import Foundation

final class ICMPTransport: PingTransport, @unchecked Sendable {
    private let timeoutSeconds: TimeInterval
    private var socketFD: Int32 = -1
    private let lock = NSLock()
    private var isCancelled = false

    private let interfaceName: String?

    init(interfaceName: String? = nil, timeoutSeconds: TimeInterval = 5) {
        self.interfaceName = interfaceName
        self.timeoutSeconds = timeoutSeconds
    }

    func ping(host: String, port: Int?) async throws -> PingResponse {
        lock.withLock { isCancelled = false }

        let resolvedIP = try resolveHost(host)

        // Non-blocking socket + poll() means this never blocks more than 100ms
        // at a time, so it's safe to run on the cooperative thread pool.
        return try performICMPPing(host: resolvedIP)
    }

    private func performICMPPing(host resolvedIP: String) throws -> PingResponse {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else {
            throw PingError.unknown("Failed to create ICMP socket: errno \(errno)")
        }

        lock.withLock { socketFD = fd }

        defer {
            close(fd)
            lock.withLock { socketFD = -1 }
        }

        // Bind to specific interface if configured
        if let ifName = interfaceName {
            var ifIndex = UInt32(if_nametoindex(ifName))
            if ifIndex > 0 {
                setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &ifIndex, socklen_t(MemoryLayout<UInt32>.size))
            }
        }

        // Use non-blocking socket + poll() to avoid GCD thread leaks
        var flags = fcntl(fd, F_GETFL)
        fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr(resolvedIP)

        let identifier = UInt16.random(in: 0...UInt16.max)
        let sequence = UInt16.random(in: 0...UInt16.max)
        let packet = buildICMPPacket(identifier: identifier, sequence: sequence)

        let startTime = ContinuousClock.Instant.now

        // Poll for write-ready, then send
        var writePoll = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let writeReady = poll(&writePoll, 1, Int32(timeoutSeconds * 1000))
        guard writeReady > 0 else {
            throw PingError.timeout
        }

        let sendResult = packet.withUnsafeBytes { bufferPtr in
            withUnsafePointer(to: addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(fd, bufferPtr.baseAddress, bufferPtr.count, 0,
                           sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sendResult >= 0 || errno == EAGAIN else {
            throw PingError.networkUnreachable
        }

        // Poll for read-ready in 100ms increments, checking cancellation
        let deadline = ContinuousClock.Instant.now + .seconds(timeoutSeconds)
        while ContinuousClock.Instant.now < deadline {
            let cancelled = lock.withLock { isCancelled }
            guard !cancelled else { throw PingError.cancelled }

            var readPoll = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let readReady = poll(&readPoll, 1, 100) // 100ms poll interval

            if readReady < 0 {
                if errno == EINTR { continue }
                throw PingError.unknown("poll failed: errno \(errno)")
            }
            if readReady == 0 { continue } // timeout, loop and check deadline

            // Data available — read it
            var responseBuffer = [UInt8](repeating: 0, count: 1024)
            let recvResult = recv(fd, &responseBuffer, responseBuffer.count, 0)

            guard recvResult >= 0 else {
                if errno == EAGAIN || errno == EWOULDBLOCK { continue }
                throw PingError.unknown("recv failed: errno \(errno)")
            }

            // On macOS/iOS, SOCK_DGRAM ICMP sockets may include the IP header.
            guard recvResult >= 28 else { continue }

            let ihl = Int(responseBuffer[0] & 0x0F) * 4
            guard recvResult >= ihl + 8 else { continue }

            let icmpType = responseBuffer[ihl]

            if icmpType == 0 { // Echo Reply
                let replyId = (UInt16(responseBuffer[ihl + 4]) << 8) | UInt16(responseBuffer[ihl + 5])
                let replySeq = (UInt16(responseBuffer[ihl + 6]) << 8) | UInt16(responseBuffer[ihl + 7])
                guard replyId == identifier && replySeq == sequence else { continue }

                let elapsed = ContinuousClock.Instant.now - startTime
                let rttMs = Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
                    + Double(elapsed.components.seconds) * 1000.0

                return PingResponse(rttMs: rttMs, resolvedIP: resolvedIP)
            }

            if icmpType == 3 { // Destination Unreachable
                throw PingError.networkUnreachable
            }
        }

        throw PingError.timeout
    }

    func cancel() {
        lock.withLock {
            isCancelled = true
            if socketFD >= 0 {
                close(socketFD)
                socketFD = -1
            }
        }
    }

    private func resolveHost(_ host: String) throws -> String {
        var addr = in_addr()
        if inet_pton(AF_INET, host, &addr) == 1 {
            return host
        }

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0, let addrInfo = result else {
            throw PingError.dnsResolutionFailed
        }
        defer { freeaddrinfo(result) }

        let sockAddr = addrInfo.pointee.ai_addr!
            .withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var inAddr = sockAddr.sin_addr
        inet_ntop(AF_INET, &inAddr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
        let bytes = ipBuffer.map { UInt8(bitPattern: $0) }
        if let nullIndex = bytes.firstIndex(of: 0) {
            return String(decoding: bytes[..<nullIndex], as: UTF8.self)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func buildICMPPacket(identifier: UInt16, sequence: UInt16) -> Data {
        var packet = Data(count: 64)
        packet[0] = 8   // Type: Echo Request
        packet[1] = 0   // Code: 0
        packet[2] = 0   // Checksum placeholder
        packet[3] = 0
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)

        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        withUnsafeBytes(of: timestamp.bigEndian) { bytes in
            for i in 0..<min(bytes.count, 56) {
                packet[8 + i] = bytes[i]
            }
        }

        let checksum = icmpChecksum(packet)
        packet[2] = UInt8(checksum & 0xFF)
        packet[3] = UInt8(checksum >> 8)

        return packet
    }

    private func icmpChecksum(_ data: Data) -> UInt16 {
        var sum: UInt32 = 0
        var index = 0
        while index < data.count - 1 {
            sum += UInt32(data[index]) | (UInt32(data[index + 1]) << 8)
            index += 2
        }
        if index < data.count {
            sum += UInt32(data[index])
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum & 0xFFFF)
    }
}

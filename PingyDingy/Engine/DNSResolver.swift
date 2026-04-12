import Foundation

struct DNSResult: Sendable {
    let ip: String
    let isIPv6: Bool
    let didChange: Bool
}

final class DNSResolver: Sendable {

    func resolve(hostname: String, previousIP: String?) throws -> DNSResult {
        // Check if already an IPv4 address
        var addr4 = in_addr()
        if inet_pton(AF_INET, hostname, &addr4) == 1 {
            return DNSResult(
                ip: hostname,
                isIPv6: false,
                didChange: previousIP != nil && previousIP != hostname
            )
        }

        // Check if already an IPv6 address
        var addr6 = in6_addr()
        if inet_pton(AF_INET6, hostname, &addr6) == 1 {
            return DNSResult(
                ip: hostname,
                isIPv6: true,
                didChange: previousIP != nil && previousIP != hostname
            )
        }

        // DNS resolution
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var resultPtr: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &resultPtr)

        guard status == 0, let addrInfo = resultPtr else {
            throw PingError.dnsResolutionFailed
        }
        defer { freeaddrinfo(resultPtr) }

        let ip: String
        let isIPv6: Bool

        if addrInfo.pointee.ai_family == AF_INET6 {
            let sockAddr = addrInfo.pointee.ai_addr!
                .withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
            var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            var inAddr = sockAddr.sin6_addr
            inet_ntop(AF_INET6, &inAddr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
            let nullTermIndex = ipBuffer.firstIndex(of: 0) ?? ipBuffer.endIndex
            ip = String(decoding: ipBuffer[..<nullTermIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            isIPv6 = true
        } else {
            let sockAddr = addrInfo.pointee.ai_addr!
                .withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var inAddr = sockAddr.sin_addr
            inet_ntop(AF_INET, &inAddr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let nullTermIndex = ipBuffer.firstIndex(of: 0) ?? ipBuffer.endIndex
            ip = String(decoding: ipBuffer[..<nullTermIndex].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            isIPv6 = false
        }

        let changed = previousIP != nil && previousIP != ip
        return DNSResult(ip: ip, isIPv6: isIPv6, didChange: changed)
    }
}

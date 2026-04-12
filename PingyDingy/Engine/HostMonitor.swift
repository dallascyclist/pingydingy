import Foundation
import Observation

struct PingEvent: Sendable {
    let hostId: UUID
    let timestamp: Date
    let rttMs: Double?
    let success: Bool
    let resolvedIP: String
    let error: String?
    let networkInterface: String?
}

struct DNSChangeEvent: Sendable {
    let hostId: UUID
    let newIP: String
    let previousIP: String
}

@MainActor
@Observable
final class HostMonitor: Identifiable {
    let id: UUID
    let hostname: String
    let hostDescription: String?
    let pingType: PingType
    let port: Int
    let intervalSeconds: Int
    let loggingEnabled: Bool
    var perPingSoundEnabled: Bool
    var transitionSoundEnabled: Bool
    let isDemo: Bool
    let networkInterface: String?
    var interfaceDisplayName: String?
    var interfaceAvailable: Bool = true

    private(set) var resolvedIP: String = ""
    private(set) var isIPv6: Bool = false
    private(set) var isUp: Bool = false
    private(set) var isRunning: Bool = false
    private(set) var lastRTT: Double?
    private(set) var avgRTT: Double = 0
    private(set) var sentCount: Int = 0
    private(set) var receivedCount: Int = 0
    private(set) var lostCount: Int = 0
    private(set) var lastResponseTime: Date?
    private(set) var lastLostTime: Date?
    private(set) var dnsChanged: Bool = false
    private(set) var recentDataPoints: [PingDataPoint] = []

    @ObservationIgnored var onPingResult: (@Sendable (PingEvent) -> Void)?
    @ObservationIgnored var onDNSChange: (@Sendable (DNSChangeEvent) -> Void)?

    private let transport: PingTransport
    private let dnsResolver: DNSResolver
    private let soundManager: SoundManager
    private var monitorTask: Task<Void, Never>?
    private var dnsTask: Task<Void, Never>?
    private var rttSum: Double = 0

    init(
        config: HostConfiguration,
        transport: PingTransport,
        dnsResolver: DNSResolver = DNSResolver(),
        soundManager: SoundManager,
        isDemo: Bool = false,
        interfaceDisplayName: String? = nil
    ) {
        self.id = config.id
        self.hostname = config.hostname
        self.hostDescription = config.hostDescription
        self.pingType = config.pingType
        self.port = config.port
        self.intervalSeconds = config.intervalSeconds
        self.loggingEnabled = config.loggingEnabled
        self.perPingSoundEnabled = config.perPingSoundEnabled
        self.transitionSoundEnabled = config.transitionSoundEnabled
        self.isDemo = isDemo
        self.networkInterface = config.networkInterface
        self.interfaceDisplayName = interfaceDisplayName
        self.transport = transport
        self.dnsResolver = dnsResolver
        self.soundManager = soundManager
    }

    var displayLabel: String? {
        if isIPAddress(hostname) {
            return hostDescription?.isEmpty == false ? hostDescription : nil
        }
        return hostname
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        do {
            let result = try dnsResolver.resolve(hostname: hostname, previousIP: nil)
            resolvedIP = result.ip
            isIPv6 = result.isIPv6
        } catch {
            resolvedIP = hostname
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let pingStart = ContinuousClock.now
                await self.performPing()
                let elapsed = ContinuousClock.now - pingStart
                let elapsedSeconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000_000.0
                let remaining = Double(self.intervalSeconds) - elapsedSeconds
                if remaining > 0.01 {
                    try? await Task.sleep(for: .seconds(remaining))
                }
            }
        }

        dnsTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self.performDNSReresolution()
            }
        }
    }

    func stop() {
        isRunning = false
        monitorTask?.cancel()
        dnsTask?.cancel()
        monitorTask = nil
        dnsTask = nil
        transport.cancel()
    }

    func acknowledgeDNSChange() {
        dnsChanged = false
    }

    private func performPing() async {
        guard interfaceAvailable else { return }
        let wasUp = isUp
        let currentResolvedIP = resolvedIP
        let currentPort = pingType == .tcp ? port : nil

        do {
            let response = try await transport.ping(
                host: currentResolvedIP,
                port: currentPort
            )
            sentCount += 1
            receivedCount += 1
            lastRTT = response.rttMs
            rttSum += response.rttMs
            avgRTT = rttSum / Double(receivedCount)
            isUp = true
            lastResponseTime = Date()

            appendDataPoint(rttMs: response.rttMs, success: true)

            soundManager.playPingSound(success: true, hostSoundEnabled: perPingSoundEnabled)

            if !wasUp && sentCount > 1 && transitionSoundEnabled {
                soundManager.playTransitionSound(hostId: id, wentUp: true)
            }

            onPingResult?(PingEvent(
                hostId: id, timestamp: Date(), rttMs: response.rttMs,
                success: true, resolvedIP: response.resolvedIP, error: nil,
                networkInterface: interfaceDisplayName ?? "auto"
            ))
        } catch {
            sentCount += 1
            lostCount += 1
            lastRTT = nil
            isUp = false
            lastLostTime = Date()

            appendDataPoint(rttMs: nil, success: false)

            soundManager.playPingSound(success: false, hostSoundEnabled: perPingSoundEnabled)

            if wasUp && sentCount > 1 && transitionSoundEnabled {
                soundManager.playTransitionSound(hostId: id, wentUp: false)
            }

            onPingResult?(PingEvent(
                hostId: id, timestamp: Date(), rttMs: nil, success: false,
                resolvedIP: currentResolvedIP,
                error: (error as? PingError)?.errorDescription ?? error.localizedDescription,
                networkInterface: interfaceDisplayName ?? "auto"
            ))
        }
    }

    private func performDNSReresolution() {
        guard !isIPAddress(hostname) else { return }
        do {
            let result = try dnsResolver.resolve(hostname: hostname, previousIP: resolvedIP)
            if result.didChange {
                let previousIP = resolvedIP
                resolvedIP = result.ip
                isIPv6 = result.isIPv6
                dnsChanged = true
                onDNSChange?(DNSChangeEvent(hostId: id, newIP: result.ip, previousIP: previousIP))
            }
        } catch {
            // Keep using last known IP
        }
    }

    private static let maxDataPoints = 600 // 10 minutes at 1s interval

    private func appendDataPoint(rttMs: Double?, success: Bool) {
        let point = PingDataPoint(
            id: UUID(),
            timestamp: Date(),
            rttMs: rttMs,
            success: success
        )
        recentDataPoints.append(point)
        // Trim old points beyond the window
        if recentDataPoints.count > Self.maxDataPoints {
            recentDataPoints.removeFirst(recentDataPoints.count - Self.maxDataPoints)
        }
    }

    private nonisolated func isIPAddress(_ host: String) -> Bool {
        var addr4 = in_addr()
        var addr6 = in6_addr()
        return inet_pton(AF_INET, host, &addr4) == 1
            || inet_pton(AF_INET6, host, &addr6) == 1
    }
}

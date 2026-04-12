import Foundation
import Network
import SwiftData
import Observation

enum ConfigSharingError: Error, LocalizedError {
    case noContext
    case invalidFile
    var errorDescription: String? {
        switch self {
        case .noContext: "Database not available"
        case .invalidFile: "Invalid configuration file"
        }
    }
}

@Observable @MainActor
final class MonitoringEngine {
    private(set) var monitors: [HostMonitor] = []
    var sortOption: SortOption = .timeAdded
    var sortDirection: SortDirection = .ascending
    var activeFilters: Set<FilterOption> = []
    var showRetentionReminder: Bool = false

    private var modelContext: ModelContext?
    private let soundManager: SoundManager
    private let interfaceManager: InterfaceManager

    init(soundManager: SoundManager, interfaceManager: InterfaceManager) {
        self.soundManager = soundManager
        self.interfaceManager = interfaceManager
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func addHost(_ config: HostConfiguration) {
        modelContext?.insert(config)
        try? modelContext?.save()
        let monitor = createMonitor(for: config)
        monitors.append(monitor)
    }

    func removeHost(_ monitor: HostMonitor) {
        monitor.stop()
        monitors.removeAll { $0.id == monitor.id }

        if let context = modelContext, let config = fetchConfig(id: monitor.id) {
            context.delete(config)
            try? context.save()
        }
    }

    func updateHost(_ monitor: HostMonitor, with form: HostFormData) {
        guard let config = fetchConfig(id: monitor.id) else { return }

        let wasRunning = monitor.isRunning
        monitor.stop()

        config.hostname = form.hostname
        config.hostDescription = form.hostDescription.isEmpty ? nil : form.hostDescription
        config.pingType = form.pingType
        config.port = form.port
        config.intervalSeconds = form.intervalSeconds
        config.loggingEnabled = form.loggingEnabled
        config.perPingSoundEnabled = form.perPingSoundEnabled
        config.transitionSoundEnabled = form.transitionSoundEnabled
        config.networkInterface = form.networkInterface
        try? modelContext?.save()

        monitors.removeAll { $0.id == monitor.id }
        let newMonitor = createMonitor(for: config)
        monitors.append(newMonitor)
        if wasRunning { newMonitor.start() }
    }

    func startAll() { monitors.forEach { $0.start() } }
    func stopAll() {
        monitors.forEach { $0.stop() }
        flushPendingResults()
    }

    func clearAllData() {
        // Stop and remove all monitors
        for monitor in monitors { monitor.stop() }
        monitors.removeAll()

        guard let context = modelContext else { return }

        // Delete all ping results
        let pingDescriptor = FetchDescriptor<PingResult>()
        if let results = try? context.fetch(pingDescriptor) {
            for result in results { context.delete(result) }
        }

        // Delete all DNS resolutions
        let dnsDescriptor = FetchDescriptor<DNSResolution>()
        if let resolutions = try? context.fetch(dnsDescriptor) {
            for resolution in resolutions { context.delete(resolution) }
        }

        // Delete all host configurations
        let hostDescriptor = FetchDescriptor<HostConfiguration>()
        if let configs = try? context.fetch(hostDescriptor) {
            for config in configs { context.delete(config) }
        }

        try? context.save()
        showRetentionReminder = false
    }

    func toggleMonitoring(for monitor: HostMonitor) {
        if monitor.isRunning { monitor.stop() } else { monitor.start() }
    }

    func loadHosts() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<HostConfiguration>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        guard let configs = try? context.fetch(descriptor) else { return }
        monitors = configs.map { createMonitor(for: $0) }
        checkRetention()
    }

    func setupInterfaceMonitoring() {
        interfaceManager.onInterfaceStatusChanged = { [weak self] interfaceName, available in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for monitor in self.monitors where monitor.networkInterface == interfaceName {
                    monitor.interfaceAvailable = available
                    // Update display name if it was unresolved at creation time
                    if available, monitor.interfaceDisplayName == nil || monitor.interfaceDisplayName == interfaceName {
                        monitor.interfaceDisplayName = self.interfaceManager.displayName(for: interfaceName)
                    }
                }
            }
        }
    }

    var filteredAndSortedMonitors: [HostMonitor] {
        var result = monitors

        for filter in activeFilters {
            switch filter {
            case .up: result = result.filter { $0.isUp }
            case .down: result = result.filter { !$0.isUp && $0.sentCount > 0 }
            case .icmp: result = result.filter { $0.pingType == .icmp }
            case .tcp: result = result.filter { $0.pingType == .tcp }
            case .logging: result = result.filter { $0.loggingEnabled }
            case .slow: result = result.filter { ($0.lastRTT ?? 0) > 500 }
            }
        }

        result.sort { a, b in
            let ascending: Bool
            switch sortOption {
            case .timeAdded: ascending = true
            case .hostname: ascending = a.hostname.localizedCompare(b.hostname) == .orderedAscending
            case .lastRTT: ascending = (a.lastRTT ?? .infinity) < (b.lastRTT ?? .infinity)
            case .avgRTT: ascending = a.avgRTT < b.avgRTT
            case .lastResponse: ascending = (a.lastResponseTime ?? .distantPast) < (b.lastResponseTime ?? .distantPast)
            case .lastLost: ascending = (a.lastLostTime ?? .distantPast) < (b.lastLostTime ?? .distantPast)
            case .lossPercent:
                let aLoss = a.sentCount > 0 ? Double(a.lostCount) / Double(a.sentCount) : 0
                let bLoss = b.sentCount > 0 ? Double(b.lostCount) / Double(b.sentCount) : 0
                ascending = aLoss < bLoss
            case .status: ascending = a.isUp && !b.isUp
            }
            return sortDirection == .ascending ? ascending : !ascending
        }
        return result
    }

    func pingDataPoints(for hostId: UUID) -> [PingDataPoint] {
        // Read from monitor's in-memory buffer — works for both demo and real hosts
        guard let monitor = monitors.first(where: { $0.id == hostId }) else { return [] }
        return monitor.recentDataPoints
    }

    func exportRows(for hostId: UUID, start: Date, end: Date) -> [ExportRow] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<PingResult>(
            predicate: #Predicate<PingResult> { $0.hostId == hostId && $0.timestamp >= start && $0.timestamp <= end },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let results = try? context.fetch(descriptor) else { return [] }
        return results.map {
            ExportRow(timestamp: $0.timestamp, rttMs: $0.rttMs, success: $0.success,
                     resolvedIP: $0.resolvedIP, networkInterface: $0.networkInterface, error: $0.error)
        }
    }

    // MARK: - Demo Data

    var hasDemoMonitors: Bool {
        monitors.contains { $0.isDemo }
    }

    func removeDemoMonitors() {
        for monitor in monitors where monitor.isDemo {
            monitor.stop()
        }
        monitors.removeAll { $0.isDemo }
    }

    func loadDemoData() {
        let demoHosts: [(String, String, PingType, Int, Int)] = [
            ("8.8.8.8",         "Google DNS",      .icmp, 443,  1),
            ("1.1.1.1",         "Cloudflare DNS",  .icmp, 443,  1),
            ("9.9.9.9",         "Quad9 DNS",       .icmp, 443,  1),
            ("208.67.222.222",  "OpenDNS",         .icmp, 443,  1),
            ("149.112.112.112", "Quad9 Alt",       .icmp, 443,  1),
            ("8.8.8.8",         "Google DNS",      .tcp,  53,   5),
            ("1.1.1.1",         "Cloudflare DNS",  .tcp,  443,  5),
            ("google.com",      "Google Web",      .tcp,  443,  5),
            ("one.one.one.one", "Cloudflare Test", .tcp,  443,  5),
            ("portquiz.net",    "TCP Port Tester", .tcp,  8080, 5),
        ]

        for (index, (host, desc, pingType, port, interval)) in demoHosts.enumerated() {
            let config = HostConfiguration(
                hostname: host,
                hostDescription: desc,
                pingType: pingType,
                port: port,
                intervalSeconds: interval,
                loggingEnabled: false,
                perPingSoundEnabled: false,
                transitionSoundEnabled: true,
                sortOrder: monitors.count + index
            )
            // Do NOT insert config into SwiftData — demo data is ephemeral
            let transport: PingTransport = pingType == .tcp ? TCPTransport() : ICMPTransport()
            let monitor = HostMonitor(
                config: config,
                transport: transport,
                soundManager: soundManager,
                isDemo: true,
                interfaceDisplayName: nil
            )
            // No persistence callbacks — onPingResult and onDNSChange stay nil
            monitors.append(monitor)
            monitor.start()
        }
    }

    // MARK: - Config Sharing

    func exportConfig(monitors selectedMonitors: [HostMonitor]) throws -> URL {
        guard let context = modelContext else { throw ConfigSharingError.noContext }
        let configs: [HostConfiguration] = selectedMonitors.compactMap { monitor in
            self.fetchConfig(id: monitor.id)
        }
        let configFile = ConfigFile.fromHostConfigurations(configs)
        return try configFile.writeToTempFile()
    }

    func buildImportPreview(from configFile: ConfigFile) -> ImportPreview {
        let existingByKey: [String: HostConfiguration] = {
            guard let context = modelContext else { return [:] }
            let descriptor = FetchDescriptor<HostConfiguration>()
            guard let configs = try? context.fetch(descriptor) else { return [:] }
            var map: [String: HostConfiguration] = [:]
            for config in configs {
                let key = "\(config.hostname)|\(config.pingType.rawValue)|\(config.port)"
                map[key] = config
            }
            return map
        }()

        var newHosts: [ConfigHost] = []
        var conflicts: [ImportConflict] = []

        for incoming in configFile.hosts {
            if let existing = existingByKey[incoming.conflictKey] {
                conflicts.append(ImportConflict(existingHost: existing, incomingHost: incoming))
            } else {
                newHosts.append(incoming)
            }
        }

        return ImportPreview(newHosts: newHosts, conflicts: conflicts)
    }

    func executeImport(_ preview: ImportPreview) {
        switch preview.mode {
        case .replace:
            for monitor in monitors { monitor.stop() }
            monitors.removeAll()
            if let context = modelContext {
                let descriptor = FetchDescriptor<HostConfiguration>()
                if let allConfigs = try? context.fetch(descriptor) {
                    for config in allConfigs { context.delete(config) }
                }
                try? context.save()
            }
            let allIncoming = preview.newHosts + preview.conflicts.map(\.incomingHost)
            for (index, host) in allIncoming.enumerated() {
                addHost(hostConfigurationFrom(host, sortOrder: index))
            }

        case .merge:
            let startOrder = monitors.count
            for (index, host) in preview.newHosts.enumerated() {
                addHost(hostConfigurationFrom(host, sortOrder: startOrder + index))
            }
            for conflict in preview.conflicts where conflict.resolution == .useTheirs {
                if let existingMonitor = monitors.first(where: { $0.id == conflict.existingHost.id }) {
                    let form = HostFormData(
                        hostname: conflict.incomingHost.hostname,
                        hostDescription: conflict.incomingHost.description ?? "",
                        pingType: conflict.incomingHost.pingType,
                        port: conflict.incomingHost.port,
                        intervalSeconds: conflict.incomingHost.intervalSeconds,
                        loggingEnabled: conflict.incomingHost.loggingEnabled,
                        perPingSoundEnabled: conflict.incomingHost.perPingSoundEnabled,
                        transitionSoundEnabled: conflict.incomingHost.transitionSoundEnabled
                    )
                    updateHost(existingMonitor, with: form)
                }
            }
        }
    }

    private func hostConfigurationFrom(_ host: ConfigHost, sortOrder: Int) -> HostConfiguration {
        HostConfiguration(
            hostname: host.hostname,
            hostDescription: host.description,
            pingType: host.pingType,
            port: host.port,
            intervalSeconds: host.intervalSeconds,
            loggingEnabled: host.loggingEnabled,
            perPingSoundEnabled: host.perPingSoundEnabled,
            transitionSoundEnabled: host.transitionSoundEnabled,
            sortOrder: sortOrder
        )
    }

    private func createMonitor(for config: HostConfiguration) -> HostMonitor {
        let ifType: NWInterface.InterfaceType? = {
            guard let ifName = config.networkInterface else { return nil }
            return interfaceManager.availableInterfaces.first { $0.name == ifName }?.type
        }()

        // Timeout should not exceed the ping interval — prevents pileup
        let timeout = TimeInterval(max(1, config.intervalSeconds))

        let transport: PingTransport = config.pingType == .tcp
            ? TCPTransport(interfaceName: config.networkInterface, interfaceType: ifType, timeoutSeconds: timeout)
            : ICMPTransport(interfaceName: config.networkInterface, timeoutSeconds: timeout)

        let displayName = interfaceManager.displayName(for: config.networkInterface)

        let monitor = HostMonitor(
            config: config,
            transport: transport,
            soundManager: soundManager,
            isDemo: false,
            interfaceDisplayName: config.networkInterface != nil ? displayName : nil
        )

        // Set initial interface availability
        // Default to true — let the ping attempt and fail naturally rather than
        // silently blocking. InterfaceManager's onInterfaceStatusChanged will
        // update this if the interface actually disappears later.
        monitor.interfaceAvailable = true

        let loggingEnabled = config.loggingEnabled

        monitor.onPingResult = { [weak self] event in
            Task { @MainActor in
                self?.persistPingResult(event, loggingEnabled: loggingEnabled)
            }
        }
        monitor.onDNSChange = { [weak self] event in
            Task { @MainActor in
                self?.persistDNSChange(event)
            }
        }
        return monitor
    }

    /// Fetch a HostConfiguration by UUID — avoids SwiftData #Predicate UUID issues
    private func fetchConfig(id: UUID) -> HostConfiguration? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<HostConfiguration>()
        guard let configs = try? context.fetch(descriptor) else { return nil }
        return configs.first { $0.id == id }
    }

    // Batch pending results and save periodically to prevent ModelContext memory growth
    private var pendingResults: [PingEvent] = []
    private var saveTask: Task<Void, Never>?
    private static let saveInterval: TimeInterval = 10 // seconds between batch saves

    private func persistPingResult(_ event: PingEvent, loggingEnabled: Bool) {
        guard loggingEnabled else { return }
        pendingResults.append(event)

        // Start a periodic save task if not already running
        if saveTask == nil {
            saveTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(MonitoringEngine.saveInterval))
                    self?.flushPendingResults()
                }
            }
        }
    }

    private func flushPendingResults() {
        guard let context = modelContext, !pendingResults.isEmpty else { return }

        let batch = pendingResults
        pendingResults.removeAll(keepingCapacity: true)

        for event in batch {
            let result = PingResult(
                hostId: event.hostId, rttMs: event.rttMs, success: event.success,
                resolvedIP: event.resolvedIP, error: event.error,
                networkInterface: event.networkInterface
            )
            context.insert(result)
        }
        try? context.save()
    }

    private func persistDNSChange(_ event: DNSChangeEvent) {
        guard let context = modelContext else { return }
        let resolution = DNSResolution(
            hostId: event.hostId, resolvedIP: event.newIP, previousIP: event.previousIP
        )
        context.insert(resolution)
        try? context.save()
    }

    private func checkRetention() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<PingResult>(sortBy: [SortDescriptor(\.timestamp)])
        descriptor.fetchLimit = 1
        if let oldest = try? context.fetch(descriptor).first {
            showRetentionReminder = DataRetentionService.shouldShowReminder(oldestDataDate: oldest.timestamp)
        }
    }
}

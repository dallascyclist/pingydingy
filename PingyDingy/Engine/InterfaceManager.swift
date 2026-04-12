import Foundation
import Network
import Observation
#if canImport(CoreTelephony)
import CoreTelephony
#endif

struct MonitoredInterface: Identifiable, Sendable {
    let id: String
    let name: String
    let type: NWInterface.InterfaceType
    let displayName: String
}

@Observable @MainActor
final class InterfaceManager {
    private(set) var availableInterfaces: [MonitoredInterface] = []

    @ObservationIgnored var onInterfaceStatusChanged: ((String, Bool) -> Void)?

    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var previousInterfaceNames: Set<String> = []

    init() {
        startMonitoring()
    }

    deinit {
        pathMonitor?.cancel()
    }

    func isInterfaceAvailable(_ name: String) -> Bool {
        availableInterfaces.contains { $0.name == name }
    }

    func displayName(for interfaceName: String?) -> String {
        guard let name = interfaceName else { return "Auto" }
        return availableInterfaces.first { $0.name == name }?.displayName ?? name
    }

    private func startMonitoring() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.pingydingy.interfacemonitor"))
    }

    private func handlePathUpdate(_ path: NWPath) {
        let interfaces = path.availableInterfaces
        let carrierNames = resolveCarrierNames()

        // Deduplicate by type — keep only the first interface of each type
        // NWPathMonitor can return multiple WiFi interfaces (en0, en1, etc.)
        var seenTypes: Set<NWInterface.InterfaceType> = []
        var cellularIndex = 0

        let monitored: [MonitoredInterface] = interfaces.compactMap { iface in
            // For WiFi and Ethernet, keep only the first one
            // For cellular, keep all (dual-SIM = two distinct cellular interfaces)
            if iface.type != .cellular {
                guard !seenTypes.contains(iface.type) else { return nil }
                seenTypes.insert(iface.type)
            }

            let displayName: String
            switch iface.type {
            case .wifi:
                displayName = "WiFi"
            case .cellular:
                cellularIndex += 1
                // Try carrier name from CTTelephonyNetworkInfo
                // Check both the exact interface name and the indexed pdp_ip mapping
                let carrierName = carrierNames[iface.name]
                    ?? carrierNames["pdp_ip\(cellularIndex - 1)"]
                if let carrier = carrierName, isValidCarrierName(carrier) {
                    displayName = carrier
                } else {
                    displayName = "Cellular \(cellularIndex)"
                }
            case .wiredEthernet:
                displayName = "Ethernet"
            default:
                return nil
            }

            return MonitoredInterface(
                id: iface.name,
                name: iface.name,
                type: iface.type,
                displayName: displayName
            )
        }

        let newNames = Set(monitored.map(\.name))
        let disappeared = previousInterfaceNames.subtracting(newNames)
        let appeared = newNames.subtracting(previousInterfaceNames)

        availableInterfaces = monitored
        previousInterfaceNames = newNames

        for name in disappeared {
            onInterfaceStatusChanged?(name, false)
        }
        for name in appeared {
            onInterfaceStatusChanged?(name, true)
        }
    }

    /// Check if a carrier name is valid (not empty, not "-", not "Carrier")
    private func isValidCarrierName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != "-" && trimmed != "--" && trimmed.lowercased() != "carrier"
    }

    private nonisolated func resolveCarrierNames() -> [String: String] {
        #if canImport(CoreTelephony) && os(iOS)
        let networkInfo = CTTelephonyNetworkInfo()
        var result: [String: String] = [:]

        // Try serviceSubscriberCellularProviders (deprecated but functional)
        if let carriers = networkInfo.serviceSubscriberCellularProviders {
            let sortedKeys = carriers.keys.sorted()
            for (index, key) in sortedKeys.enumerated() {
                if let carrier = carriers[key], let name = carrier.carrierName {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && trimmed != "-" && trimmed != "--" && trimmed.lowercased() != "carrier" {
                        // Map to both pdp_ip index and service key
                        result["pdp_ip\(index)"] = trimmed
                        result[key] = trimmed
                    }
                }
            }
        }

        return result
        #else
        return [:]
        #endif
    }
}

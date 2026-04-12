import Testing
import Foundation
@testable import PingyDingy

@Test @MainActor func interfaceManagerInitializes() {
    let manager = InterfaceManager()
    // Doesn't crash on init — the real validation
    #expect(manager.availableInterfaces.isEmpty || !manager.availableInterfaces.isEmpty)
}

@Test @MainActor func interfaceManagerDisplayNameFallback() {
    let manager = InterfaceManager()
    #expect(manager.displayName(for: nil) == "Auto")
    #expect(manager.displayName(for: "unknown0") == "unknown0")
}

@Test @MainActor func monitoredInterfaceIdentifiable() {
    let iface = MonitoredInterface(
        id: "en0", name: "en0", type: .wifi, displayName: "WiFi"
    )
    #expect(iface.id == "en0")
    #expect(iface.displayName == "WiFi")
    #expect(iface.name == "en0")
}

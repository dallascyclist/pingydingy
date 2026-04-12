import SwiftUI
import SwiftData

@main
struct PingyDingyApp: App {
    @State private var soundManager = SoundManager()
    @State private var interfaceManager = InterfaceManager()

    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    #if canImport(UIKit)
    @AppStorage("keepDeviceUnlocked") private var keepDeviceUnlocked = false
    #endif

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: .light
        case 2: .dark
        default: nil // system
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView(engine: MonitoringEngine(soundManager: soundManager, interfaceManager: interfaceManager),
                     interfaceManager: interfaceManager)
                .preferredColorScheme(colorScheme)
                #if canImport(UIKit)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = keepDeviceUnlocked
                }
                .onChange(of: keepDeviceUnlocked) { _, newValue in
                    UIApplication.shared.isIdleTimerDisabled = newValue
                }
                #endif
        }
        .modelContainer(for: [
            HostConfiguration.self,
            PingResult.self,
            DNSResolution.self
        ])
    }
}

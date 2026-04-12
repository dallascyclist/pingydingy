import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultInterval") private var defaultInterval: Int = 1
    @AppStorage("defaultPingType") private var defaultPingType: String = PingType.icmp.rawValue
    @AppStorage("defaultPort") private var defaultPort: Int = 443
    @AppStorage("keepDeviceUnlocked") private var keepDeviceUnlocked: Bool = false
    @AppStorage("masterSoundEnabled") private var masterSoundEnabled: Bool = true
    @AppStorage("defaultLogging") private var defaultLogging: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0 // 0=system, 1=light, 2=dark

    var onMasterSoundChanged: ((Bool) -> Void)?
    var onClearAllData: (() -> Void)?

    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults for New Hosts") {
                    HStack {
                        Text("Interval")
                        Spacer()
                        Text("\(defaultInterval)s")
                            .foregroundStyle(TronTheme.accent)
                    }
                    Stepper("", value: $defaultInterval, in: 1...600)
                        .labelsHidden()

                    Picker("Protocol", selection: Binding(
                        get: { PingType(rawValue: defaultPingType) ?? .icmp },
                        set: { defaultPingType = $0.rawValue }
                    )) {
                        Text("ICMP").tag(PingType.icmp)
                        Text("TCP").tag(PingType.tcp)
                    }

                    if PingType(rawValue: defaultPingType) == .tcp {
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("Port", value: $defaultPort, format: .number)
                                #if canImport(UIKit)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }

                    Toggle("Record Log", isOn: $defaultLogging)
                }

                Section("Device") {
                    Toggle("Keep Device Unlocked", isOn: $keepDeviceUnlocked)
                }

                Section("Sound") {
                    Toggle("Master Sound", isOn: $masterSoundEnabled)
                        .onChange(of: masterSoundEnabled) { _, newValue in
                            onMasterSoundChanged?(newValue)
                        }
                }

                Section("Appearance") {
                    Picker("Dark Mode", selection: $appearanceMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Data") {
                    Button("Clear All Data", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .alert("Clear All Data?", isPresented: $showClearConfirmation) {
                        Button("Clear Everything", role: .destructive) {
                            onClearAllData?()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will delete all hosts, ping logs, and DNS history. This cannot be undone.")
                    }
                }
            }
            .navigationTitle("Settings")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

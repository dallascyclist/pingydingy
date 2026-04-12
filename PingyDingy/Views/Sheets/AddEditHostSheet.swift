import SwiftUI

struct HostFormData {
    var hostname: String = ""
    var hostDescription: String = ""
    var pingType: PingType = .icmp
    var port: Int = 443
    var intervalSeconds: Int = 1
    var networkInterface: String?
    var loggingEnabled: Bool = true
    var perPingSoundEnabled: Bool = false
    var transitionSoundEnabled: Bool = false
}

struct AddEditHostSheet: View {
    let existingHost: HostConfiguration?
    let onSave: (HostFormData) -> Void
    let interfaceManager: InterfaceManager

    @Environment(\.dismiss) private var dismiss
    @State private var form: HostFormData

    private static let intervalStops = [1, 5, 10, 15, 30, 60, 120, 240, 300, 600]

    init(existingHost: HostConfiguration? = nil, interfaceManager: InterfaceManager, onSave: @escaping (HostFormData) -> Void) {
        self.existingHost = existingHost
        self.onSave = onSave
        self.interfaceManager = interfaceManager
        if let host = existingHost {
            _form = State(initialValue: HostFormData(
                hostname: host.hostname,
                hostDescription: host.hostDescription ?? "",
                pingType: host.pingType,
                port: host.port,
                intervalSeconds: host.intervalSeconds,
                networkInterface: host.networkInterface,
                loggingEnabled: host.loggingEnabled,
                perPingSoundEnabled: host.perPingSoundEnabled,
                transitionSoundEnabled: host.transitionSoundEnabled
            ))
        } else {
            _form = State(initialValue: HostFormData())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("IP Address or Hostname", text: $form.hostname)
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .autocorrectionDisabled()

                    TextField("Description (optional)", text: $form.hostDescription)
                }

                Section("Protocol") {
                    Picker("Type", selection: $form.pingType) {
                        Text("ICMP").tag(PingType.icmp)
                        Text("TCP").tag(PingType.tcp)
                    }
                    .pickerStyle(.segmented)

                    if form.pingType == .tcp {
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("Port", value: $form.port, format: .number)
                                #if canImport(UIKit)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                Section("Network Interface") {
                    Picker("Interface", selection: $form.networkInterface) {
                        Text("Auto").tag(String?.none)
                        ForEach(interfaceManager.availableInterfaces) { iface in
                            Text(iface.displayName).tag(Optional(iface.name))
                        }
                    }
                }

                Section("Interval") {
                    HStack {
                        Text("\(form.intervalSeconds)s")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 60)

                        Spacer()

                        Button(action: decrementInterval) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(TronTheme.accent)
                        }
                        .disabled(form.intervalSeconds <= 1)

                        Button(action: incrementInterval) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(TronTheme.accent)
                        }
                        .disabled(form.intervalSeconds >= 600)
                    }

                    TextField("Seconds (1-600)", value: $form.intervalSeconds, format: .number)
                        #if canImport(UIKit)
                        .keyboardType(.numberPad)
                        #endif
                        .onChange(of: form.intervalSeconds) { _, newValue in
                            form.intervalSeconds = max(1, min(600, newValue))
                        }
                }

                Section("Options") {
                    Toggle("Record Log", isOn: $form.loggingEnabled)
                }

                Section("Sound") {
                    Toggle("Per-Ping Sound", isOn: $form.perPingSoundEnabled)
                    Toggle("Transition Alerts", isOn: $form.transitionSoundEnabled)
                }
            }
            .navigationTitle(existingHost == nil ? "Add Host" : "Edit Host")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(form)
                        dismiss()
                    }
                    .disabled(form.hostname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func incrementInterval() {
        let stops = Self.intervalStops
        if let nextStop = stops.first(where: { $0 > form.intervalSeconds }) {
            form.intervalSeconds = nextStop
        }
    }

    private func decrementInterval() {
        let stops = Self.intervalStops
        if let prevStop = stops.last(where: { $0 < form.intervalSeconds }) {
            form.intervalSeconds = prevStop
        }
    }
}

import SwiftUI

struct ImportPreviewSheet: View {
    @State var preview: ImportPreview
    let onImport: (ImportPreview) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Mode picker
                Section {
                    Picker("Import Mode", selection: $preview.mode) {
                        Text("Merge").tag(ImportMode.merge)
                        Text("Replace All").tag(ImportMode.replace)
                    }
                    .pickerStyle(.segmented)
                }

                if preview.mode == .replace {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(TronTheme.dnsAlert)
                            Text("Replace will remove all existing hosts and import these.")
                                .font(.system(size: 12))
                                .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
                        }
                    }
                }

                // New hosts
                if !preview.newHosts.isEmpty {
                    Section {
                        ForEach(preview.newHosts, id: \.conflictKey) { host in
                            ConfigHostRow(host: host, isNew: true)
                        }
                    } header: {
                        Label("New (\(preview.newHosts.count))", systemImage: "plus.circle.fill")
                            .foregroundStyle(TronTheme.statusUp)
                    }
                }

                // Conflicts
                if !preview.conflicts.isEmpty {
                    Section {
                        ForEach($preview.conflicts) { $conflict in
                            ConflictRow(conflict: $conflict, showResolution: preview.mode == .merge)
                        }
                    } header: {
                        Label("Conflicts (\(preview.conflicts.count))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(TronTheme.dnsAlert)
                    }
                }

                // Summary
                Section {
                    HStack {
                        Text("Will import")
                        Spacer()
                        Text("\(preview.totalToImport) hosts")
                            .foregroundStyle(TronTheme.accent)
                    }
                }
            }
            .navigationTitle("Import Config")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport(preview)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ConfigHostRow: View {
    let host: ConfigHost
    let isNew: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(host.hostname)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(isNew ? TronTheme.statusUp : TronTheme.textPrimary)
                if let desc = host.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(TronTheme.textSecondary)
                }
            }
            Spacer()
            Text(host.pingType == .tcp ? "TCP \(host.port)" : "ICMP")
                .protocolBadge(isDown: false)
            Text("\(host.intervalSeconds)s")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(TronTheme.textSecondary)
        }
    }
}

struct ConflictRow: View {
    @Binding var conflict: ImportConflict
    let showResolution: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conflict.incomingHost.hostname)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(TronTheme.dnsAlert)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yours")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TronTheme.textSecondary)
                    Text("\(conflict.existingHost.intervalSeconds)s interval")
                        .font(.system(size: 11))
                        .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
                    Text("log \(conflict.existingHost.loggingEnabled ? "on" : "off")")
                        .font(.system(size: 11))
                        .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Theirs")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TronTheme.textSecondary)
                    Text("\(conflict.incomingHost.intervalSeconds)s interval")
                        .font(.system(size: 11))
                        .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
                    Text("log \(conflict.incomingHost.loggingEnabled ? "on" : "off")")
                        .font(.system(size: 11))
                        .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showResolution {
                HStack(spacing: 8) {
                    Button {
                        conflict.resolution = .keepYours
                    } label: {
                        Text("Keep Yours")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(conflict.resolution == .keepYours ? TronTheme.accent.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(TronTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .foregroundStyle(conflict.resolution == .keepYours ? TronTheme.accent : TronTheme.textSecondary)

                    Button {
                        conflict.resolution = .useTheirs
                    } label: {
                        Text("Use Theirs")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(conflict.resolution == .useTheirs ? TronTheme.dnsAlert.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(TronTheme.dnsAlert.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .foregroundStyle(conflict.resolution == .useTheirs ? TronTheme.dnsAlert : TronTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

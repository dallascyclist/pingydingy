import SwiftUI

struct ShareConfigSheet: View {
    let allMonitors: [HostMonitor]
    let visibleMonitors: [HostMonitor]
    let onExport: ([HostMonitor]) throws -> URL
    let onEnterMultiSelect: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportAndShare(allMonitors)
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(TronTheme.accent)
                            VStack(alignment: .leading) {
                                Text("Share All")
                                    .foregroundStyle(TronTheme.textPrimary)
                                Text("\(allMonitors.count) hosts")
                                    .font(.caption)
                                    .foregroundStyle(TronTheme.textSecondary)
                            }
                        }
                    }

                    Button {
                        exportAndShare(visibleMonitors)
                    } label: {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundStyle(TronTheme.accent)
                            VStack(alignment: .leading) {
                                Text("Share Visible")
                                    .foregroundStyle(TronTheme.textPrimary)
                                Text("\(visibleMonitors.count) hosts (filtered)")
                                    .font(.caption)
                                    .foregroundStyle(TronTheme.textSecondary)
                            }
                        }
                    }
                    .disabled(visibleMonitors.isEmpty)

                    Button {
                        dismiss()
                        onEnterMultiSelect()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(TronTheme.accent)
                            VStack(alignment: .leading) {
                                Text("Select Hosts...")
                                    .foregroundStyle(TronTheme.textPrimary)
                                Text("Pick specific hosts to share")
                                    .font(.caption)
                                    .foregroundStyle(TronTheme.textSecondary)
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(TronTheme.statusDown)
                    }
                }
            }
            .navigationTitle("Share Config")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            #endif
        }
    }

    private func exportAndShare(_ monitors: [HostMonitor]) {
        do {
            let url = try onExport(monitors)
            exportURL = url
            showShareSheet = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

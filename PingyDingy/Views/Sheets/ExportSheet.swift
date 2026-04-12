import SwiftUI

enum ExportTimeRange: String, CaseIterable {
    case lastHour = "Last Hour"
    case last24h = "Last 24 Hours"
    case last7d = "Last 7 Days"
    case all = "All Data"
    case custom = "Custom Range"
}

struct ExportSheet: View {
    let hostname: String
    let pingType: PingType
    let port: Int
    let totalRowCount: Int
    let dataProvider: (Date, Date) -> [ExportRow]

    @Environment(\.dismiss) private var dismiss
    @State private var timeRange: ExportTimeRange = .all
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var customEnd: Date = Date()
    @State private var format: ExportFormat = .csv
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Time Range") {
                    Picker("Range", selection: $timeRange) {
                        ForEach(ExportTimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }

                    if timeRange == .custom {
                        DatePicker("Start", selection: $customStart, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End", selection: $customEnd, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Format") {
                    Picker("Format", selection: $format) {
                        Text("CSV").tag(ExportFormat.csv)
                        Text("JSON").tag(ExportFormat.json)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Text("Estimated rows")
                        Spacer()
                        Text("\(totalRowCount)")
                            .foregroundStyle(TronTheme.accent)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(TronTheme.statusDown)
                    }
                }

                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Export")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
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

    private var dateRange: (start: Date, end: Date) {
        let now = Date()
        switch timeRange {
        case .lastHour: return (Calendar.current.date(byAdding: .hour, value: -1, to: now)!, now)
        case .last24h: return (Calendar.current.date(byAdding: .day, value: -1, to: now)!, now)
        case .last7d: return (Calendar.current.date(byAdding: .day, value: -7, to: now)!, now)
        case .all: return (.distantPast, now)
        case .custom: return (customStart, customEnd)
        }
    }

    private func performExport() {
        let range = dateRange
        let rows = dataProvider(range.start, range.end)
        do {
            let url = try ExportService.export(
                rows: rows, hostname: hostname, pingType: pingType, port: port, format: format
            )
            exportURL = url
            showShareSheet = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

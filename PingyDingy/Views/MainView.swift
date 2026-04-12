import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext

    @State var engine: MonitoringEngine
    let interfaceManager: InterfaceManager
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var showSort = false
    @State private var showFilter = false
    @State private var editingMonitor: HostMonitor?
    @State private var exportingMonitor: HostMonitor?
    @State private var deleteConfirmMonitor: HostMonitor?
    @State private var showDemoCleanupAlert = false

    // Config sharing state
    @State private var showShareConfig = false
    @State private var isMultiSelectMode = false
    @State private var selectedMonitorIDs: Set<UUID> = []
    @State private var importConfigFile: ConfigFile?
    @State private var showImportPreview = false

    #if canImport(UIKit)
    @State private var orientation = UIDeviceOrientation.portrait
    @State private var multiSelectExportURL: URL?
    @State private var showMultiSelectShareSheet = false
    #endif

    var body: some View {
        Group {
            #if canImport(UIKit)
            if sizeClass == .regular {
                iPadSplitView
            } else {
                if orientation.isLandscape {
                    landscapeView
                } else {
                    portraitView
                }
            }
            #else
            iPadSplitView // macOS always uses split view
            #endif
        }
        .background(TronTheme.background)
        .onAppear {
            engine.setModelContext(modelContext)
            engine.loadHosts()
            engine.setupInterfaceMonitoring()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isPortrait || newOrientation.isLandscape {
                orientation = newOrientation
            }
        }
        #endif
        .onOpenURL { url in
            handleIncomingConfigURL(url)
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditHostSheet(interfaceManager: interfaceManager) { form in
                let config = HostConfiguration(
                    hostname: form.hostname,
                    hostDescription: form.hostDescription.isEmpty ? nil : form.hostDescription,
                    pingType: form.pingType,
                    port: form.port,
                    intervalSeconds: form.intervalSeconds,
                    loggingEnabled: form.loggingEnabled,
                    perPingSoundEnabled: form.perPingSoundEnabled,
                    transitionSoundEnabled: form.transitionSoundEnabled,
                    networkInterface: form.networkInterface,
                    sortOrder: engine.monitors.count
                )
                engine.addHost(config)
            }
        }
        .sheet(item: $editingMonitor) { monitor in
            AddEditHostSheet(existingHost: findConfig(for: monitor), interfaceManager: interfaceManager) { form in
                engine.updateHost(monitor, with: form)
            }
        }
        .sheet(item: $exportingMonitor) { monitor in
            ExportSheet(
                hostname: monitor.hostname,
                pingType: monitor.pingType,
                port: monitor.port,
                totalRowCount: monitor.sentCount,
                dataProvider: { start, end in
                    engine.exportRows(for: monitor.id, start: start, end: end)
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(
                onMasterSoundChanged: { _ in },
                onClearAllData: { engine.clearAllData() }
            )
        }
        .sheet(isPresented: $showShareConfig) {
            ShareConfigSheet(
                allMonitors: engine.monitors,
                visibleMonitors: engine.filteredAndSortedMonitors,
                onExport: { monitors in
                    try engine.exportConfig(monitors: monitors)
                },
                onEnterMultiSelect: {
                    isMultiSelectMode = true
                    selectedMonitorIDs = []
                }
            )
        }
        .sheet(isPresented: $showImportPreview) {
            if let configFile = importConfigFile {
                ImportPreviewSheet(
                    preview: engine.buildImportPreview(from: configFile),
                    onImport: { preview in
                        engine.executeImport(preview)
                    }
                )
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showMultiSelectShareSheet) {
            if let url = multiSelectExportURL {
                ShareSheet(items: [url])
            }
        }
        #endif
        .alert("Delete Host?", isPresented: Binding(
            get: { deleteConfirmMonitor != nil },
            set: { if !$0 { deleteConfirmMonitor = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let monitor = deleteConfirmMonitor {
                    engine.removeHost(monitor)
                }
                deleteConfirmMonitor = nil
            }
            Button("Cancel", role: .cancel) { deleteConfirmMonitor = nil }
        } message: {
            Text("This will remove the host and all its monitoring data.")
        }
        .alert("Delete demo data?", isPresented: $showDemoCleanupAlert) {
            Button("Delete", role: .destructive) {
                engine.removeDemoMonitors()
            }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("Demo hosts are temporary. Remove them now, or keep them stopped.")
        }
    }

    private var portraitView: some View {
        VStack(spacing: 0) {
            MonitorToolbar(
                showSort: $showSort,
                showFilter: $showFilter,
                onStartAll: { engine.startAll() },
                onStopAll: {
    engine.stopAll()
    if engine.hasDemoMonitors {
        showDemoCleanupAlert = true
    }
},
                onAdd: { showAddSheet = true },
                onShareConfig: { showShareConfig = true },
                onSettings: { showSettings = true },
                hasHosts: !engine.monitors.isEmpty,
                isAnyRunning: engine.monitors.contains { $0.isRunning }
            )

            if showSort {
                SortBar(
                    sortOption: $engine.sortOption,
                    sortDirection: $engine.sortDirection
                )
            }

            if !engine.activeFilters.isEmpty || showFilter {
                FilterChipBar(activeFilters: $engine.activeFilters)
            }

            if engine.showRetentionReminder {
                retentionBanner
            }

            if engine.monitors.isEmpty {
                EmptyStateView(onLoadDemo: { engine.loadDemoData() })
            } else {
                HostCardListView(
                    monitors: engine.filteredAndSortedMonitors,
                    onEdit: { editingMonitor = $0 },
                    onDelete: { deleteConfirmMonitor = $0 },
                    onExport: { exportingMonitor = $0 },
                    onToggleMonitoring: { engine.toggleMonitoring(for: $0) },
                    isMultiSelectMode: isMultiSelectMode,
                    selectedMonitorIDs: $selectedMonitorIDs
                )
            }

            if isMultiSelectMode {
                multiSelectBar
            }
        }
    }

    private var landscapeView: some View {
        HistogramStackView(
            monitors: engine.filteredAndSortedMonitors,
            dataPointsProvider: { engine.pingDataPoints(for: $0) }
        )
    }

    private var iPadSplitView: some View {
        HStack(spacing: 0) {
            portraitView.frame(maxWidth: 420)
            Divider().background(TronTheme.accent.opacity(0.3))
            HistogramStackView(
                monitors: engine.filteredAndSortedMonitors,
                dataPointsProvider: { engine.pingDataPoints(for: $0) }
            )
        }
    }

    private var retentionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(TronTheme.dnsAlert)
            Text("Some hosts have log data older than 90 days. Consider exporting and clearing.")
                .font(.system(size: 12))
                .foregroundStyle(TronTheme.textPrimary.opacity(0.7))
            Spacer()
            Button {
                engine.showRetentionReminder = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(TronTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TronTheme.dnsAlert.opacity(0.1))
    }

    private var multiSelectBar: some View {
        HStack(spacing: 16) {
            Button {
                isMultiSelectMode = false
                selectedMonitorIDs = []
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TronTheme.textSecondary)
            }

            Spacer()

            Button {
                shareSelectedMonitors()
            } label: {
                Text("Share Selected (\(selectedMonitorIDs.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        selectedMonitorIDs.isEmpty
                            ? TronTheme.accent.opacity(0.4)
                            : TronTheme.accent
                    )
            }
            .disabled(selectedMonitorIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TronTheme.cardBg)
    }

    // MARK: - Helpers

    private func findConfig(for monitor: HostMonitor) -> HostConfiguration? {
        // Fetch all and filter in memory — SwiftData #Predicate with UUID
        // has known issues that can cause silent fetch failures
        let descriptor = FetchDescriptor<HostConfiguration>()
        guard let configs = try? modelContext.fetch(descriptor) else { return nil }
        return configs.first { $0.id == monitor.id }
    }

    private func handleIncomingConfigURL(_ url: URL) {
        do {
            let configFile = try ConfigFile.fromURL(url)
            importConfigFile = configFile
            showImportPreview = true
        } catch {
            // Silently ignore invalid files — could log in the future
        }
    }

    private func shareSelectedMonitors() {
        let selected = engine.monitors.filter { selectedMonitorIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        do {
            let url = try engine.exportConfig(monitors: selected)
            #if canImport(UIKit)
            multiSelectExportURL = url
            showMultiSelectShareSheet = true
            #endif
            isMultiSelectMode = false
            selectedMonitorIDs = []
        } catch {
            // Export failed — could surface error in the future
        }
    }
}

// HostMonitor needs Equatable + Hashable for sheet(item:)
extension HostMonitor: Equatable, Hashable {
    nonisolated public static func == (lhs: HostMonitor, rhs: HostMonitor) -> Bool {
        lhs.id == rhs.id
    }
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

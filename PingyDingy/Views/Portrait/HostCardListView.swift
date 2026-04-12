import SwiftUI

struct HostCardListView: View {
    let monitors: [HostMonitor]
    let onEdit: (HostMonitor) -> Void
    let onDelete: (HostMonitor) -> Void
    let onExport: (HostMonitor) -> Void
    let onToggleMonitoring: (HostMonitor) -> Void
    var isMultiSelectMode: Bool = false
    @Binding var selectedMonitorIDs: Set<UUID>

    var body: some View {
        List {
            ForEach(monitors) { monitor in
                if isMultiSelectMode {
                    HostCardView(monitor: monitor)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .overlay(alignment: .leading) {
                            Image(systemName: selectedMonitorIDs.contains(monitor.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(selectedMonitorIDs.contains(monitor.id)
                                                 ? TronTheme.accent : TronTheme.textSecondary.opacity(0.5))
                                .padding(.leading, 4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMonitorIDs.contains(monitor.id) {
                                selectedMonitorIDs.remove(monitor.id)
                            } else {
                                selectedMonitorIDs.insert(monitor.id)
                            }
                        }
                } else {
                    HostCardView(monitor: monitor)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDelete(monitor)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            if !monitor.isDemo {
                                Button {
                                    onEdit(monitor)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(TronTheme.accent)
                                Button {
                                    onExport(monitor)
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                onToggleMonitoring(monitor)
                            } label: {
                                Label(
                                    monitor.isRunning ? "Stop" : "Start",
                                    systemImage: monitor.isRunning ? "stop.fill" : "play.fill"
                                )
                            }
                            .tint(monitor.isRunning ? TronTheme.statusDown : TronTheme.statusUp)
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(TronTheme.background)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 20)
        }
    }
}

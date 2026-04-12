import SwiftUI

struct MonitorToolbar: View {
    @Binding var showSort: Bool
    @Binding var showFilter: Bool
    let onStartAll: () -> Void
    let onStopAll: () -> Void
    let onAdd: () -> Void
    let onShareConfig: () -> Void
    let onSettings: () -> Void
    let hasHosts: Bool
    let isAnyRunning: Bool

    var body: some View {
        HStack {
            // Left: Sort / Filter
            HStack(spacing: 12) {
                Button {
                    showSort.toggle()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16))
                        .foregroundStyle(TronTheme.accent)
                }
                .disabled(!hasHosts)

                Button {
                    showFilter.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16))
                        .foregroundStyle(TronTheme.accent)
                }
                .disabled(!hasHosts)
            }

            Spacer()

            // Center: Start All / Stop All
            HStack(spacing: 16) {
                Button {
                    onStartAll()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TronTheme.statusUp.opacity(isAnyRunning ? 0.25 : 1.0))
                }
                .disabled(!hasHosts)

                Button {
                    onStopAll()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TronTheme.statusDown.opacity(isAnyRunning ? 1.0 : 0.25))
                }
                .disabled(!hasHosts)
            }

            Spacer()

            // Right: Add / Share / Settings
            HStack(spacing: 12) {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(TronTheme.accent)
                }

                Button {
                    onShareConfig()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundStyle(TronTheme.accent)
                }
                .disabled(!hasHosts)

                Button {
                    onSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(TronTheme.accent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

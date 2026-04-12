import SwiftUI

struct HostCardView: View {
    var monitor: HostMonitor
    @State private var showDNSPopover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Row 1: IP (left) | display label (right)
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Text(monitor.resolvedIP.isEmpty ? "—" : monitor.resolvedIP)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(ipColor)
                        .lineLimit(1)

                    if monitor.dnsChanged {
                        Button("(?)") {
                            showDNSPopover = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TronTheme.dnsAlert)
                        .popover(isPresented: $showDNSPopover) {
                            Text("DNS re-resolution changed the IP address")
                                .font(.system(size: 13))
                                .padding()
                                .presentationCompactAdaptation(.popover)
                                .onDisappear {
                                    monitor.acknowledgeDNSChange()
                                }
                        }
                    }
                }

                Spacer()

                if let label = monitor.displayLabel {
                    Text(label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(TronTheme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Row 2: Protocol badge (left) | controls (right)
            HStack {
                Text(protocolLabel)
                    .protocolBadge(isDown: !monitor.isUp && monitor.sentCount > 0)

                if let ifaceName = monitor.interfaceDisplayName {
                    Text(ifaceName)
                        .protocolBadge(isDown: !monitor.interfaceAvailable)
                }

                Spacer()

                HStack(spacing: 10) {
                    // Per-ping sound toggle (speaker icon)
                    Button {
                        monitor.perPingSoundEnabled.toggle()
                    } label: {
                        Image(systemName: monitor.perPingSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(monitor.perPingSoundEnabled ? TronTheme.accent.opacity(0.8) : TronTheme.accent.opacity(0.2))
                    }
                    .buttonStyle(.plain)

                    // Transition alert toggle (target/scope icon)
                    Button {
                        monitor.transitionSoundEnabled.toggle()
                    } label: {
                        Image(systemName: monitor.transitionSoundEnabled ? "scope" : "circle.dashed")
                            .font(.system(size: 10))
                            .foregroundStyle(monitor.transitionSoundEnabled ? TronTheme.dnsAlert.opacity(0.8) : TronTheme.accent.opacity(0.2))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor.opacity(0.5), radius: 3)
                        Text(monitor.isRunning ? "ON" : "OFF")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                }
            }

            // Separator
            Rectangle()
                .fill(monitor.isUp || monitor.sentCount == 0 ? TronTheme.border : TronTheme.borderFail)
                .frame(height: 0.5)

            // Row 3: Stats
            HStack(spacing: 14) {
                StatCell(value: monitor.lastRTT.map { String(format: "%.0f", $0) } ?? "—", label: "ms", color: statColor)
                StatCell(value: monitor.avgRTT > 0 ? String(format: "%.0f", monitor.avgRTT) : "—", label: "avg", color: statColor.opacity(0.6))
                StatCell(value: "\(monitor.sentCount)", label: "sent", color: statColor)
                StatCell(value: "\(monitor.receivedCount)", label: "recv", color: statColor)
                StatCell(value: "\(monitor.lostCount)", label: "lost", color: lostColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(monitor.isUp || monitor.sentCount == 0 ? TronTheme.cardBg : TronTheme.cardBgFail)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .neonGlow(
            color: glowColor,
            isDown: !monitor.isUp && monitor.sentCount > 0
        )
    }

    private var protocolLabel: String {
        switch monitor.pingType {
        case .icmp: "ICMP"
        case .tcp: "TCP \(monitor.port)"
        }
    }

    private var ipColor: Color {
        if !monitor.interfaceAvailable { return TronTheme.dnsAlert }
        if monitor.dnsChanged { return TronTheme.accent }
        if monitor.sentCount == 0 { return TronTheme.accent }
        return monitor.isUp ? TronTheme.statusUp : TronTheme.statusDown
    }

    private var statusColor: Color {
        if !monitor.interfaceAvailable { return TronTheme.dnsAlert }
        if !monitor.isRunning { return TronTheme.accent.opacity(0.4) }
        if monitor.sentCount == 0 { return TronTheme.accent }
        return monitor.isUp ? TronTheme.statusUp : TronTheme.statusDown
    }

    private var statColor: Color {
        if !monitor.interfaceAvailable { return TronTheme.dnsAlert }
        if monitor.sentCount == 0 { return TronTheme.accent }
        return monitor.isUp ? TronTheme.statusUp : TronTheme.statusDown
    }

    private var lostColor: Color {
        if monitor.lostCount > 0 { return TronTheme.statusDown }
        return statColor
    }

    private var glowColor: Color {
        if !monitor.interfaceAvailable { return TronTheme.dnsAlert }
        if monitor.sentCount == 0 { return TronTheme.accent }
        return monitor.isUp ? TronTheme.statusUp : TronTheme.statusDown
    }
}

struct StatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(TronTheme.textSecondary)
        }
    }
}

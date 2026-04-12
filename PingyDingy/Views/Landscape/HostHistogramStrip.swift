import SwiftUI

struct PingDataPoint: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let rttMs: Double?
    let success: Bool
}

enum HistogramMetric: String, CaseIterable, Sendable {
    case rttNow = "RTT (now)"
    case rttAvg = "RTT (avg)"
    case countSent = "Sent"
    case countLost = "Lost"
    case countReceived = "Received"

    func next() -> HistogramMetric {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

struct HostHistogramStrip: View {
    let monitor: HostMonitor
    let dataPoints: [PingDataPoint]

    @State private var metric: HistogramMetric = .rttNow
    @State private var timeWindowSeconds: Double = 300 // 5 minutes
    @GestureState private var pinchScale: CGFloat = 1.0

    private let minWindow: Double = 30
    private let maxWindow: Double = 3600

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let label = monitor.displayLabel {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TronTheme.textPrimary)
                }
                Text(monitor.resolvedIP)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(TronTheme.accent)

                Text(monitor.pingType == .icmp ? "ICMP" : "TCP \(monitor.port)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(TronTheme.accent.opacity(0.4))

                if let ifaceName = monitor.interfaceDisplayName {
                    Text("[\(ifaceName)]")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(monitor.interfaceAvailable ? TronTheme.accent : TronTheme.dnsAlert)
                }

                Spacer()

                Text("interval: \(monitor.intervalSeconds)s")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TronTheme.accent)

                Spacer()

                Text(metric.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TronTheme.accent)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(TronTheme.accent.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Canvas graph
            let currentMetric = metric
            let currentPinchScale = pinchScale
            let currentWindow = timeWindowSeconds
            let currentMinWindow = minWindow
            let currentMaxWindow = maxWindow
            let currentDataPoints = dataPoints
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    drawGraph(
                        context: context,
                        size: size,
                        now: timeline.date,
                        metric: currentMetric,
                        pinchScale: currentPinchScale,
                        timeWindowSeconds: currentWindow,
                        minWindow: currentMinWindow,
                        maxWindow: currentMaxWindow,
                        dataPoints: currentDataPoints
                    )
                }
            }
            .frame(height: 80)
            .background(TronTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onTapGesture {
                metric = metric.next()
            }
            .gesture(
                MagnifyGesture()
                    .updating($pinchScale) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        let newWindow = timeWindowSeconds / Double(value.magnification)
                        timeWindowSeconds = max(minWindow, min(maxWindow, newWindow))
                    }
            )

            // Time axis labels
            HStack {
                Text(timeLabel(secondsAgo: timeWindowSeconds))
                Spacer()
                Text(timeLabel(secondsAgo: timeWindowSeconds * 0.75))
                Spacer()
                Text(timeLabel(secondsAgo: timeWindowSeconds * 0.5))
                Spacer()
                Text(timeLabel(secondsAgo: timeWindowSeconds * 0.25))
                Spacer()
                Text("now")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(TronTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
        .padding(6)
        .background(TronTheme.background)
        .neonGlow(color: TronTheme.accent)
    }

    // MARK: - Drawing

    private func drawGraph(
        context: GraphicsContext,
        size: CGSize,
        now: Date,
        metric: HistogramMetric,
        pinchScale: CGFloat,
        timeWindowSeconds: Double,
        minWindow: Double,
        maxWindow: Double,
        dataPoints: [PingDataPoint]
    ) {
        let effectiveWindow = timeWindowSeconds / Double(pinchScale)
        let clampedWindow = max(minWindow, min(maxWindow, effectiveWindow))
        let windowStart = now.addingTimeInterval(-clampedWindow)
        let graphHeight = size.height - 4
        let graphBottom = size.height - 2

        // Draw grid
        let gridColor = TronTheme.accent.opacity(0.1)
        for i in 1...3 {
            let y = size.height * Double(i) / 4.0
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        let visible = dataPoints.filter { $0.timestamp >= windowStart && $0.timestamp <= now }
        guard !visible.isEmpty else { return }

        // Fixed bar width: each bar represents one interval tick
        // Use 3px minimum, or scale by pixels-per-second if the window is small
        let pixelsPerSecond = size.width / clampedWindow
        let barWidth = max(2, min(pixelsPerSecond * 0.8, 8))
        let barGap: Double = 1

        // Compute values and find max for Y-axis scaling
        let values: [(x: Double, value: Double, success: Bool)]
        switch metric {
        case .rttNow:
            values = visible.map { point in
                let x = xPosition(for: point.timestamp, windowStart: windowStart, windowSeconds: clampedWindow, width: size.width)
                return (x: x, value: point.rttMs ?? 0, success: point.success)
            }
        case .rttAvg:
            var sum: Double = 0
            var count: Double = 0
            values = visible.map { point in
                let x = xPosition(for: point.timestamp, windowStart: windowStart, windowSeconds: clampedWindow, width: size.width)
                if let rtt = point.rttMs { sum += rtt; count += 1 }
                return (x: x, value: count > 0 ? sum / count : 0, success: point.success)
            }
        case .countSent:
            var cumulative: Double = 0
            values = visible.map { point in
                cumulative += 1
                let x = xPosition(for: point.timestamp, windowStart: windowStart, windowSeconds: clampedWindow, width: size.width)
                return (x: x, value: cumulative, success: point.success)
            }
        case .countLost:
            var cumulative: Double = 0
            values = visible.map { point in
                if !point.success { cumulative += 1 }
                let x = xPosition(for: point.timestamp, windowStart: windowStart, windowSeconds: clampedWindow, width: size.width)
                return (x: x, value: cumulative, success: cumulative == 0)
            }
        case .countReceived:
            var cumulative: Double = 0
            values = visible.map { point in
                if point.success { cumulative += 1 }
                let x = xPosition(for: point.timestamp, windowStart: windowStart, windowSeconds: clampedWindow, width: size.width)
                return (x: x, value: cumulative, success: true)
            }
        }

        let maxValue = max(values.map(\.value).max() ?? 1, 1)

        // Draw bars from left to right — each bar grows up from the bottom
        for point in values {
            let barHeight = (point.value / maxValue) * graphHeight
            guard barHeight > 0 else { continue }
            let rect = CGRect(
                x: point.x - (barWidth + barGap) / 2,
                y: graphBottom - barHeight,
                width: barWidth,
                height: barHeight
            )
            let color: Color = point.success ? TronTheme.statusUp : TronTheme.statusDown
            context.fill(Path(rect), with: .color(color.opacity(0.8)))
        }
    }

    /// Map a timestamp to an x position within the graph.
    /// windowStart is on the left edge (x=0), now is on the right edge (x=width).
    private func xPosition(for timestamp: Date, windowStart: Date, windowSeconds: Double, width: Double) -> Double {
        let elapsed = timestamp.timeIntervalSince(windowStart)
        return (elapsed / windowSeconds) * width
    }

    private func timeLabel(secondsAgo: Double) -> String {
        if secondsAgo < 60 { return "-\(Int(secondsAgo))s" }
        return "-\(Int(secondsAgo / 60))m"
    }
}

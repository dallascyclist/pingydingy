import SwiftUI

struct HistogramStackView: View {
    let monitors: [HostMonitor]
    let dataPointsProvider: (UUID) -> [PingDataPoint]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(monitors) { monitor in
                    HostHistogramStrip(
                        monitor: monitor,
                        dataPoints: dataPointsProvider(monitor.id)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(TronTheme.background)
    }
}

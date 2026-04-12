import SwiftUI

struct DNSChangePopover: View {
    let previousIP: String
    let currentIP: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DNS Change Detected")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TronTheme.dnsAlert)

            HStack {
                Text("Previous:")
                    .font(.system(size: 12))
                    .foregroundStyle(TronTheme.textSecondary)
                Text(previousIP)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TronTheme.textPrimary)
            }

            HStack {
                Text("Current:")
                    .font(.system(size: 12))
                    .foregroundStyle(TronTheme.textSecondary)
                Text(currentIP)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TronTheme.accent)
            }

            Text("DNS re-resolution changed the IP address for this host.")
                .font(.system(size: 11))
                .foregroundStyle(TronTheme.textSecondary)
        }
        .padding(16)
        .background(TronTheme.cardBg)
    }
}

import SwiftUI

struct EmptyStateView: View {
    let onLoadDemo: () -> Void

    @State private var glowOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(TronTheme.accent)
                .shadow(color: TronTheme.accent.opacity(glowOpacity), radius: 12)

            Text("Tap + to add your first host")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(TronTheme.textPrimary.opacity(0.7))

            HStack(spacing: 4) {
                Text("Or load")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(TronTheme.textPrimary.opacity(0.5))

                Button {
                    onLoadDemo()
                } label: {
                    Text("demo hosts")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TronTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TronTheme.accent.opacity(0.2))
                        .clipShape(Capsule())
                }

                Text("to try it out")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(TronTheme.textPrimary.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TronTheme.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
    }
}

import SwiftUI

struct NeonGlowBorder: ViewModifier {
    let color: Color
    let isDown: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDown ? TronTheme.borderFail : TronTheme.border, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.clear, color, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 0)
    }
}

struct NeonChipStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TronTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(TronTheme.chipBg)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(TronTheme.accent.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ProtocolBadge: ViewModifier {
    let isDown: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 9, weight: .medium))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(isDown ? TronTheme.statusDown : TronTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isDown ? TronTheme.statusDown : TronTheme.accent).opacity(0.13)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

extension View {
    func neonGlow(color: Color, isDown: Bool = false) -> some View {
        modifier(NeonGlowBorder(color: color, isDown: isDown))
    }

    func neonChip() -> some View {
        modifier(NeonChipStyle())
    }

    func protocolBadge(isDown: Bool = false) -> some View {
        modifier(ProtocolBadge(isDown: isDown))
    }
}

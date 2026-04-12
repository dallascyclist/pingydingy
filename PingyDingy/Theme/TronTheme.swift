import SwiftUI

enum TronTheme {
    static let background = adaptiveColor(
        dark: Color(red: 0, green: 0, blue: 0.067),
        light: Color(red: 0.961, green: 0.961, blue: 0.98)
    )
    static let cardBg = adaptiveColor(
        dark: Color(red: 0, green: 0, blue: 0.133),
        light: .white
    )
    static let cardBgFail = adaptiveColor(
        dark: Color(red: 0.067, green: 0, blue: 0),
        light: Color(red: 1, green: 0.961, blue: 0.961)
    )
    static let accent = adaptiveColor(
        dark: Color(red: 0.267, green: 0.533, blue: 1),
        light: Color(red: 0.133, green: 0.333, blue: 0.8)
    )
    static let statusUp = adaptiveColor(
        dark: Color(red: 0, green: 1, blue: 0.533),
        light: Color(red: 0, green: 0.667, blue: 0.333)
    )
    static let statusDown = adaptiveColor(
        dark: Color(red: 1, green: 0.267, blue: 0.267),
        light: Color(red: 0.8, green: 0.133, blue: 0.133)
    )
    static let dnsAlert = adaptiveColor(
        dark: Color(red: 1, green: 0.667, blue: 0),
        light: Color(red: 0.8, green: 0.533, blue: 0)
    )
    static let textPrimary = adaptiveColor(
        dark: .white,
        light: Color(red: 0.067, green: 0.067, blue: 0.067)
    )
    static let textSecondary = adaptiveColor(
        dark: Color(red: 0.267, green: 0.533, blue: 1).opacity(0.27),
        light: Color(red: 0.133, green: 0.267, blue: 0.533).opacity(0.27)
    )
    static let border = adaptiveColor(
        dark: Color(red: 0.267, green: 0.533, blue: 1).opacity(0.2),
        light: Color(red: 0.133, green: 0.333, blue: 0.8).opacity(0.13)
    )
    static let borderFail = adaptiveColor(
        dark: Color(red: 1, green: 0.267, blue: 0.267).opacity(0.2),
        light: Color(red: 0.8, green: 0.133, blue: 0.133).opacity(0.13)
    )
    static let chipBg = adaptiveColor(
        dark: Color(red: 0.267, green: 0.533, blue: 1).opacity(0.13),
        light: Color(red: 0.133, green: 0.333, blue: 0.8).opacity(0.08)
    )

    private static func adaptiveColor(dark: Color, light: Color) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
        #else
        dark
        #endif
    }
}

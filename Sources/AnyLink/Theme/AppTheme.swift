import SwiftUI

enum AppTheme {
    static let accent = Color(hex: 0x0a84ff)
    static let accentEnd = Color(hex: 0x0060df)
    static let success = Color(hex: 0x34c759)

    static let accentGradient = LinearGradient(
        colors: [accent, accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadiusControl: CGFloat = 9
    static let cornerRadiusCard: CGFloat = 12

    static let background = Color.themed(light: 0xf5f5f7, dark: 0x1e1e1e)
    static let card = Color.themed(light: 0xffffff, dark: 0x2c2c2e)
    static let primaryText = Color.themed(light: 0x1d1d1f, dark: 0xf5f5f7)
    static let secondaryText = Color.themed(light: 0x6e6e73, dark: 0xa1a1a6)
    static let border = Color.themed(light: 0x000000, dark: 0xffffff)
        .opacity(0.08)
}

extension Color {
    static func themed(light: UInt, dark: UInt) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(isDark ? Color(hex: dark) : Color(hex: light))
        })
    }

    init(hex: UInt) {
        self.init(
            nsColor: NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xff) / 255.0,
                green: CGFloat((hex >> 8) & 0xff) / 255.0,
                blue: CGFloat(hex & 0xff) / 255.0,
                alpha: 1.0
            )
        )
    }
}

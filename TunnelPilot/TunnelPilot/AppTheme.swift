import AppKit
import SwiftUI

enum AppTheme {
    static let accent = Color(hex: 0x0A84FF)
    static let accentDeep = Color(hex: 0x0060DF)
    static let success = Color(hex: 0x34C759)
    static let warning = Color(hex: 0xFF9F0A)
    static let danger = Color(hex: 0xFF453A)

    static let pageBackground = adaptive(light: 0xF5F5F7, dark: 0x191A1F)
    static let sidebarBackground = adaptive(light: 0xF5F5F7, dark: 0x1C1D22)
    static let cardBackground = adaptive(light: 0xFFFFFF, dark: 0x27282E)
    static let controlBackground = adaptive(light: 0xF4F4F6, dark: 0x1F2026)
    static let sidebarCardBackground = adaptive(light: 0xE2F2E6, dark: 0x21352A)
    static let footerBackground = adaptive(light: 0xF1F1F3, dark: 0x222329)
    static let border = adaptive(light: 0xE0E0E3, dark: 0x3A3B42)

    static let cardRadius: CGFloat = 14
    static let controlRadius: CGFloat = 9
    static let buttonGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 生成适配深浅色的动态颜色。
    /// 必须 nonisolated：工程默认 MainActor 隔离，NSColor 的动态 provider
    /// 闭包会被 AppKit 在任意线程（如 SwiftUI DisplayLink 渲染队列）调用，
    /// 若闭包继承 MainActor 隔离会触发 executor 断言崩溃
    /// （macOS 15.x 上打开设置页闪退，EXC_BREAKPOINT）。
    nonisolated private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let value = isDark ? dark : light

            return NSColor(
                calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct TunnelCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }
}

extension View {
    func tunnelCard() -> some View {
        modifier(TunnelCardModifier())
    }
}

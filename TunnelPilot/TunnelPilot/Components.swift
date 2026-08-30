import SwiftUI

struct PageHeader: View {
    let section: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(section.title)
                .font(.system(size: 27, weight: .bold, design: .rounded))

            Text(section.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.top, 22)
        .padding(.bottom, 10)
        .background(AppTheme.pageBackground)
    }
}

struct ConnectionStateBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)

            Text(state.statusBarText)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private var stateColor: Color {
        switch state {
        case .connected: return AppTheme.success
        case .connecting, .disconnecting: return AppTheme.warning
        case .failed: return AppTheme.danger
        case .disconnected: return .secondary
        }
    }
}

struct CardTitle: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(_ title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 30, height: 30)
                .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LogoMark: View {
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "bolt.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: AppTheme.accent.opacity(0.28), radius: 10, y: 5)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String
    var isBadge = false

    var body: some View {
        HStack(spacing: 20) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            if isBadge {
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.11), in: Capsule())
            } else {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 8)
    }
}

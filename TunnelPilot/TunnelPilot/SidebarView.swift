import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var pulse = false

    private static let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                LogoMark(size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("隧道助手")
                        .font(.system(size: 16, weight: .bold))

                    Text("版本 \(Self.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 28)

            VStack(spacing: 3) {
                ForEach(AppSection.allCases) { section in
                    SidebarItem(
                        section: section,
                        isSelected: selection == section,
                        action: { selection = section }
                    )
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Circle()
                        .fill(stateColor)
                        .frame(width: 9, height: 9)
                }
                    .scaleEffect(connectionManager.connectionState == .connected && pulse ? 1.35 : 1)
                    .animation(
                        connectionManager.connectionState == .connected
                            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                            : .default,
                        value: pulse
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionManager.connectionState.statusBarText)
                        .font(.system(size: 12, weight: .semibold))
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(AppTheme.sidebarCardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(AppTheme.sidebarBackground)
        .onAppear { pulse = true }
    }

    private var stateColor: Color {
        switch connectionManager.connectionState {
        case .connected: return AppTheme.success
        case .connecting, .disconnecting, .reconnecting: return AppTheme.warning
        case .failed: return AppTheme.danger
        case .disconnected: return .secondary
        }
    }
}

private struct SidebarItem: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 22)

                Text(section.title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))

                Spacer()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                isSelected ? AppTheme.accent : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

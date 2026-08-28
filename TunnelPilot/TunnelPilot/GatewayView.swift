import SwiftUI

struct GatewayView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GatewayHeroCard()
                GatewayFormCard {
                    openWindow(id: "profile-manager")
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }
}

private struct GatewayHeroCard: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if connectionManager.connectionState.isTransitioning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Circle()
                            .fill(.white.opacity(0.92))
                            .frame(width: 8, height: 8)
                    }

                    Text(connectionManager.connectionState.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(connectionManager.connectionState == .connected
                    ? connectionManager.selectedGateway.address
                    : connectionManager.connectionState.detail)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            Button(action: connectionManager.toggleConnection) {
                HStack(spacing: 8) {
                    if connectionManager.connectionState.isTransitioning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else if connectionManager.connectionState != .connected {
                        Image(systemName: connectionManager.actionSymbol)
                    }

                    Text(connectionManager.actionTitle)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 22)
                .frame(height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(0.2), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .disabled(!connectionManager.canToggleConnection)
            .opacity(connectionManager.canToggleConnection ? 1 : 0.65)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(height: 84)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: AppTheme.accent.opacity(0.18), radius: 20, y: 9)
    }

    private var heroGradient: LinearGradient {
        switch connectionManager.connectionState {
        case .connected:
            return LinearGradient(
                colors: [Color(hex: 0x1495FF), Color(hex: 0x0566E6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .failed:
            return LinearGradient(
                colors: [Color(hex: 0xF05B68), Color(hex: 0xC53042)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .connecting, .disconnecting:
            return LinearGradient(
                colors: [Color(hex: 0x4F9DFF), Color(hex: 0x2A72D8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .disconnected:
            return LinearGradient(
                colors: [Color(hex: 0x1495FF), Color(hex: 0x0566E6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GatewayFormCard: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    let openProfileManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("主机")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    NativePopupButton(
                        titles: connectionManager.gateways.map(\.displayName),
                        isEnabled: !connectionManager.connectionState.isConnected,
                        selection: selectedGatewayIndex
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        AppTheme.controlBackground,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
                    .opacity(connectionManager.connectionState.isConnected ? 0.6 : 1)

                    Button(action: openProfileManager) {
                        ZStack {
                            Color.clear

                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .frame(width: 36, height: 36)
                        .contentShape(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                    }
                    .buttonStyle(IconSquareButtonStyle())
                    .help("管理配置")
                    .disabled(connectionManager.connectionState.isConnected)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("OTP 临时密码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                SecureField("请输入临时密码", text: $connectionManager.otp)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AppTheme.controlBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
                    .disabled(connectionManager.connectionState.isConnected)
                    .opacity(connectionManager.connectionState.isConnected ? 0.6 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tunnelCard()
    }

    private var selectedGatewayIndex: Binding<Int> {
        Binding(
            get: {
                connectionManager.gateways.firstIndex {
                    $0.id == connectionManager.selectedGatewayID
                } ?? 0
            },
            set: { index in
                guard connectionManager.gateways.indices.contains(index) else { return }
                connectionManager.selectedGatewayID = connectionManager.gateways[index].id
            }
        )
    }
}

// MARK: - 方形图标按钮样式（含 hover / 按下反馈）

private struct IconSquareButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isHovering ? AppTheme.accent.opacity(0.6) : AppTheme.border,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return AppTheme.accent.opacity(0.18)
        } else if isHovering {
            return AppTheme.accent.opacity(0.10)
        } else {
            return AppTheme.cardBackground
        }
    }
}

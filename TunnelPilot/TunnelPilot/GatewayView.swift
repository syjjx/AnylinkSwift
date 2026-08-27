import SwiftUI

struct GatewayView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GatewayHeroCard()
                GatewayFormCard(openProfileManager: { openWindow(id: "profile-manager") })
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
                colors: [Color(hex: 0x168EFF), Color(hex: 0x1265D5)],
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("主机")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Picker("网关", selection: $connectionManager.selectedGatewayID) {
                        ForEach(connectionManager.gateways) { gateway in
                            Text(gateway.displayName)
                                .tag(gateway.id)
                        }
                }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(AppTheme.controlBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }

                    Button {
                        openProfileManager()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
                    .help("管理配置")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("OTP 临时密码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                SecureField("请输入临时密码", text: $connectionManager.otp)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(AppTheme.controlBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .tunnelCard()
    }
}

private struct AddGatewaySheet: View {
    @Binding var address: String
    let add: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("添加网关")
                .font(.title3.weight(.semibold))

            Text("输入服务器地址和可选端口，以保存一个网关配置。")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("服务器地址:443", text: $address)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)

            HStack {
                Spacer()

                Button("取消", action: cancel)
                    .keyboardShortcut(.cancelAction)

                Button("添加", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 410)
    }
}

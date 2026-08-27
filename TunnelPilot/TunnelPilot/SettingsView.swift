import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingRow(
                        title: "启动时自动连接",
                        description: "打开应用后自动连接最近使用的 VPN",
                        isOn: binding(for: \AppSettings.autoConnect)
                    )
                    SettingRow(
                        title: "连接后最小化",
                        description: "VPN 连接成功后自动最小化",
                        isOn: binding(for: \AppSettings.minimizeOnConnect)
                    )
                    SettingRow(
                        title: "证书不可信时终止",
                        description: "若服务器证书不可信，中止连接",
                        isOn: binding(for: \AppSettings.blockUntrustedServers)
                    )
                    SettingRow(
                        title: "启用调试日志",
                        description: "记录详细日志以便排查问题",
                        isOn: binding(for: \AppSettings.debugLogging)
                    )
                    SettingRow(
                        title: "兼容思科协议",
                        description: "与思科 AnyConnect 协议兼容",
                        isOn: binding(for: \AppSettings.ciscoCompatibility)
                    )
                    SettingRow(
                        title: "不使用 DTLS 通道",
                        description: "仅使用 TLS 传输",
                        isOn: binding(for: \AppSettings.disableDTLS)
                    )
                    SettingRow(
                        title: "界面使用本地语言",
                        description: "跟随系统语言显示界面",
                        isOn: binding(for: \AppSettings.useLocalLanguage),
                        isLast: true
                    )
                }
                .padding(.horizontal, 21)
                .padding(.vertical, 8)
                .tunnelCard()
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }

    private func binding(for keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { connectionManager.settings[keyPath: keyPath] },
            set: { connectionManager.settings[keyPath: keyPath] = $0 }
        )
    }
}

private struct SettingRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    var isLast = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.medium))

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppTheme.success)
            }

            if !isLast {
                Divider()
            }
        }
        .padding(.vertical, 12)
    }
}

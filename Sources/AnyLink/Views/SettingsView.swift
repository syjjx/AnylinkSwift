import SwiftUI

struct SettingsView: View {
    @AppStorage("auto_connect") private var autoConnect = false
    @AppStorage("minimize_on_connect") private var minimizeOnConnect = false
    @AppStorage("block_untrusted_cert") private var blockUntrustedCert = true
    @AppStorage("debug_log") private var debugLog = false
    @AppStorage("cisco_compat") private var ciscoCompat = false
    @AppStorage("no_dtls") private var noDtls = false
    @AppStorage("use_local_language") private var useLocalLanguage = false

    var body: some View {
        ScrollView {
            VStack {
                settingCard
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var settingCard: some View {
        VStack(spacing: 0) {
            setting("启动后自动连接", description: "应用启动后自动连接上次使用的网关", isOn: $autoConnect)
            setting("连接后最小化窗口", description: "连接成功后自动隐藏窗口到菜单栏", isOn: $minimizeOnConnect)
            setting("证书不可信时终止", description: "服务器证书校验失败时立即中断连接", isOn: $blockUntrustedCert)
            setting("开启调试日志", description: "记录详细的连接日志，便于排查问题", isOn: $debugLog)
            setting("兼容思科协议", description: "使用 Cisco 兼容模式连接服务器", isOn: $ciscoCompat)
            setting("不使用 DTLS 通道", description: "仅通过 TLS 通道传输数据", isOn: $noDtls)
            setting("界面使用本地语言", description: "跟随系统语言显示界面", isOn: $useLocalLanguage)
        }
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard))
    }

    private func setting(_ title: String, description: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.primaryText)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

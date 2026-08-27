import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var manager: ConnectionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusCard
                Button("查看详情") {
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var statusCard: some View {
        VStack(spacing: 0) {
            row("通道类型", value: manager.status.channelType, badge: true)
            row("TLS 加密套件", value: manager.status.tlsCipherSuite)
            row("DTLS 加密套件", value: manager.status.dtlsCipherSuite)
            row("DTLS 端口", value: manager.status.dtlsPort)
            row("服务器地址", value: manager.status.serverAddress)
            row("本地地址", value: manager.status.localAddress)
            row("VPN 地址", value: manager.status.vpnAddress)
            row("MTU", value: manager.status.mtu > 0 ? String(manager.status.mtu) : "—")
            row("DNS", value: manager.status.dns.isEmpty ? "—" : manager.status.dns.joined(separator: ","))
        }
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard))
    }

    private func row(_ key: String, value: String, badge: Bool = false) -> some View {
        HStack {
            Text(key)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            if badge {
                Text(value)
                    .font(.body.monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.accent, in: Capsule())
            } else {
                Text(value)
                    .font(.body.monospaced())
                    .foregroundStyle(AppTheme.primaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

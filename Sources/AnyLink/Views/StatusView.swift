import SwiftUI

struct StatusView: View {
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
            row("通道类型", value: "TLS", badge: true)
            row("TLS 加密套件", value: "ECDHE-RSA-AES256-GCM-SHA384")
            row("DTLS 加密套件", value: "—")
            row("DTLS 端口", value: "—")
            row("服务器地址", value: "ppp111p.72kg.top")
            row("本地地址", value: "192.168.1.100")
            row("VPN 地址", value: "—")
            row("MTU", value: "1399")
            row("DNS", value: "—")
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

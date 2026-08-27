import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var manager: ConnectionManager

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text("AnyLink Secure Client")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(AppTheme.card)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var statusColor: Color {
        switch manager.state {
        case .connected: AppTheme.success
        case .connecting, .reconnecting: AppTheme.warning
        case .failed: .red
        case .idle: AppTheme.secondaryText
        }
    }

    private var statusText: String {
        switch manager.state {
        case .connected: "已连接到 " + (manager.connectedHost ?? "")
        case .connecting: "正在连接…"
        case .reconnecting: "正在重连…"
        case .failed: "连接失败"
        case .idle: "未连接"
        }
    }
}

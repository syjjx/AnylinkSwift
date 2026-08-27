import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 24))
            Text("AnyLink Secure Client")
                .font(.title2.weight(.semibold))
            Text("An SSL VPN client for AnyLink / OpenConnect servers")
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
            HStack(spacing: 12) {
                Button {
                } label: {
                    Label("连接日志", systemImage: "doc.text")
                }
                Button {
                } label: {
                    Label("安全提醒", systemImage: "shield")
                }
            }
            .buttonStyle(.bordered)
            HStack(spacing: 20) {
                Link("获取帮助", destination: URL(string: "https://tlslink.com")!)
                Link("检查更新", destination: URL(string: "https://github.com/tlslink/anylink-client/releases")!)
            }
            .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.background)
    }
}

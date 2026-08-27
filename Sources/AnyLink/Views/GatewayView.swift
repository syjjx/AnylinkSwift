import SwiftUI

struct GatewayView: View {
    @State private var selectedHost = "ppp111p.72kg.top:4321"
    @State private var otp = ""
    @State private var isConnected = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectCard
                hostCard
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var connectCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(isConnected ? "已连接" : "未连接")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text(selectedHost)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button {
                isConnected.toggle()
            } label: {
                Text(isConnected ? "断开" : "连接")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    private var hostCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Picker("主机", selection: $selectedHost) {
                    Text("ppp111p.72kg.top:4321").tag("ppp111p.72kg.top:4321")
                    Text("abc.72k.cn:443").tag("abc.72k.cn:443")
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }
            SecureField("OTP 临时密码（可选）", text: $otp)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

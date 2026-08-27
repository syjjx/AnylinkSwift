import SwiftUI

struct HelpView: View {
    @State private var activeSheet: HelpSheet?

    var body: some View {
        VStack(spacing: 24) {
            LogoMark()

            VStack(spacing: 6) {
                Text("隧道助手")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("面向苹果电脑的安全隧道客户端")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("版本 0.1.0  |  界面预览")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                HelpActionButton(title: "连接日志", systemImage: "doc.text") {
                    activeSheet = .logs
                }

                HelpActionButton(title: "安全提示", systemImage: "shield") {
                    activeSheet = .security
                }
            }

            HStack(spacing: 18) {
                Link("获取帮助", destination: URL(string: "https://github.com/syjjx/AnylinkSwift/issues")!)
                Link("项目主页", destination: URL(string: "https://github.com/syjjx/AnylinkSwift")!)
                Link("检查更新", destination: URL(string: "https://github.com/syjjx/AnylinkSwift/releases")!)
            }
            .font(.callout)
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .sheet(item: $activeSheet) { sheet in
            HelpSheetView(sheet: sheet)
        }
    }
}

private struct HelpActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private enum HelpSheet: String, Identifiable {
    case logs
    case security

    var id: String { rawValue }
}

private struct HelpSheetView: View {
    let sheet: HelpSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(sheet == .logs ? "连接日志" : "安全提示")
                    .font(.title3.weight(.semibold))

                Spacer()

                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            if sheet == .logs {
                Text("暂时没有连接日志。真实通信服务尚未在此界面预览中启用。")
                    .foregroundStyle(.secondary)
            } else {
                Text("请只连接到信任的网关。证书验证和虚拟专用网络权限将在接入真实通信服务时加入。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

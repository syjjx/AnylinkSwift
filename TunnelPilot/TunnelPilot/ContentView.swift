//
//  ContentView.swift
//  TunnelPilot
//
//  Created by 沈寅佳 on 2026/8/27.
//

import SwiftUI

struct ContentView: View {
    let appDelegate: AppDelegate
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var selection: AppSection = .gateway

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var body: some View {
        VStack(spacing: 0) {
            if connectionManager.agentState != .installed {
                AgentInstallBanner()
            }

            HStack(spacing: 0) {
                SidebarView(selection: $selection)
                    .frame(width: 172)

                Divider()

                VStack(spacing: 0) {
                    PageHeader(section: selection)

                    page
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(AppTheme.pageBackground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView()
        }
        .background(AppTheme.pageBackground)
        .frame(width: 820, height: 600)
        .overlay {
            WindowAccessor(appDelegate: appDelegate)
                .frame(width: 0, height: 0)
        }
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .gateway:
            GatewayView()
        case .status:
            StatusView()
        case .settings:
            SettingsView()
        case .help:
            HelpView()
        }
    }
}

/// VPN 服务组件未安装或指向旧版本时显示的顶部横幅。
private struct AgentInstallBanner: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: connectionManager.agentState == .outdated
                ? "arrow.triangle.2.circlepath"
                : "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)

            Text(bannerText)
                .font(.callout)

            Spacer()

            Button {
                Task { await connectionManager.installAgent() }
            } label: {
                Text(connectionManager.isAgentBusy ? "安装中…" : "立即安装")
                    .frame(minWidth: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(connectionManager.isAgentBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            AppTheme.warning.opacity(0.14),
            in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.warning.opacity(0.5), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(AppTheme.pageBackground)
    }

    private var bannerText: String {
        switch connectionManager.agentState {
        case .outdated:
            return "VPN 服务指向旧版本应用，安装后将使用当前应用"
        case .missing:
            return "VPN 服务组件未安装，安装后即可连接"
        case .installed:
            return ""
        }
    }
}

#Preview {
    ContentView(appDelegate: AppDelegate())
        .environmentObject(ConnectionManager())
}

//
//  TunnelPilotApp.swift
//  TunnelPilot
//
//  Created by 沈寅佳 on 2026/8/27.
//

import SwiftUI

@main
struct TunnelPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup("隧道助手 安全客户端", id: "main") {
            ContentView(appDelegate: appDelegate)
                .environmentObject(connectionManager)
        }
        .windowResizability(.contentSize)

        Window("流量统计和路由详情", id: "connection-details") {
            ConnectionDetailsView()
                .environmentObject(connectionManager)
        }
        .defaultSize(width: 760, height: 560)
        .windowResizability(.contentSize)

        Window("配置管理", id: "profile-manager") {
            ProfileManagerView()
                .environmentObject(connectionManager)
        }
        .defaultSize(width: 720, height: 520)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContent(appDelegate: appDelegate)
                .environmentObject(connectionManager)
        } label: {
            MenuBarStatusIcon(state: connectionManager.connectionState)
        }
        .menuBarExtraStyle(.menu)
    }
}

//
//  ContentView.swift
//  TunnelPilot
//
//  Created by 沈寅佳 on 2026/8/27.
//

import SwiftUI

struct ContentView: View {
    let appDelegate: AppDelegate
    @State private var selection: AppSection = .gateway

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var body: some View {
        VStack(spacing: 0) {
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

#Preview {
    ContentView(appDelegate: AppDelegate())
        .environmentObject(ConnectionManager())
}

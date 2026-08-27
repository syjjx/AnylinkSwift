import AppKit
import SwiftUI

struct MenuBarStatusIcon: View {
    let state: ConnectionState

    var body: some View {
        Image(systemName: state.menuBarSymbol)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(stateColor)
            .accessibilityLabel("连接状态：\(state.statusBarText)")
    }

    private var stateColor: Color {
        switch state {
        case .connected: return AppTheme.success
        case .connecting, .disconnecting: return AppTheme.warning
        case .failed: return AppTheme.danger
        case .disconnected: return .secondary
        }
    }
}

struct MenuBarContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        Button {
            openMainWindow()
        } label: {
            Label("打开应用", systemImage: "macwindow")
        }

        Button {
            connectionManager.toggleConnection()
        } label: {
            Label(quickActionTitle, systemImage: quickActionSymbol)
        }
        .disabled(!connectionManager.canToggleConnection)

        Divider()

        Button("退出应用", systemImage: "power") {
            NSApp.terminate(nil)
        }
    }

    private func openMainWindow() {
        if appDelegate.mainWindow != nil {
            appDelegate.showMainWindow()
            return
        }

        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            appDelegate.showMainWindow()
        }
    }

    private var quickActionTitle: String {
        switch connectionManager.connectionState {
        case .connected:
            return "快速断开"
        case .connecting:
            return "正在连接..."
        case .disconnecting:
            return "正在断开..."
        case .disconnected, .failed:
            return "快速连接"
        }
    }

    private var quickActionSymbol: String {
        switch connectionManager.connectionState {
        case .connected:
            return "xmark.circle"
        case .connecting, .disconnecting:
            return "arrow.triangle.2.circlepath"
        case .disconnected, .failed:
            return "bolt.horizontal.circle"
        }
    }
}

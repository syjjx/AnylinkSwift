import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)

            Text(connectionManager.connectionState.statusBarText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if connectionManager.connectionState == .connected {
                Text("连接到")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Text(connectionManager.selectedGateway.address)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 28)
        .background(AppTheme.footerBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var stateColor: Color {
        switch connectionManager.connectionState {
        case .connected: return AppTheme.success
        case .connecting, .disconnecting, .reconnecting: return AppTheme.warning
        case .failed: return AppTheme.danger
        case .disconnected: return .secondary
        }
    }
}

import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @Environment(\.openWindow) private var openWindow

    private var rows: [(String, String)] {
        let snapshot = connectionManager.snapshot
        return [
            ("通道类型", snapshot.channelType),
            ("TLS 加密套件", snapshot.tlsCipherSuite),
            ("DTLS 加密套件", snapshot.dtlsCipherSuite),
            ("TLS 通道压缩", snapshot.cstpCompression),
            ("DTLS 通道压缩", snapshot.dtlsCompression),
            ("DTLS 端口", snapshot.dtlsPort),
            ("服务器地址", snapshot.serverAddress),
            ("本地地址", snapshot.localAddress),
            ("VPN 地址", snapshot.vpnAddress),
            ("MTU", snapshot.mtu),
            ("DNS", snapshot.dns)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        KeyValueRow(key: row.0, value: row.1, isBadge: index == 0 && connectionManager.connectionState.isConnected)

                        if index < rows.count - 1 {
                            Divider()
                                .opacity(0.65)
                        }
                    }

                    Divider()
                        .padding(.top, 5)

                    HStack {
                        Spacer()

                        Button("查看连接详情") {
                            openWindow(id: "connection-details")
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                        .disabled(!connectionManager.connectionState.isConnected)

                        Spacer()
                    }
                    .padding(.top, 15)
                }
                .padding(.horizontal, 21)
                .padding(.vertical, 10)
                .tunnelCard()
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }
}

struct ConnectionDetailsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前网关：\(connectionManager.selectedGateway.address)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            TrafficSummaryCard(snapshot: connectionManager.traffic)

            HStack(alignment: .top, spacing: 14) {
                RouteTableCard(title: "排除路由", routes: connectionManager.routes.excluded)
                RouteTableCard(title: "安全路由", routes: connectionManager.routes.secured)
            }
        }
        .padding(24)
        .frame(width: 760, height: 560)
        .background(AppTheme.pageBackground)
    }
}

private struct TrafficSummaryCard: View {
    let snapshot: TrafficSnapshot

    var body: some View {
        HStack(spacing: 0) {
            TrafficValue(title: "发送字节", value: formatBytes(snapshot.sentBytes))
            Divider()
                .frame(height: 42)
            TrafficValue(title: "接收字节", value: formatBytes(snapshot.receivedBytes))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .tunnelCard()
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let megabytes = Double(bytes) / 1_000_000
        return String(format: "%.2f MB", megabytes)
    }
}

private struct TrafficValue: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RouteTableCard: View {
    let title: String
    let routes: [RouteEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

            Divider()

            HStack(spacing: 0) {
                Text("地址")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 20)

                Text("前缀")
                    .frame(width: 72, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(AppTheme.controlBackground)

            Divider()

            if routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .font(.title3)
                        .foregroundStyle(.tertiary)

                    Text("暂无路由")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            HStack(spacing: 0) {
                                Text(route.address)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(route.prefix)
                                    .frame(width: 72, alignment: .leading)
                            }
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(index.isMultiple(of: 2) ? AppTheme.cardBackground : AppTheme.controlBackground)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 330, maxHeight: .infinity)
        .tunnelCard()
    }

}

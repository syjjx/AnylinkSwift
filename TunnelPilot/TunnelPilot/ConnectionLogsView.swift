import SwiftUI

struct ConnectionLogsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    private static let topID = "connection-logs-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id(Self.topID)

                    if connectionManager.connectionLogs.isEmpty {
                        VStack(spacing: 9) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.tertiary)

                            Text("暂无连接日志")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Text("发起一次连接后，日志会显示在这里")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(connectionManager.connectionLogs.indices.reversed(), id: \.self) { index in
                            Text(connectionManager.connectionLogs[index])
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(14)
            }
            .background(
                AppTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .onAppear {
                scrollToTop(using: proxy, animated: false)
            }
            .onChange(of: connectionManager.connectionLogs) { _ in
                scrollToTop(using: proxy, animated: true)
            }
        }
        .padding(20)
        .background(AppTheme.pageBackground)
        .frame(minWidth: 560, minHeight: 300)
    }

    private func scrollToTop(using proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.topID, anchor: .top)
                }
            } else {
                proxy.scrollTo(Self.topID, anchor: .top)
            }
        }
    }
}

#Preview {
    ConnectionLogsView()
        .environmentObject(ConnectionManager())
}

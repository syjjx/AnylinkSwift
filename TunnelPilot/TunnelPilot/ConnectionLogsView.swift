import AppKit
import SwiftUI

struct ConnectionLogsView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager

    /// 倒序拼接的完整日志文本（最新在顶部）。
    private var logText: String {
        connectionManager.connectionLogs.joined(separator: "\n") + "\n"
    }

    var body: some View {
        VStack(spacing: 10) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    AppTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )
            } else {
                LogTextView(text: logText)
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    )
                    .background(
                        AppTheme.cardBackground,
                        in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
            }

            HStack(spacing: 12) {
                Spacer()

                Button {
                    copyAll()
                } label: {
                    Label("复制全部", systemImage: "doc.on.doc")
                }
                .disabled(connectionManager.connectionLogs.isEmpty)

                Button(role: .destructive) {
                    connectionManager.clearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .disabled(connectionManager.connectionLogs.isEmpty)
            }
            .controlSize(.small)
        }
        .padding(20)
        .background(AppTheme.pageBackground)
        .frame(minWidth: 560, minHeight: 300)
    }

    private func copyAll() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
    }
}

/// 日志文本视图：基于 NSTextView，支持跨行选择复制。
/// 内容更新时保持滚动在顶部（日志倒序，最新在最上方）。
private struct LogTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard textView.string != text else { return }
        textView.string = text
        // 倒序日志：最新在顶部，滚动到文本开头
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}

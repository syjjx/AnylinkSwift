import AppKit
import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case gateway
    case status
    case settings
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gateway: return "网关"
        case .status: return "状态"
        case .settings: return "设置"
        case .help: return "帮助"
        }
    }

    var subtitle: String {
        switch self {
        case .gateway: return "选择要连接的虚拟专用网络主机并输入临时密码"
        case .status: return "当前隧道的实时参数"
        case .settings: return "连接行为与界面偏好"
        case .help: return "关于应用与帮助资源"
        }
    }

    var systemImage: String {
        switch self {
        case .gateway: return "globe"
        case .status: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        case .help: return "questionmark.circle"
        }
    }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case reconnecting
    case failed

    var title: String {
        switch self {
        case .disconnected: return "准备连接"
        case .connecting: return "正在连接..."
        case .connected: return "安全连接已建立"
        case .disconnecting: return "正在断开..."
        case .reconnecting: return "正在重连..."
        case .failed: return "连接失败"
        }
    }

    var detail: String {
        switch self {
        case .disconnected: return "选择网关开始连接"
        case .connecting: return "正在连接 VPN 服务器"
        case .connected: return "隧道已建立"
        case .disconnecting: return "正在关闭隧道"
        case .reconnecting: return "网络中断，正在自动重连"
        case .failed: return "请重新尝试连接"
        }
    }

    var statusBarText: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "正在连接"
        case .connected: return "已连接"
        case .disconnecting: return "正在断开"
        case .reconnecting: return "重连中"
        case .failed: return "连接失败"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .disconnected: return "lock.open"
        case .connecting, .disconnecting, .reconnecting: return "arrow.triangle.2.circlepath"
        case .connected: return "lock"
        case .failed: return "exclamationmark.shield.fill"
        }
    }

    var isConnected: Bool { self == .connected }
    var isTransitioning: Bool { self == .connecting || self == .disconnecting || self == .reconnecting }
}

struct GatewayProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var host: String
    var username: String
    var password: String
    var group: String
    var secret: String

    init(
        name: String,
        host: String,
        username: String = "",
        password: String = "",
        group: String = "",
        secret: String = "",
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.password = password
        self.group = group
        self.secret = secret
    }

    var address: String { host }

    var displayName: String {
        name.isEmpty ? host : name
    }
}

struct ProfileDraft: Equatable, Sendable {
    var name = ""
    var host = ""
    var username = ""
    var password = ""
    var group = ""
    var secret = ""

    init() {}

    init(profile: GatewayProfile) {
        name = profile.name
        host = profile.host
        username = profile.username
        password = profile.password
        group = profile.group
        secret = profile.secret
    }
}

struct RouteEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var address: String
    var prefix: String

    init(address: String, prefix: String, id: UUID = UUID()) {
        self.id = id
        self.address = address
        self.prefix = prefix
    }
}

struct TrafficSnapshot: Sendable {
    var sentBytes: Int64
    var receivedBytes: Int64

    static let inactive = TrafficSnapshot(sentBytes: 0, receivedBytes: 0)
}

/// 隧道实时速率（字节/秒），由流量统计差分得出。
struct TrafficRates: Sendable {
    var sentPerSecond: Double = 0
    var receivedPerSecond: Double = 0

    static let inactive = TrafficRates()

    /// 菜单栏显示文本（两行：上行上传、下行下载），如 "↑12.3KB/s\n↓4.5MB/s"。
    var menuBarText: String {
        "↑\(Self.format(sentPerSecond))\n↓\(Self.format(receivedPerSecond))"
    }

    /// 渲染为菜单栏图片：左侧状态图标 + 右侧两行速度文本（上行上传、下行下载）。
    /// MenuBarExtra 的状态栏 label 会强制固定字体并可能丢弃部分子视图，
    /// 因此图标与文字绘制成一张图。
    func menuBarImage(symbolName: String, iconColor: NSColor, fontSize: CGFloat = 8) -> NSImage {
        let iconSize: CGFloat = 18
        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular))?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [iconColor]))

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let up = NSAttributedString(string: "↑\(Self.format(sentPerSecond))", attributes: attributes)
        let down = NSAttributedString(string: "↓\(Self.format(receivedPerSecond))", attributes: attributes)
        let lineHeight = up.size().height
        let textWidth = max(up.size().width, down.size().width)
        let gap: CGFloat = 4
        let width = iconSize + gap + textWidth
        let height = max(lineHeight * 2, iconSize)

        let image = NSImage(size: NSSize(width: ceil(width), height: ceil(height)))
        image.lockFocus()
        icon?.draw(in: NSRect(
            x: 0,
            y: (height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        ))
        let textX = iconSize + gap
        up.draw(at: NSPoint(x: textX, y: height - lineHeight))
        down.draw(at: NSPoint(x: textX, y: 0))
        image.unlockFocus()
        return image
    }

    /// 与 Qt 原版一致，按 1000 进制格式化。
    private static func format(_ bytesPerSecond: Double) -> String {
        let value = max(0, bytesPerSecond)
        switch value {
        case ..<1000:
            return String(format: "%.0fB/s", value)
        case ..<1_000_000:
            return String(format: "%.1fKB/s", value / 1000)
        case ..<1_000_000_000:
            return String(format: "%.1fMB/s", value / 1_000_000)
        default:
            return String(format: "%.2fGB/s", value / 1_000_000_000)
        }
    }
}

struct RouteSnapshot: Sendable {
    var excluded: [RouteEntry]
    var secured: [RouteEntry]

    static let inactive = RouteSnapshot(excluded: [], secured: [])
}

struct TunnelSnapshot: Sendable {
    var channelType: String
    var tlsCipherSuite: String
    var dtlsCipherSuite: String
    var dtlsPort: String
    var serverAddress: String
    var localAddress: String
    var vpnAddress: String
    var mtu: String
    var dns: String
    /// TLS 通道压缩（"未启用"/"lzs"/"oc-lz4"）
    var cstpCompression: String
    /// DTLS 通道压缩（同上）
    var dtlsCompression: String

    static let inactive = TunnelSnapshot(
        channelType: "暂无活动隧道",
        tlsCipherSuite: "-",
        dtlsCipherSuite: "-",
        dtlsPort: "-",
        serverAddress: "-",
        localAddress: "-",
        vpnAddress: "-",
        mtu: "-",
        dns: "-",
        cstpCompression: "-",
        dtlsCompression: "-"
    )
}

struct AppSettings: Sendable {
    var autoConnect = false
    var minimizeOnConnect = true
    var blockUntrustedServers = true
    var debugLogging = false
    var compressionEnabled = true
    var disableDTLS = false
    /// 异常断线时由 vpnagent 自动重连（指数退避，用户主动断开不触发）
    var autoReconnect = true
    var useLocalLanguage = true
}

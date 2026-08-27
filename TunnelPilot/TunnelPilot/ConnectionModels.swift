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
    case failed

    var title: String {
        switch self {
        case .disconnected: return "准备连接"
        case .connecting: return "正在连接..."
        case .connected: return "安全连接已建立"
        case .disconnecting: return "正在断开..."
        case .failed: return "连接失败"
        }
    }

    var detail: String {
        switch self {
        case .disconnected: return "选择网关开始连接"
        case .connecting: return "正在准备模拟隧道"
        case .connected: return "模拟隧道已建立"
        case .disconnecting: return "正在关闭模拟隧道"
        case .failed: return "请重新尝试连接"
        }
    }

    var statusBarText: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "正在连接"
        case .connected: return "已连接"
        case .disconnecting: return "正在断开"
        case .failed: return "连接失败"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .disconnected: return "lock.open"
        case .connecting, .disconnecting: return "arrow.triangle.2.circlepath"
        case .connected: return "lock.shield.fill"
        case .failed: return "exclamationmark.shield.fill"
        }
    }

    var isConnected: Bool { self == .connected }
    var isTransitioning: Bool { self == .connecting || self == .disconnecting }
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

    static let demo = TrafficSnapshot(
        sentBytes: 2_260_000,
        receivedBytes: 7_370_000
    )
}

struct RouteSnapshot: Sendable {
    var excluded: [RouteEntry]
    var secured: [RouteEntry]

    static let inactive = RouteSnapshot(excluded: [], secured: [])

    static let demo = RouteSnapshot(
        excluded: [
            RouteEntry(address: "192.168.0.0", prefix: "24"),
            RouteEntry(address: "127.0.0.0", prefix: "8"),
            RouteEntry(address: "1.1.8.0", prefix: "24"),
            RouteEntry(address: "1.2.4.0", prefix: "24"),
            RouteEntry(address: "1.8.1.0", prefix: "24"),
            RouteEntry(address: "1.8.8.0", prefix: "24"),
            RouteEntry(address: "1.12.0.0", prefix: "14"),
            RouteEntry(address: "1.18.128.0", prefix: "24"),
            RouteEntry(address: "1.24.0.0", prefix: "13")
        ],
        secured: []
    )
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

    static let inactive = TunnelSnapshot(
        channelType: "暂无活动隧道",
        tlsCipherSuite: "-",
        dtlsCipherSuite: "-",
        dtlsPort: "-",
        serverAddress: "-",
        localAddress: "-",
        vpnAddress: "-",
        mtu: "-",
        dns: "-"
    )

    static let demo = TunnelSnapshot(
        channelType: "DTLS",
        tlsCipherSuite: "TLS_AES_256_GCM_SHA384",
        dtlsCipherSuite: "ECDHE_RSA_AES_256_GCM",
        dtlsPort: "4321",
        serverAddress: "198.51.100.42",
        localAddress: "192.0.2.18",
        vpnAddress: "10.231.0.14",
        mtu: "1333",
        dns: "10.99.99.1"
    )
}

struct AppSettings: Sendable {
    var autoConnect = false
    var minimizeOnConnect = true
    var blockUntrustedServers = false
    var debugLogging = false
    var ciscoCompatibility = false
    var disableDTLS = false
    var useLocalLanguage = true
}

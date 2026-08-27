import Foundation

enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting
    case failed(reason: String)

    var isBusy: Bool {
        self == .connecting || self == .reconnecting
    }
}

struct VPNStatus: Equatable {
    var channelType = "TLS"
    var tlsCipherSuite = "—"
    var dtlsCipherSuite = "—"
    var dtlsPort = "—"
    var serverAddress = "—"
    var localAddress = "—"
    var vpnAddress = "—"
    var mtu = 0
    var dns: [String] = []

    static let empty = VPNStatus()
}

enum ConnectionEvent {
    case connected
    case disconnected(reason: String)
    case aborted(reason: String)
    case failed(reason: String)
    case status(VPNStatus)
}

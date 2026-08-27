import Foundation

@MainActor
final class StubConnectionService: ConnectionService {
    var onEvent: ((ConnectionEvent) -> Void)?

    private var task: Task<Void, Never>?

    func connect(host: String, username: String, password: String, otp: String?) {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.onEvent?(.status(VPNStatus(
                channelType: "TLS",
                tlsCipherSuite: "ECDHE-RSA-AES256-GCM-SHA384",
                serverAddress: host,
                localAddress: "192.168.1.100",
                vpnAddress: "10.8.0.2",
                mtu: 1399,
                dns: ["8.8.8.8", "114.114.114.114"]
            )))
            self.onEvent?(.connected)
        }
    }

    func reconnect() {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.onEvent?(.connected)
        }
    }

    func disconnect() {
        task?.cancel()
        onEvent?(.disconnected(reason: "已手动断开"))
    }
}

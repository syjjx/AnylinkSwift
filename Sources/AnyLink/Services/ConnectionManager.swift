import Foundation
import Combine

@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var status: VPNStatus = .empty
    @Published var connectedHost: String?

    private let service: ConnectionService
    private var lastReason = ""

    init(service: ConnectionService) {
        self.service = service
        service.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    func connect(host: String, otp: String? = nil) {
        guard state != .connected else { return }
        state = .connecting
        connectedHost = host
        service.connect(host: host, username: "", password: "", otp: otp)
    }

    func disconnect() {
        service.disconnect()
    }

    private func handle(_ event: ConnectionEvent) {
        switch event {
        case .connected:
            state = .connected
        case .disconnected:
            state = .idle
        case .aborted(let reason):
            lastReason = reason
            state = .failed(reason: reason)
        case .failed(let reason):
            lastReason = reason
            state = .failed(reason: reason)
        case .status(let newStatus):
            status = newStatus
        }
    }
}

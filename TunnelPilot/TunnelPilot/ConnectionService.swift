import Foundation

protocol ConnectionService: Sendable {
    func connect(to gateway: GatewayProfile, otp: String) async throws
    func disconnect() async
    func applySettings(_ settings: AppSettings) async
    var events: AsyncStream<AgentEvent> { get }
}

/// Local-only service used while the GUI is being built.
struct StubConnectionService: ConnectionService {
    var events: AsyncStream<AgentEvent> {
        AsyncStream { $0.finish() }
    }

    func connect(to gateway: GatewayProfile, otp: String) async throws {
        _ = gateway
        _ = otp
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }

    func disconnect() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    func applySettings(_ settings: AppSettings) async {
        _ = settings
    }
}

import Foundation

protocol ConnectionService: Sendable {
    func connect(to gateway: GatewayProfile, otp: String) async throws
    func disconnect() async
}

/// Local-only service used while the GUI is being built.
struct StubConnectionService: ConnectionService {
    func connect(to gateway: GatewayProfile, otp: String) async throws {
        _ = gateway
        _ = otp
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }

    func disconnect() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }
}

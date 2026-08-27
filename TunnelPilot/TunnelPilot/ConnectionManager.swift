import Combine
import Foundation

@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published var gateways: [GatewayProfile]
    @Published var selectedGatewayID: UUID
    @Published var otp = ""
    @Published var settings = AppSettings()
    @Published private(set) var snapshot = TunnelSnapshot.inactive
    @Published private(set) var traffic = TrafficSnapshot.inactive
    @Published private(set) var routes = RouteSnapshot.inactive
    @Published private(set) var connectedSince: Date?
    @Published private(set) var lastError: String?

    private let service: any ConnectionService
    private var operation: Task<Void, Never>?

    init(service: any ConnectionService = StubConnectionService()) {
        let initialGateways = [
            GatewayProfile(name: "HLLT", host: "vpn.example.com:4321", username: "yinjia"),
            GatewayProfile(name: "备用网关", host: "192.0.2.2:443")
        ]

        self.gateways = initialGateways
        self.selectedGatewayID = initialGateways[0].id
        self.service = service
    }

    var selectedGateway: GatewayProfile {
        gateways.first(where: { $0.id == selectedGatewayID }) ?? gateways[0]
    }

    var actionTitle: String {
        connectionState == .connected ? "断开连接" : "连接"
    }

    var actionSymbol: String {
        connectionState == .connected ? "xmark" : "arrow.right"
    }

    var canToggleConnection: Bool {
        !connectionState.isTransitioning
    }

    func toggleConnection() {
        if connectionState == .connected {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        guard connectionState == .disconnected || connectionState == .failed else { return }

        operation?.cancel()
        connectionState = .connecting
        snapshot = .inactive
        traffic = .inactive
        routes = .inactive
        connectedSince = nil
        lastError = nil

        let gateway = selectedGateway
        let oneTimePassword = otp

        operation = Task { [weak self] in
            guard let self else { return }

            do {
                try await service.connect(to: gateway, otp: oneTimePassword)
                guard !Task.isCancelled else { return }

                connectionState = .connected
                snapshot = .demo
                traffic = .demo
                routes = .demo
                connectedSince = Date()
            } catch is CancellationError {
                // A cancelled local operation is not a connection failure.
            } catch {
                connectionState = .failed
                lastError = error.localizedDescription
            }
        }
    }

    func disconnect() {
        guard connectionState == .connected else { return }

        operation?.cancel()
        connectionState = .disconnecting

        operation = Task { [weak self] in
            guard let self else { return }
            await self.service.disconnect()
            guard !Task.isCancelled else { return }

            connectionState = .disconnected
            snapshot = .inactive
            traffic = .inactive
            routes = .inactive
            connectedSince = nil
        }
    }

    func addGateway(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return }

        let profile = GatewayProfile(name: trimmedAddress, host: trimmedAddress)
        gateways.append(profile)
        selectedGatewayID = profile.id
    }

    func saveProfile(_ draft: ProfileDraft, id: UUID?) -> UUID? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !host.isEmpty, !username.isEmpty else { return nil }

        let profileID = id ?? UUID()
        let profile = GatewayProfile(
            name: name,
            host: host,
            username: username,
            password: draft.password,
            group: draft.group.trimmingCharacters(in: .whitespacesAndNewlines),
            secret: draft.secret,
            id: profileID
        )

        if let index = gateways.firstIndex(where: { $0.id == profileID }) {
            gateways[index] = profile
        } else {
            gateways.append(profile)
        }

        selectedGatewayID = profileID
        return profileID
    }

    func profile(with id: UUID) -> GatewayProfile? {
        gateways.first(where: { $0.id == id })
    }

    func deleteProfile(id: UUID) {
        gateways.removeAll(where: { $0.id == id })

        if selectedGatewayID == id {
            selectedGatewayID = gateways.first?.id ?? UUID()
        }
    }
}

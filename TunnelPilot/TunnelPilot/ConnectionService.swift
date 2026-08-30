import Foundation

protocol ConnectionService: Sendable {
    func connect(to gateway: GatewayProfile, otp: String) async throws
    func disconnect() async
    func applySettings(_ settings: AppSettings) async
    func queryAgentVersion() async throws -> AgentRunningVersion
    /// 关闭并清理当前连接（daemon 重启后旧 socket 失效，需重建）。
    func resetConnection() async
    var events: AsyncStream<AgentEvent> { get }
}

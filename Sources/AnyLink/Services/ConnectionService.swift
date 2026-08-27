import Foundation

@MainActor
protocol ConnectionService: AnyObject {
    var onEvent: ((ConnectionEvent) -> Void)? { get set }
    func connect(host: String, username: String, password: String, otp: String?)
    func reconnect()
    func disconnect()
}

import Foundation

/// vpnagent 通过 WebSocket JSON-RPC 推送或轮询产生的事件。
enum AgentEvent: Sendable, Equatable {
    /// 隧道信息已更新（建立后或周期性刷新）
    case tunnelEstablished(AgentTunnelInfo)
    /// 流量统计更新
    case traffic(AgentTraffic)
    /// 会话正常关闭（vpnagent 推送 DISCONNECT）
    case closed(String)
    /// 会话异常中断（vpnagent 推送 ABORT，或与 vpnagent 的连接断开）
    case aborted(String)
}

/// status RPC 返回的隧道信息（对应 sslcon session.ConnSession）。
struct AgentTunnelInfo: Sendable, Equatable {
    var dtlsConnected = false
    var tlsCipherSuite = ""
    var dtlsCipherSuite = ""
    var dtlsPort = ""
    var serverAddress = ""
    var localAddress = ""
    var vpnAddress = ""
    var mtu = 0
    var dns: [String] = []
    var splitInclude: [String] = []
    var splitExclude: [String] = []
    /// 协商的压缩算法（"none"/"lzs"/"oc-lz4"，空串表示未知）
    var cstpCompression = ""
    /// DTLS 通道协商的压缩算法（同上）
    var dtlsCompression = ""
}

/// stat RPC 返回的流量统计。
struct AgentTraffic: Sendable, Equatable {
    var sentBytes: UInt64 = 0
    var receivedBytes: UInt64 = 0
}

/// VERSION RPC 返回的 vpnagent 构建信息（对应 sslcon rpc.versionReply）。
struct AgentRunningVersion: Sendable, Equatable {
    /// sslcon 构建版本（如 2.1.0）
    var version: String
    /// git commit（可空）
    var commit: String
    /// 上报给服务端的 AnyConnect 客户端版本
    var agentVersion: String
    /// 编译所用 Go 版本
    var goVersion: String
}

enum AgentRPCError: Error, LocalizedError {
    case transport(String)
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .transport(let message), .remote(let message):
            return message
        }
    }
}

/// 通过 vpnagent 的 WebSocket JSON-RPC（ws://127.0.0.1:6210/rpc）连接 VPN。
///
/// sslcon 服务端按请求 id 分发方法（而不是 method 名），id 必须与
/// sslcon/rpc/rpc.go 的常量一致：status=0, config=1, connect=2,
/// disconnect=3, reconnect=4, interface=5, stat=7。
actor AgentConnectionService: ConnectionService {
    private enum RPCID {
        static let status = 0
        static let config = 1
        static let connect = 2
        static let disconnect = 3
        static let abort = 6
        static let stat = 7
        static let version = 8
    }

    private enum Method {
        static let status = "status"
        static let config = "config"
        static let connect = "connect"
        static let disconnect = "disconnect"
        static let stat = "stat"
        static let version = "version"
    }

    nonisolated private static let rpcURL = URL(string: "ws://127.0.0.1:6210/rpc")!

    nonisolated let events: AsyncStream<AgentEvent>

    private let eventSink = EventSink()
    private var settings = AppSettings()
    private var webSocket: URLSessionWebSocketTask?
    private var isSocketOpen = false
    private var openWaiters: [OpenBox] = []
    private var pending: [Int: PendingBox] = [:]
    private var receiveTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var statCount = 0

    private let session: URLSession
    private let socketDelegate: SocketDelegate

    init() {
        let sink = eventSink
        let delegate = SocketDelegate()
        self.socketDelegate = delegate
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        self.events = AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
            sink.continuation = continuation
        }
    }

    // MARK: - ConnectionService

    func connect(to gateway: GatewayProfile, otp: String) async throws {
        try await openIfNeeded()

        // 连接前先同步配置（与原版 AnyLink 行为一致）
        _ = try? await send(Method.config, id: RPCID.config, params: makeConfigParams(settings))

        var profile: [String: Any] = [
            "host": gateway.host,
            "username": gateway.username,
            "password": gateway.password,
            "group": gateway.group,
            "secret": gateway.secret,
        ]
        if !otp.isEmpty {
            profile["password"] = gateway.password + otp
        }

        let response = try await send(Method.connect, id: RPCID.connect, params: profile)
        if let errorMessage = response.errorMessage {
            throw AgentRPCError.remote(errorMessage)
        }

        startPollingIfNeeded()
    }

    func disconnect() async {
        pollingTask?.cancel()
        pollingTask = nil
        statCount = 0
        guard isSocketOpen else { return }
        _ = try? await send(Method.disconnect, id: RPCID.disconnect, params: [:])
    }

    func applySettings(_ settings: AppSettings) async {
        self.settings = settings
        guard isSocketOpen else { return }
        _ = try? await send(Method.config, id: RPCID.config, params: makeConfigParams(settings))
    }

    /// 查询运行中 vpnagent 的构建版本（VERSION RPC）。
    func queryAgentVersion() async throws -> AgentRunningVersion {
        try await openIfNeeded()
        let response = try await send(Method.version, id: RPCID.version, params: [:])
        guard let data = response.resultData else {
            throw AgentRPCError.transport("VERSION 接口无返回")
        }
        let reply = try JSONDecoder().decode(AgentVersionReply.self, from: data)
        return AgentRunningVersion(
            version: reply.version,
            commit: reply.commit,
            agentVersion: reply.agentVersion,
            goVersion: reply.goVersion
        )
    }

    /// 关闭当前连接并清理状态。
    ///
    /// daemon 重装/重启后旧 socket 对应的进程已退出，连接可能未被 URLSession
    /// 感知而停留在半死状态，此时必须显式重建。
    func resetConnection() async {
        pollingTask?.cancel()
        pollingTask = nil
        statCount = 0
        let socket = webSocket
        webSocket = nil
        isSocketOpen = false
        socket?.cancel(with: .normalClosure, reason: nil)

        let waiters = openWaiters
        openWaiters.removeAll()
        for box in waiters {
            box.resume(result: false)
        }
        let failed = pending
        pending.removeAll()
        for (_, box) in failed {
            box.resume(throwing: AgentRPCError.transport("连接已重置"))
        }
    }

    // MARK: - 连接管理

    private func openIfNeeded() async throws {
        if isSocketOpen {
            return
        }

        // 全新连接：创建 socket 并注册回调
        if webSocket == nil {
            let socket = session.webSocketTask(with: Self.rpcURL)
            socketDelegate.onOpen = { [weak self] in
                Task { await self?.handleSocketOpen() }
            }
            socketDelegate.onClose = { [weak self] error in
                Task { await self?.handleSocketClose(error) }
            }
            webSocket = socket
            socket.resume()
        }

        // 等待握手完成（handleSocketOpen 成功、handleSocketClose 失败），最多 5 秒
        let box = OpenBox()
        openWaiters.append(box)
        let timeout = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            box.resume(result: false)
        }
        let opened = await withCheckedContinuation { continuation in
            box.continuation = continuation
        }
        timeout.cancel()

        guard opened else {
            if let socket = webSocket {
                socket.cancel()
            }
            handleSocketClose(nil)
            throw AgentRPCError.transport("无法连接 vpnagent 服务（ws://127.0.0.1:6210/rpc）")
        }
    }

    private func handleSocketOpen() {
        guard webSocket != nil else { return }
        isSocketOpen = true
        let waiters = openWaiters
        openWaiters.removeAll()
        for box in waiters {
            box.resume(result: true)
        }
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func handleSocketClose(_ error: Error?) {
        guard webSocket != nil else { return }
        webSocket = nil
        isSocketOpen = false

        let message = "与 vpnagent 的连接中断"
        let waiters = openWaiters
        openWaiters.removeAll()
        for box in waiters {
            box.resume(result: false)
        }
        let failed = pending
        pending.removeAll()
        for (_, box) in failed {
            box.resume(throwing: AgentRPCError.transport(message))
        }
        pollingTask?.cancel()
        pollingTask = nil
        eventSink.continuation?.yield(.aborted(message))
    }

    private func receiveLoop() async {
        guard let socket = webSocket else { return }
        do {
            while !Task.isCancelled {
                let message = try await socket.receive()
                switch message {
                case .data(let data):
                    handleIncoming(data)
                case .string(let text):
                    handleIncoming(Data(text.utf8))
                @unknown default:
                    break
                }
            }
        } catch {
            handleSocketClose(error)
        }
    }

    private func handleIncoming(_ data: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = object["id"] as? Int
        else {
            return
        }

        if let box = pending.removeValue(forKey: id),
           let continuation = box.continuation {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                continuation.resume(throwing: AgentRPCError.remote(message))
            } else if let result = object["result"] {
                // 注意：config/connect 的 result 是字符串，必须允许 fragments，
                // 否则 dataWithJSONObject 会抛 NSInvalidArgumentException
                let resultData = (try? JSONSerialization.data(
                    withJSONObject: result,
                    options: [.fragmentsAllowed]
                )) ?? Data()
                continuation.resume(returning: RPCResponse(resultData: resultData, errorMessage: nil))
            } else {
                continuation.resume(returning: RPCResponse(resultData: nil, errorMessage: nil))
            }
            return
        }

        // vpnagent 主动推送：会话关闭（3）或异常中断（6）
        guard id == RPCID.disconnect || id == RPCID.abort else { return }
        let message = (object["result"] as? String)
            ?? ((object["error"] as? [String: Any])?["message"] as? String)
            ?? "连接已断开"
        if id == RPCID.disconnect {
            pollingTask?.cancel()
            pollingTask = nil
            eventSink.continuation?.yield(.closed(message))
        } else {
            pollingTask?.cancel()
            pollingTask = nil
            eventSink.continuation?.yield(.aborted(message))
        }
    }

    private func send(_ method: String, id: Int, params: [String: Any]) async throws -> RPCResponse {
        guard let socket = webSocket, isSocketOpen else {
            throw AgentRPCError.transport("未连接到 vpnagent 服务")
        }

        if let previous = pending[id] {
            pending.removeValue(forKey: id)
            previous.resume(throwing: AgentRPCError.transport("请求被更新的请求取代"))
        }

        let request: [String: Any] = [
            "method": method,
            "jsonrpc": "2.0",
            "params": params,
            "id": id,
        ]
        let data = try JSONSerialization.data(withJSONObject: request)

        let box = PendingBox()
        pending[id] = box
        return try await withCheckedThrowingContinuation { continuation in
            box.continuation = continuation
            Task {
                do {
                    try await socket.send(.data(data))
                } catch {
                    self.failPending(id: id, error: AgentRPCError.transport("发送请求失败: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func failPending(id: Int, error: Error) {
        guard let box = pending.removeValue(forKey: id) else { return }
        box.resume(throwing: error)
    }

    // MARK: - 轮询

    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func pollLoop() async {
        statCount = 0
        await refreshStatus()
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
            if Task.isCancelled {
                return
            }
            statCount += 1
            await refreshTraffic()
            if statCount % 60 == 0 {
                await refreshStatus()
            }
        }
    }

    private func refreshStatus() async {
        do {
            let response = try await send(Method.status, id: RPCID.status, params: [:])
            guard let data = response.resultData else { return }
            let status = try JSONDecoder().decode(AgentStatus.self, from: data)
            let info = AgentTunnelInfo(
                dtlsConnected: status.dtlsConnected,
                tlsCipherSuite: status.tlsCipherSuite,
                dtlsCipherSuite: status.dtlsCipherSuite,
                dtlsPort: status.dtlsPort,
                serverAddress: status.serverAddress,
                localAddress: status.localAddress,
                vpnAddress: status.vpnAddress,
                mtu: status.mtu,
                dns: status.dns,
                splitInclude: status.splitInclude,
                splitExclude: status.splitExclude,
                cstpCompression: status.cstpCompression,
                dtlsCompression: status.dtlsCompression
            )
            eventSink.continuation?.yield(.tunnelEstablished(info))
        } catch {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    private func refreshTraffic() async {
        do {
            let response = try await send(Method.stat, id: RPCID.stat, params: [:])
            guard let data = response.resultData else { return }
            let stat = try JSONDecoder().decode(AgentStat.self, from: data)
            eventSink.continuation?.yield(
                .traffic(AgentTraffic(sentBytes: stat.bytesSent, receivedBytes: stat.bytesReceived))
            )
        } catch {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    // MARK: - 配置

    private func makeConfigParams(_ settings: AppSettings) -> [String: Any] {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return [
            "log_level": settings.debugLogging ? "Debug" : "Info",
            "log_path": FileManager.default.temporaryDirectory.path,
            "skip_verify": !settings.blockUntrustedServers,
            "cisco_compat": true,
            "no_dtls": settings.disableDTLS,
            "compression": settings.compressionEnabled,
            "agent_name": "AnyLink Secure Client",
            "agent_version": version,
        ]
    }

    // MARK: - 内部类型
}

// MARK: - DTO

private struct AgentStatus: Decodable {
    var dtlsConnected = false
    var tlsCipherSuite = ""
    var dtlsCipherSuite = ""
    var dtlsPort = ""
    var serverAddress = ""
    var localAddress = ""
    var vpnAddress = ""
    var mtu = 0
    var dns: [String] = []
    var splitInclude: [String] = []
    var splitExclude: [String] = []
    var cstpCompression = ""
    var dtlsCompression = ""

    private enum CodingKeys: String, CodingKey {
        case dtlsConnected = "DtlsConnected"
        case tlsCipherSuite = "TLSCipherSuite"
        case dtlsCipherSuite = "DTLSCipherSuite"
        case dtlsPort = "DTLSPort"
        case serverAddress = "ServerAddress"
        case localAddress = "LocalAddress"
        case vpnAddress = "VPNAddress"
        case mtu = "MTU"
        case dns = "DNS"
        case splitInclude = "SplitInclude"
        case splitExclude = "SplitExclude"
        case cstpCompression = "cstp_compression"
        case dtlsCompression = "dtls_compression"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dtlsConnected = (try? container.decode(Bool.self, forKey: .dtlsConnected)) ?? false
        tlsCipherSuite = (try? container.decode(String.self, forKey: .tlsCipherSuite)) ?? ""
        dtlsCipherSuite = (try? container.decode(String.self, forKey: .dtlsCipherSuite)) ?? ""
        dtlsPort = (try? container.decode(String.self, forKey: .dtlsPort)) ?? ""
        serverAddress = (try? container.decode(String.self, forKey: .serverAddress)) ?? ""
        localAddress = (try? container.decode(String.self, forKey: .localAddress)) ?? ""
        vpnAddress = (try? container.decode(String.self, forKey: .vpnAddress)) ?? ""
        mtu = (try? container.decode(Int.self, forKey: .mtu)) ?? 0
        dns = (try? container.decode([String].self, forKey: .dns)) ?? []
        splitInclude = (try? container.decode([String].self, forKey: .splitInclude)) ?? []
        splitExclude = (try? container.decode([String].self, forKey: .splitExclude)) ?? []
        cstpCompression = (try? container.decode(String.self, forKey: .cstpCompression)) ?? ""
        dtlsCompression = (try? container.decode(String.self, forKey: .dtlsCompression)) ?? ""
    }
}

private struct AgentStat: Decodable {
    var bytesSent: UInt64 = 0
    var bytesReceived: UInt64 = 0

    private enum CodingKeys: String, CodingKey {
        case bytesSent = "bytesSent"
        case bytesReceived = "bytesReceived"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bytesSent = (try? container.decode(UInt64.self, forKey: .bytesSent)) ?? 0
        bytesReceived = (try? container.decode(UInt64.self, forKey: .bytesReceived)) ?? 0
    }
}

private struct AgentVersionReply: Decodable {
    var version = ""
    var commit = ""
    var agentVersion = ""
    var goVersion = ""

    private enum CodingKeys: String, CodingKey {
        case version
        case commit
        case agentVersion = "agent_version"
        case goVersion = "go_version"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(String.self, forKey: .version)) ?? ""
        commit = (try? container.decode(String.self, forKey: .commit)) ?? ""
        agentVersion = (try? container.decode(String.self, forKey: .agentVersion)) ?? ""
        goVersion = (try? container.decode(String.self, forKey: .goVersion)) ?? ""
    }
}

/// 事件续流盒：AsyncStream 的构造闭包是非隔离的，用该盒子把续流传给 actor。
nonisolated private final class EventSink: @unchecked Sendable {
    var continuation: AsyncStream<AgentEvent>.Continuation?
}

/// 请求续流盒：withCheckedThrowingContinuation 的闭包是 sending 的，
/// 不能直接改 actor 状态，通过该盒子中转。
nonisolated private final class PendingBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _continuation: CheckedContinuation<RPCResponse, Error>?

    var continuation: CheckedContinuation<RPCResponse, Error>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _continuation
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _continuation = newValue
        }
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation = _continuation else { return }
        _continuation = nil
        continuation.resume(throwing: error)
    }
}

/// 握手等待盒：didOpen / 超时 / 关闭都可能 resume，用锁保证只成功一次。
nonisolated private final class OpenBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _continuation: CheckedContinuation<Bool, Never>?

    var continuation: CheckedContinuation<Bool, Never>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _continuation
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _continuation = newValue
        }
    }

    func resume(result: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation = _continuation else { return }
        _continuation = nil
        continuation.resume(returning: result)
    }
}

private struct RPCResponse: Sendable {
    var resultData: Data?
    var errorMessage: String?
}

nonisolated private final class SocketDelegate: NSObject, URLSessionWebSocketDelegate {
    nonisolated(unsafe) var onOpen: @Sendable () -> Void = {}
    nonisolated(unsafe) var onClose: @Sendable (Error?) -> Void = { _ in }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose(nil)
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            onClose(error)
        }
    }
}

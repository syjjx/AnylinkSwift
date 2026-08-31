import Combine
import Foundation
import Security

@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published var gateways: [GatewayProfile]
    @Published var selectedGatewayID: UUID
    @Published var otp = ""
    @Published private(set) var settings: AppSettings
    @Published private(set) var snapshot = TunnelSnapshot.inactive
    @Published private(set) var traffic = TrafficSnapshot.inactive
    @Published private(set) var routes = RouteSnapshot.inactive
    @Published private(set) var trafficRates = TrafficRates.inactive
    @Published private(set) var connectionLogs: [String] = []
    @Published private(set) var connectedSince: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var agentState: AgentInstallState = .missing
    @Published private(set) var isAgentBusy = false
    @Published private(set) var agentVersionInfo = AgentVersionInfo(running: nil, bundled: nil)

    private let service: any ConnectionService
    private let installer = AgentInstaller()
    /// 连接成功后收起主窗口（"连接后最小化"设置）时使用。
    weak var appDelegate: AppDelegate?
    private let configurationURL: URL
    private let profileURL: URL
    private var lastProfileName: String
    private var operation: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var logTailTask: Task<Void, Never>?
    private var logFileIdentity: (device: Int, inode: Int)?
    private var logFileOffset: UInt64 = 0
    private var lastTrafficSample: (date: Date, sent: UInt64, received: UInt64)?

    private static let vpnAgentLogURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("vpnagent.log")
    private static let maxLogEntries = 5000

    init(service: any ConnectionService = AgentConnectionService()) {
        let defaultGateways = [
            GatewayProfile(name: "主网关", host: "vpn.example.com:4321", username: "yinjia"),
            GatewayProfile(name: "备用网关", host: "192.0.2.2:443")
        ]
        let configurationURL = Self.configurationFileURL()
        let profileURL = configurationURL.deletingLastPathComponent()
            .appendingPathComponent("profile.json")
        let persistedConfiguration = Self.loadConfiguration(from: configurationURL)
        let initialGateways = Self.loadProfiles(from: profileURL) ?? defaultGateways
        let initialSettings = persistedConfiguration.settings

        self.gateways = initialGateways
        self.selectedGatewayID = initialGateways.first {
            $0.displayName == persistedConfiguration.lastProfile
        }?.id ?? initialGateways.first?.id ?? UUID()
        self.settings = initialSettings
        self.service = service
        self.configurationURL = configurationURL
        self.profileURL = profileURL
        self.lastProfileName = persistedConfiguration.lastProfile

        if !FileManager.default.fileExists(atPath: configurationURL.path) {
            saveConfiguration()
        }

        if !FileManager.default.fileExists(atPath: profileURL.path) {
            saveProfiles()
        }

        startConsumingEvents()
        startLogTailing()
        refreshAgentState()
        Task { await refreshAgentVersion() }
        Task { [service] in
            await service.applySettings(initialSettings)
        }
        if initialSettings.autoConnect {
            Task { [weak self] in
                guard let self else { return }
                await self.autoConnectWhenReady()
            }
        }
    }

    /// 启动时自动连接：等待 vpnagent RPC 就绪后立即连接，不做固定延迟。
    private func autoConnectWhenReady() async {
        guard agentState != .missing else {
            appendLog("connection: [Info] 启动时自动连接已跳过（VPN 服务组件未安装）")
            return
        }
        appendLog("connection: [Info] 启动时自动连接：等待 vpnagent 就绪…")
        var reachable = false
        for _ in 0..<40 {
            if Task.isCancelled { return }
            if await isAgentReachable() {
                reachable = true
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        guard reachable else {
            appendLog("connection: [Error] 启动时自动连接失败：vpnagent 服务不可达")
            return
        }
        guard connectionState == .disconnected else { return }
        appendLog("connection: [Info] 启动时自动连接（设置已开启）")
        connect()
    }

    /// 探测 vpnagent 的 RPC 端口（127.0.0.1:6210）是否可连接。
    private func isAgentReachable() async -> Bool {
        await Task.detached(priority: .utility) {
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = UInt16(6210).bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            guard fd >= 0 else { return false }
            defer { close(fd) }
            let result = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            return result == 0
        }.value
    }

    // MARK: - VPN 服务组件

    func refreshAgentState() {
        agentState = installer.currentState()
    }

    /// 检查运行中 vpnagent 版本（VERSION RPC）与打包版本（bundle 内二进制），
    /// 运行版本低于打包版本时提示更新。
    func refreshAgentVersion() async {
        // daemon 重装后正在重启（新进程监听 6210 前旧连接已失效），
        // 首次查询失败时等待片刻重试一次。
        var running: String?
        for attempt in 0..<2 {
            do {
                let version = try await service.queryAgentVersion()
                running = version.version
                break
            } catch {
                await service.resetConnection()
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }
        let bundled = await installer.bundledSSLConVersion()
        // 运行版本查不到但 daemon 已安装（无论指向当前 bundle 还是其他副本）：
        // 运行的是旧进程（无 VERSION 接口），无法证明其不落后，视为需要更新。
        let treatUnknown = running == nil && bundled != nil && agentState != .missing
        agentVersionInfo = AgentVersionInfo(
            running: running,
            bundled: bundled,
            treatUnknownRunningAsUpdate: treatUnknown
        )
        if agentVersionInfo.needsUpdate {
            appendLog("agent: [Info] vpnagent 版本过旧（运行 \(running ?? "未知")，打包 \(bundled ?? "未知")），请更新服务组件")
        }
    }

    /// 是否需要提示用户处理 VPN 服务组件（顶部横幅显示条件）。
    /// 未安装、或 daemon 指向的 vpnagent 版本落后于当前应用打包版本时提示；
    /// daemon 指向其他路径但运行版本不落后（如 Xcode 开发构建）时视为可用，不提示。
    var agentNeedsAttention: Bool {
        agentState == .missing || agentVersionInfo.needsUpdate
    }

    func installAgent() async {
        guard !isAgentBusy else { return }
        isAgentBusy = true
        defer { isAgentBusy = false }

        guard installer.hasBundledAgent() else {
            appendLog("agent: [Error] 应用包内缺少 vpnagent 组件（开发构建请重新构建或使用打包版本）")
            return
        }

        appendLog("agent: [Info] 安装 VPN 服务组件…")
        do {
            try await installer.install()
            refreshAgentState()
            appendLog("agent: [Info] VPN 服务组件安装完成")
            // daemon 已重启，旧连接失效，重置后重新检查版本以刷新界面提示
            await service.resetConnection()
            await refreshAgentVersion()
        } catch {
            appendLog("agent: [Error] VPN 服务组件安装失败: \(error.localizedDescription)")
        }
    }

    func uninstallAgent() async {
        guard !isAgentBusy else { return }
        isAgentBusy = true
        defer { isAgentBusy = false }

        appendLog("agent: [Info] 卸载 VPN 服务组件…")
        do {
            try await installer.uninstall()
            refreshAgentState()
            appendLog("agent: [Info] VPN 服务组件已卸载")
            await service.resetConnection()
            await refreshAgentVersion()
        } catch {
            appendLog("agent: [Error] VPN 服务组件卸载失败: \(error.localizedDescription)")
        }
    }

    var selectedGateway: GatewayProfile {
        gateways.first(where: { $0.id == selectedGatewayID })
            ?? gateways.first
            ?? GatewayProfile(name: "", host: "")
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

    func setSetting(_ keyPath: WritableKeyPath<AppSettings, Bool>, to value: Bool) {
        guard settings[keyPath: keyPath] != value else { return }

        var updatedSettings = settings
        updatedSettings[keyPath: keyPath] = value
        settings = updatedSettings
        saveConfiguration()

        let service = self.service
        let currentSettings = settings
        Task {
            await service.applySettings(currentSettings)
        }
    }

    func toggleConnection() {
        if connectionState == .connected {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        guard
            !gateways.isEmpty,
            connectionState == .disconnected || connectionState == .failed
        else {
            return
        }

        operation?.cancel()
        connectionState = .connecting
        snapshot = .inactive
        traffic = .inactive
        routes = .inactive
        connectedSince = nil
        lastError = nil

        let gateway = selectedGateway
        let oneTimePassword = otp
        appendLog("connection: [Info] starting connection to \(gateway.address)")

        operation = Task { [weak self] in
            guard let self else { return }

            do {
                try await service.connect(to: gateway, otp: oneTimePassword)
                guard !Task.isCancelled else { return }

                connectionState = .connected
                connectedSince = Date()
                lastProfileName = gateway.displayName
                saveConfiguration()
                appendLog("connection: [Info] connection established")
                if settings.minimizeOnConnect {
                    appDelegate?.minimizeMainWindow()
                }
            } catch is CancellationError {
                // A cancelled local operation is not a connection failure.
            } catch {
                connectionState = .failed
                lastError = error.localizedDescription
                appendLog("connection: [Error] connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        guard connectionState == .connected else { return }

        operation?.cancel()
        connectionState = .disconnecting
        appendLog("connection: [Info] disconnect requested")

        operation = Task { [weak self] in
            guard let self else { return }
            await self.service.disconnect()
            guard !Task.isCancelled else { return }

            self.transitionToDisconnected()
            appendLog("connection: [Info] connection closed")
        }
    }

    /// 应用退出前同步断开 VPN（由 AppDelegate 的 terminateLater 流程调用）。
    func disconnectForTermination() async {
        guard connectionState == .connected || connectionState == .connecting else { return }
        appendLog("connection: [Info] 应用退出，断开连接")
        operation?.cancel()
        await service.disconnect()
        transitionToDisconnected()
        appendLog("connection: [Info] connection closed")
    }

    // MARK: - 通信层事件

    private func startConsumingEvents() {
        let stream = service.events
        eventTask = Task { [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .tunnelEstablished(let info):
            guard connectionState == .connected || connectionState == .connecting else { return }
            applyTunnelInfo(info)
        case .traffic(let traffic):
            guard connectionState == .connected else { return }
            self.traffic = TrafficSnapshot(
                sentBytes: Int64(clamping: traffic.sentBytes),
                receivedBytes: Int64(clamping: traffic.receivedBytes)
            )
            updateTrafficRates(with: traffic)
        case .closed(let message):
            guard connectionState == .connected || connectionState == .disconnecting else { return }
            transitionToDisconnected()
            appendLog("connection: [Info] \(message)")
        case .aborted(let message):
            guard connectionState == .connected || connectionState == .connecting else { return }
            connectionState = .failed
            lastError = message
            snapshot = .inactive
            traffic = .inactive
            routes = .inactive
            trafficRates = .inactive
            lastTrafficSample = nil
            connectedSince = nil
            appendLog("connection: [Error] \(message)")
        }
    }

    private func transitionToDisconnected() {
        connectionState = .disconnected
        snapshot = .inactive
        traffic = .inactive
        routes = .inactive
        trafficRates = .inactive
        lastTrafficSample = nil
        connectedSince = nil
    }

    /// 由相邻两次流量统计差分计算实时速率。
    private func updateTrafficRates(with traffic: AgentTraffic) {
        let now = Date()
        if let last = lastTrafficSample {
            let interval = now.timeIntervalSince(last.date)
            if interval > 0 {
                trafficRates = TrafficRates(
                    sentPerSecond: max(0, Double(traffic.sentBytes) - Double(last.sent)) / interval,
                    receivedPerSecond: max(0, Double(traffic.receivedBytes) - Double(last.received)) / interval
                )
            }
        }
        lastTrafficSample = (date: now, sent: traffic.sentBytes, received: traffic.receivedBytes)
    }

    private func applyTunnelInfo(_ info: AgentTunnelInfo) {
        snapshot = TunnelSnapshot(
            channelType: info.dtlsConnected ? "DTLS" : "TLS",
            tlsCipherSuite: info.tlsCipherSuite,
            dtlsCipherSuite: info.dtlsCipherSuite,
            dtlsPort: info.dtlsPort,
            serverAddress: info.serverAddress,
            localAddress: info.localAddress,
            vpnAddress: info.vpnAddress,
            mtu: info.mtu == 0 ? "-" : String(info.mtu),
            dns: info.dns.isEmpty ? "-" : info.dns.joined(separator: ", "),
            cstpCompression: Self.compressionText(info.cstpCompression),
            dtlsCompression: Self.compressionText(info.dtlsCompression)
        )
        routes = RouteSnapshot(
            excluded: info.splitExclude.map { Self.routeEntry(from: $0) },
            secured: info.splitInclude.map { Self.routeEntry(from: $0) }
        )
    }

    /// 压缩算法可读文本：none → 未启用，空 → 未知。
    private static func compressionText(_ value: String) -> String {
        switch value.lowercased() {
        case "": return "未知"
        case "none": return "未启用"
        default: return value
        }
    }

    private static func routeEntry(from value: String) -> RouteEntry {
        let parts = value.split(separator: "/", maxSplits: 1)
        let address = parts.first.map(String.init) ?? value
        let rawPrefix = parts.count > 1 ? String(parts[1]) : ""
        let prefix = Self.prefixBits(from: rawPrefix) ?? rawPrefix
        return RouteEntry(address: address, prefix: prefix)
    }

    /// 把 "255.255.0.0" 之类的掩码转成前缀位数（原版用 QHostAddress::parseSubnet 解析）。
    private static func prefixBits(from mask: String) -> String? {
        let octets = mask.split(separator: ".")
        guard octets.count == 4 else { return nil }
        var bits = 0
        for octet in octets {
            guard let value = Int(octet), value >= 0, value <= 255 else { return nil }
            bits += value.nonzeroBitCount
        }
        return String(bits)
    }

    private func appendLog(_ message: String) {
        let formatter = Self.logDateFormatter
        connectionLogs.append("\(formatter.string(from: Date())) \(message)")
        trimLogs()
    }

    // MARK: - vpnagent 日志追踪

    private func startLogTailing() {
        logTailTask?.cancel()
        logTailTask = Task { [weak self] in
            await self?.logTailLoop()
        }
    }

    private func logTailLoop() async {
        while !Task.isCancelled {
            tailLogTick()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    /// 追踪 <临时目录>/vpnagent.log：每秒读取新增内容，
    /// 通过 inode 识别文件被重建（vpnagent 重启会删除重建日志）。
    private func tailLogTick() {
        let url = Self.vpnAgentLogURL
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? Int,
            let device = attributes[.systemNumber] as? Int,
            let inode = attributes[.systemFileNumber] as? Int
        else {
            // 日志文件尚不存在（vpnagent 未启动或已删除）
            logFileIdentity = nil
            logFileOffset = 0
            return
        }

        if logFileIdentity?.device != device || logFileIdentity?.inode != inode {
            logFileIdentity = (device, inode)
            logFileOffset = 0
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        do {
            if UInt64(size) < logFileOffset {
                logFileOffset = 0 // 文件被截断
            }
            try handle.seek(toOffset: logFileOffset)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return }
            logFileOffset = handle.offsetInFile

            let text = String(decoding: data, as: UTF8.self)
            guard !text.isEmpty else { return }

            var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            if text.last != "\n", let partial = lines.last {
                // 最后一行可能写入一半，回退 offset 等下一轮补齐
                logFileOffset -= UInt64(partial.utf8.count)
                lines.removeLast()
            }
            guard !lines.isEmpty else { return }

            let newLines = lines.map(String.init)
            connectionLogs.append(contentsOf: newLines)
            trimLogs()
        } catch {
            // 读取与删除/重建竞争，下一轮重试
        }
    }

    private func trimLogs() {
        guard connectionLogs.count > Self.maxLogEntries else { return }
        connectionLogs.removeFirst(connectionLogs.count - Self.maxLogEntries)
    }

    /// 清空日志窗口内容（文件追踪偏移保持不变，已读内容不会重新出现）。
    func clearLogs() {
        connectionLogs.removeAll()
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    func addGateway(address: String) {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return }

        let profile = GatewayProfile(name: trimmedAddress, host: trimmedAddress)
        gateways.append(profile)
        selectedGatewayID = profile.id
        KeychainStore.save(password: profile.password, account: profile.name)
        saveProfiles()
    }

    func saveProfile(_ draft: ProfileDraft, id: UUID?) -> UUID? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !host.isEmpty, !username.isEmpty else { return nil }

        let profileID = id ?? UUID()
        let oldProfile = gateways.first(where: { $0.id == profileID })
        guard !gateways.contains(where: { $0.id != profileID && $0.name == name }) else {
            return nil
        }

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

        if let oldProfile, oldProfile.name != profile.name {
            KeychainStore.delete(account: oldProfile.name)
            if lastProfileName == oldProfile.name {
                lastProfileName = profile.name
            }
        }
        KeychainStore.save(password: profile.password, account: profile.name)
        saveProfiles()
        saveConfiguration()
        selectedGatewayID = profileID
        return profileID
    }

    func profile(with id: UUID) -> GatewayProfile? {
        gateways.first(where: { $0.id == id })
    }

    func deleteProfile(id: UUID) {
        guard let profile = gateways.first(where: { $0.id == id }) else { return }

        gateways.removeAll(where: { $0.id == id })
        KeychainStore.delete(account: profile.name)
        saveProfiles()

        if lastProfileName == profile.name {
            lastProfileName = gateways.first?.displayName ?? ""
            saveConfiguration()
        }

        if selectedGatewayID == id {
            selectedGatewayID = gateways.first?.id ?? UUID()
        }
    }

    private func saveProfiles() {
        let persistedProfiles = Dictionary(
            uniqueKeysWithValues: gateways.map { profile in
                (profile.name, PersistedProfile(profile: profile))
            }
        )

        do {
            try FileManager.default.createDirectory(
                at: profileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(persistedProfiles)
            try data.write(to: profileURL, options: .atomic)
        } catch {
            print("Unable to save AnyLink profiles: \(error.localizedDescription)")
        }
    }

    private func saveConfiguration() {
        let persistedConfiguration = PersistedConfiguration(
            settings: settings,
            lastProfile: lastProfileName
        )

        do {
            try FileManager.default.createDirectory(
                at: configurationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(persistedConfiguration)
            try data.write(to: configurationURL, options: .atomic)
        } catch {
            print("Unable to save AnyLink configuration: \(error.localizedDescription)")
        }
    }

    private static func configurationFileURL() -> URL {
        let libraryURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")

        // Match the Qt client's QStandardPaths::AppConfigLocation and file name.
        return libraryURL
            .appendingPathComponent("Preferences", isDirectory: true)
            .appendingPathComponent("AnyLink", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private static func loadConfiguration(from url: URL) -> PersistedConfiguration {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return PersistedConfiguration()
        }

        do {
            return try JSONDecoder().decode(PersistedConfiguration.self, from: data)
        } catch {
            print("Unable to load AnyLink configuration: \(error.localizedDescription)")
            return PersistedConfiguration()
        }
    }

    private static func loadProfiles(from url: URL) -> [GatewayProfile]? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return []
        }

        do {
            let persistedProfiles = try JSONDecoder().decode(
                [String: PersistedProfile].self,
                from: data
            )

            return persistedProfiles.keys.sorted().compactMap { name in
                guard let profile = persistedProfiles[name] else { return nil }

                return GatewayProfile(
                    name: name,
                    host: profile.host,
                    username: profile.username,
                    password: KeychainStore.password(account: name) ?? "",
                    group: profile.group,
                    secret: profile.secret
                )
            }
        } catch {
            print("Unable to load AnyLink profiles: \(error.localizedDescription)")
            return []
        }
    }
}

private struct PersistedProfile: Codable {
    var host: String
    var username: String
    var group: String
    var secret: String

    init(profile: GatewayProfile) {
        host = profile.host
        username = profile.username
        group = profile.group
        secret = profile.secret
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = (try? container.decode(String.self, forKey: .host)) ?? ""
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        group = (try? container.decode(String.self, forKey: .group)) ?? ""
        secret = (try? container.decode(String.self, forKey: .secret)) ?? ""
    }
}

private enum KeychainStore {
    /// 新版应用自己的服务名：条目 ACL 归属当前应用，不会触发授权弹窗。
    private static let service = "keychain.tunnelpilot"

    static func password(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func save(password: String, account: String) {
        let data = Data(password.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            reportFailure(addStatus, operation: "save")
        } else {
            reportFailure(updateStatus, operation: "save")
        }
    }

    static func delete(account: String) {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status != errSecItemNotFound else { return }
        reportFailure(status, operation: "delete")
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func reportFailure(_ status: OSStatus, operation: String) {
        guard status != errSecSuccess else { return }
        print("Unable to \(operation) AnyLink Keychain credential (status: \(status))")
    }
}

private struct PersistedConfiguration: Codable {
    var lastProfile = ""
    var autoLogin = false
    var minimize = true
    var block = true
    var debug = false
    var local = true
    var noDTLS = false
    var compression = true

    private enum CodingKeys: String, CodingKey {
        case lastProfile
        case autoLogin
        case minimize
        case block
        case debug
        case local
        case noDTLS = "no_dtls"
        case compression
    }

    init() {}

    init(settings: AppSettings, lastProfile: String) {
        self.lastProfile = lastProfile
        autoLogin = settings.autoConnect
        minimize = settings.minimizeOnConnect
        block = settings.blockUntrustedServers
        debug = settings.debugLogging
        local = settings.useLocalLanguage
        noDTLS = settings.disableDTLS
        compression = settings.compressionEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode each known key independently so a missing or invalid value
        // falls back to its default without discarding other settings.
        lastProfile = (try? container.decode(String.self, forKey: .lastProfile)) ?? ""
        autoLogin = (try? container.decode(Bool.self, forKey: .autoLogin)) ?? false
        minimize = (try? container.decode(Bool.self, forKey: .minimize)) ?? true
        block = (try? container.decode(Bool.self, forKey: .block)) ?? true
        debug = (try? container.decode(Bool.self, forKey: .debug)) ?? false
        local = (try? container.decode(Bool.self, forKey: .local)) ?? true
        noDTLS = (try? container.decode(Bool.self, forKey: .noDTLS)) ?? false
        compression = (try? container.decode(Bool.self, forKey: .compression)) ?? true
    }

    var settings: AppSettings {
        var settings = AppSettings()
        settings.autoConnect = autoLogin
        settings.minimizeOnConnect = minimize
        settings.blockUntrustedServers = block
        settings.debugLogging = debug
        settings.compressionEnabled = compression
        settings.disableDTLS = noDTLS
        settings.useLocalLanguage = local
        return settings
    }
}

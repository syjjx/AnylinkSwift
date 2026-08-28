import Foundation

/// VPN 服务组件（vpnagent LaunchDaemon）的安装状态。
enum AgentInstallState: Equatable, Sendable {
    /// daemon 已安装且指向当前应用 bundle
    case installed
    /// daemon 已安装但指向其他位置（旧版应用或其他副本），需要重新安装
    case outdated
    /// 未安装
    case missing
}

enum AgentInstallerError: Error, LocalizedError {
    case executionFailed(Int32, String)
    case binaryMissing

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return "应用包内缺少 vpnagent 组件，请使用打包版本"
        case .executionFailed(let status, let message):
            if message.isEmpty {
                return "提权执行失败（退出码 \(status)）"
            }
            return "提权执行失败：\(message)"
        }
    }
}

/// 安装/卸载 vpnagent LaunchDaemon。
///
/// 设计文档的方案 A（AuthorizationExecuteWithPrivileges）在 Swift 中不可用
/// （该 API 已被标记 unavailable），采用方案 B：osascript 提权执行
/// `do shell script ... with administrator privileges`。
/// 后续如需上架 App Store，可演进到方案 C（SMAppService.daemon）。
struct AgentInstaller: Sendable {
    static let daemonPlistPath = "/Library/LaunchDaemons/sslcon.plist"

    /// 当前 bundle 内的 vpnagent 可执行文件路径。
    var vpnAgentPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/vpnagent").path
    }

    /// daemon 当前指向的 vpnagent 路径（未安装返回 nil）。
    static func installedAgentPath() -> String? {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: daemonPlistPath)),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let arguments = dict["ProgramArguments"] as? [String],
            let first = arguments.first
        else {
            return nil
        }
        return first
    }

    /// 当前安装状态。
    func currentState() -> AgentInstallState {
        guard let installed = Self.installedAgentPath() else { return .missing }
        return installed == vpnAgentPath ? .installed : .outdated
    }

    /// 提权安装：先卸载旧 daemon（容忍失败），再注册指向当前 bundle 的新 daemon。
    func install() async throws {
        let agent = shellQuote(vpnAgentPath)
        try await runPrivileged("\(agent) uninstall; \(agent) install")
    }

    /// 提权卸载 daemon。
    func uninstall() async throws {
        let agent = shellQuote(vpnAgentPath)
        try await runPrivileged("\(agent) uninstall")
    }

    // MARK: - 私有

    /// bundle 内是否存在 vpnagent 可执行文件。
    func hasBundledAgent() -> Bool {
        FileManager.default.isExecutableFile(atPath: vpnAgentPath)
    }

    /// shell 单引号转义。
    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// 通过 osascript 以管理员权限执行命令。
    /// 系统弹出管理员密码框；命令输出或错误会带回。
    private func runPrivileged(_ command: String) async throws {
        let script = "do shell script " + appleScriptQuote(command) + " with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try await Task.detached(priority: .userInitiated) {
            try process.run()
            process.waitUntilExit()
        }.value

        guard process.terminationStatus == 0 else {
            let message = Self.capturedOutput(of: process)
            throw AgentInstallerError.executionFailed(process.terminationStatus, message)
        }
    }

    /// 收集子进程输出（标准输出 + 错误）。
    private static func capturedOutput(of process: Process) -> String {
        var chunks: [Data] = []
        for pipe in [process.standardOutput, process.standardError] {
            if let pipe = pipe as? Pipe {
                chunks.append(pipe.fileHandleForReading.readDataToEndOfFile())
            }
        }
        return String(data: chunks.reduce(Data(), +), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// AppleScript 字符串转义。
    private func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

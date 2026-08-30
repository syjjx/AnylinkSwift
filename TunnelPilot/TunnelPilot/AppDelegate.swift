import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let mainWindowAutosaveName = "TunnelPilotMainWindow"
    private static let bundleID = "com.Syjjx.TunnelPilot"

    private(set) weak var mainWindow: NSWindow?
    /// 供"应用退出时断开连接"使用（TunnelPilotApp 注入）。
    weak var connectionManager: ConnectionManager?

    private var isDuplicateInstance = false
    private var didReplyTermination = false

    // MARK: - App 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单实例：已有实例在运行时激活它并退出自身
        if Self.activateExistingInstanceIfAny() {
            isDuplicateInstance = true
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.regular)

        // SwiftUI 启动时会重写 mainMenu,延迟一拍再接管更稳
        DispatchQueue.main.async { [weak self] in
            self?.installMinimalMenu()
        }
    }

    /// 应用退出前断开 VPN（对齐原版 Qt：退出即断网）。
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isDuplicateInstance, let connectionManager, connectionManager.connectionState == .connected else {
            return .terminateNow
        }

        didReplyTermination = false
        Task { @MainActor in
            await connectionManager.disconnectForTermination()
            self.finishTermination()
        }
        // 兜底：daemon 无响应时最多等待 3 秒后退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.finishTermination()
        }
        return .terminateLater
    }

    private func finishTermination() {
        guard !didReplyTermination else { return }
        didReplyTermination = true
        NSApp.reply(toApplicationShouldTerminate: true)
    }

    /// 若已有同 bundle id 的实例在运行，激活其窗口并返回 true。
    private static func activateExistingInstanceIfAny() -> Bool {
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let existing = others.first else { return false }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 幂等,防止 SwiftUI 生命周期中偶发覆盖菜单
        installMinimalMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - 精简主菜单(移除 File/View/Window/Help,仅保留 App 与 Edit)

    private func installMinimalMenu() {
        let mainMenu = NSMenu()

        mainMenu.addItem(makeAppMenuItem())
        mainMenu.addItem(makeEditMenuItem())

        NSApp.mainMenu = mainMenu
    }

    /// App 菜单(标题即应用名):Hide / Quit / Close Window
    private func makeAppMenuItem() -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        appMenu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        appMenu.addItem(.separator())

        // 保留 ⌘W 关窗 —— 你的应用靠关窗收起到状态栏
        appMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )

        appMenu.addItem(.separator())

        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.submenu = appMenu
        return appMenuItem
    }

    /// Edit 菜单:Undo / Redo / Cut / Copy / Paste / Select All
    /// 均使用标准 selector,系统自动路由到第一响应者
    private func makeEditMenuItem() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        editMenu.addItem(
            withTitle: "Undo",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        let redoItem = editMenu.addItem(
            withTitle: "Redo",
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(.separator())

        editMenu.addItem(
            withTitle: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    // MARK: - 窗口管理(保持你原有逻辑不变)

    func attachMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else {
            if window.delegate !== self {
                window.delegate = self
            }
            return
        }

        mainWindow = window
        window.delegate = self
        window.setFrameAutosaveName(Self.mainWindowAutosaveName)
        window.setFrameUsingName(Self.mainWindowAutosaveName)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow else { return true }

        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    /// 收起主窗口（等同关窗行为：orderOut + 驻留菜单栏）。
    /// 供"连接后最小化"设置使用。
    func minimizeMainWindow() {
        guard let mainWindow, mainWindow.isVisible else { return }
        mainWindow.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - 桥接:抓取底层 NSWindow 交给 AppDelegate

struct WindowAccessor: NSViewRepresentable {
    let appDelegate: AppDelegate

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                appDelegate.attachMainWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                appDelegate.attachMainWindow(window)
            }
        }
    }
}

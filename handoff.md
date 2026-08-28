# Handoff - TunnelPilot macOS GUI 项目

> 更新日期: 2026-08-28
> 用途: 新会话从本文档恢复上下文，继续本项目

---

## 一、项目定位

- 目标: 将 AnyLink SSL VPN 客户端的 macOS GUI 用 Swift/SwiftUI 重写为原生应用。
- 当前应用显示名称: **隧道助手 安全客户端**。
- Xcode 工程内部名称: `TunnelPilot`。
- 平台: 仅 macOS，当前 Deployment Target 为 macOS 13.5。
- 当前阶段: 只开发 GUI，通信层使用占位服务，不实际连接 VPN，不访问 `6210/rpc`。
- 原 Qt 工程和 Go `sslcon` 只作为参考，当前不要修改。

## 二、仓库和路径

| 路径 | 说明 |
|---|---|
| `/Volumes/MobileDisk/DEV/GO/anylink-client` | 原 Qt 项目，只读参考 |
| `/Volumes/MobileDisk/DEV/GO/sslcon` | Go 核心和 `vpnagent`，后续通信/路由目标 |
| `/Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift` | Swift 子仓库，当前主战场 |
| `AnyLinkSwift/TunnelPilot` | Xcode 原生 macOS 工程 |
| `AnyLinkSwift/handoff.md` | 本交接文档 |

GitHub:

- 仓库: https://github.com/syjjx/AnylinkSwift
- Swift 子仓库 remote: `https://github.com/syjjx/AnylinkSwift.git`
- 分支: `main`
- Git 用户: `syjjx`
- Git 邮箱: `syjjx@163.com`
- 最近一次已推送提交: `d8bec13 feat: add TunnelPilot macOS GUI`

注意: 外层 `/Volumes/MobileDisk/DEV/GO/anylink-client` 是旧 Qt 仓库，remote 不是 Swift 仓库。Git 操作涉及 Swift 工程时，工作目录必须是 `AnyLinkSwift`。

## 三、当前工程结构

```text
AnyLinkSwift/TunnelPilot/
├── TunnelPilot.xcodeproj/
└── TunnelPilot/
    ├── TunnelPilotApp.swift
    ├── ContentView.swift
    ├── AppDelegate.swift
    ├── AppTheme.swift
    ├── Components.swift
    ├── ConnectionModels.swift
    ├── ConnectionService.swift
    ├── ConnectionManager.swift
    ├── NativePopupButton.swift
    ├── MenuBarView.swift
    ├── GatewayView.swift
    ├── StatusView.swift
    ├── SettingsView.swift
    ├── HelpView.swift
    ├── SidebarView.swift
    ├── StatusBarView.swift
    ├── ProfileManagerView.swift
    ├── ConnectionLogsView.swift
    └── Assets.xcassets/
```

### 文件职责

- `TunnelPilotApp.swift`: Xcode App 入口、主窗口、详情窗口、配置管理窗口、连接日志窗口、`MenuBarExtra`。
- `ContentView.swift`: 主窗口手工双栏布局，固定内容尺寸 `820 x 600`。
- `AppDelegate.swift`: 记录主窗口、拦截关闭按钮、Dock/状态栏应用模式切换，并通过 `NSApp.mainMenu` 安装顶部精简应用菜单。
- `AppTheme.swift`: 浅色/深色颜色、圆角、卡片样式。
- `ConnectionModels.swift`: 页面枚举、连接状态、配置、流量、路由和设置数据模型。
- `ConnectionService.swift`: `ConnectionService` 协议和 `StubConnectionService` 占位实现。
- `ConnectionManager.swift`: GUI 唯一连接状态源，驱动连接/断开模拟、配置列表、详情数据。
- `NativePopupButton.swift`: AppKit `NSPopUpButton` 包装器和自定义 Cell。
- `MenuBarView.swift`: 菜单栏状态图标和菜单栏菜单。
- `GatewayView.swift`: 网关页、连接卡片、主机选择和配置管理按钮。
- `StatusView.swift`: 状态参数页和独立的流量/路由详情窗口内容。
- `SettingsView.swift`: 设置页。
- `HelpView.swift`: 帮助页。
- `ProfileManagerView.swift`: 配置管理窗口。
- `ConnectionLogsView.swift`: 独立连接日志窗口，显示倒序日志并自动定位到最新日志。

## 四、GUI 当前功能

### 1. 主窗口

- macOS 原生标题栏标题由 `WindowGroup("隧道助手 安全客户端", id: "main")` 提供。
- 没有自定义标题内容区。
- 主窗口内容固定为 `820 x 600`。
- 使用手工双栏，不使用 `NavigationSplitView`，避免系统侧栏材质和宽度干扰。
- 左侧栏约 `172pt`，包含应用标识、网关/状态/设置/帮助导航和连接状态。
- 底部状态栏显示连接状态和当前模式。
- 主窗口使用 AppKit frame autosave，重新打开应用时恢复上次停留的位置和窗口 frame。
- 多屏场景下通常会恢复到上次所在的屏幕；如果该屏幕已不可用或显示器排列发生变化，由 macOS 调整到可用位置。

### 2. 网关页

- 蓝色渐变连接状态卡。
- 主机配置区域。
- 主机下拉框是 AppKit `NSPopUpButton`，不是 SwiftUI `Picker` 或网页 `select`。
- 右侧配置按钮打开独立“配置管理”窗口。
- OTP 临时密码输入目前由网关页的 `SecureField` 提供；如果后续要避免系统 Passwords 建议，要沿用已经处理过的普通文本框星号方案，不要随意恢复系统密码字段。
- 连接按钮只触发 `StubConnectionService`，模拟约 1.5 秒连接，不实际网络通信。

### 3. 状态页

- 页面标题为“状态”，不是“连接状态”。
- 显示通道类型、TLS/DTLS 加密套件、DTLS 端口、服务器地址、本地地址、VPN 地址、MTU、DNS。
- 连接成功后“查看连接详情”按钮打开独立窗口。

### 4. 流量和路由详情窗口

- 独立 macOS `Window("流量统计和路由详情", id: "connection-details")`，可通过原生标题栏拖动。
- 显示发送字节、接收字节。
- 左侧显示“排除路由”，右侧显示“安全路由”。
- 路由字段为地址和前缀。
- 当前为占位演示数据，连接成功显示，断开后清空。

### 5. 设置页

- 显示启动自动连接、连接后最小化、证书不可信时终止、调试日志、思科协议兼容、不使用 DTLS、使用本地语言等选项。
- 设置保存到应用配置目录下的 `config.json`，开关变化后立即写盘。

### 6. 配置管理

- 独立 macOS `Window("配置管理", id: "profile-manager")`，可拖动。
- 左侧配置列表，右侧编辑表单。
- 字段: 名称、主机、用户名、密码、用户组、密钥。
- 支持新建、删除、保存。
- 配置保存到应用配置目录下的 `profile.json`；密码不写入 JSON，而是使用 macOS Keychain 保存。
- `profile.json` 的结构兼容原版：配置名称作为顶层 key，字段为 `host`、`username`、`group`、`secret`。
- Keychain 使用 service `keychain.anylink`，account 使用配置名称。
- 配置列表选择已经改为点击时直接加载表单，不依赖 `onChange` 的间接同步，避免点击无反馈。
- 主机页下拉框显示配置名称；当前默认配置为“备用网关”。

### 7. 连接日志

- 独立 macOS `Window("连接日志", id: "connection-logs")`，默认尺寸为 `692 x 405`。
- 帮助页的“连接日志”按钮直接打开该独立窗口，不再使用帮助页内的临时 Sheet。
- 窗口内容不重复显示标题和副标题，日志区域直接占据主体。
- 日志使用等宽字体、支持文本选择和滚动；最新日志显示在顶部，新日志到达后自动滚动到顶部。
- 当前日志来自 `ConnectionManager` 的占位连接流程，仅用于 GUI 预览，不读取真实 `vpnagent.log`。
- 当前占位流程会记录开始连接、连接成功、请求断开、连接关闭和连接失败等信息。

## 五、菜单栏和窗口生命周期

- macOS 顶部应用菜单（窗口左上方的应用菜单）由 `AppDelegate` 通过 `NSApp.mainMenu` 自定义，当前仅保留 App 和 Edit，移除 File、View、Window、Help。
- `AppDelegate.applicationDidFinishLaunching` 延迟安装自定义菜单，`applicationDidBecomeActive` 再次幂等安装，避免 SwiftUI 覆盖菜单。
- `TunnelPilotApp.swift` 当前不使用 `.commandsRemoved()`；顶部应用菜单唯一控制来源是 `AppDelegate` 的 `installMinimalMenu()`。
- 右上角状态栏图标菜单是另一套独立功能，仍使用 SwiftUI `MenuBarExtra`，不要与顶部应用菜单混淆。
- 图标由 `ConnectionState.menuBarSymbol` 决定:
  - 未连接: `lock.open`
  - 连接中/断开中: `arrow.triangle.2.circlepath`
  - 已连接: `lock.shield.fill`
  - 失败: `exclamationmark.shield.fill`
- 菜单项当前为:
  - 打开应用
  - 快速连接/快速断开
  - 退出应用
- `AppDelegate.windowShouldClose` 拦截主窗口关闭:
  - 隐藏主窗口
  - `NSApp.setActivationPolicy(.accessory)`，隐藏 Dock 图标
  - 应用继续驻留菜单栏
- 菜单栏打开应用时恢复 `.regular`，显示主窗口和 Dock 图标。
- 不要用 `applicationShouldTerminateAfterLastWindowClosed` 让应用退出；当前应返回 `false`。

## 六、NativePopupButton 当前基线

这是用户已自行调整的文件，后续必须在当前版本上增量修改，不要覆盖、回退或重新生成:

- `AnyLinkSwift/TunnelPilot/TunnelPilot/NativePopupButton.swift`
- `AnyLinkSwift/TunnelPilot/TunnelPilot/GatewayView.swift`

当前 `NativePopupButton.swift` 的重要事实:

- `InsetPopupButtonCell` 自定义标题绘制区域。
- 用户当前自行设置了 `titleLeftInset = 18`，以后以用户当前值为准。
- `titleRightInset = 38`，为右侧自绘上下双箭头预留空间。
- `arrowRightInset = 14`，箭头由 Cell 自己绘制。
- `drawBorderAndBackground` 不绘制背景和边框，由 SwiftUI 外层负责。
- `AnchoredPopupButton` 重写 `mouseDown`、`performClick` 和部分键盘处理。
- 当前菜单定位代码位于 `AnchoredPopupButton.openMenu()`:

```swift
private func openMenu() {
    guard
        isEnabled,
        let menu,
        menu.numberOfItems > 0
    else {
        return
    }

    menu.minimumWidth = max(
        menu.minimumWidth,
        bounds.width
    )

    _ = menu.popUp(
        positioning: nil,
        at: NSPoint(
            x: bounds.minX,
            y: bounds.minY
        ),
        in: self
    )
}
```

- 用户明确表示不再使用“从控件底部向下 3pt 展开”的旧实现，后续不要擅自改回 `bounds.minY - 3`。
- 外层 SwiftUI 负责下拉框 `36pt` 高度、背景、边框和圆角。
- 内部 AppKit 控件负责菜单、选中项、原生交互。
- 如果继续修改菜单定位，必须先读取用户当前版本，围绕现有 `openMenu()` 做最小增量修改。

## 七、通信层现状

当前没有真实通信实现:

- `ConnectionService` 只有 `connect(to:otp:)` 和 `disconnect()` 抽象。
- `StubConnectionService` 只等待并返回，不访问网络。
- `ConnectionManager` 在模拟连接成功后填充 `TunnelSnapshot.demo`、`TrafficSnapshot.demo` 和 `RouteSnapshot.demo`。
- 后续接入真实服务时，目标链路是:

```text
GUI <- WebSocket JSON-RPC ws://127.0.0.1:6210/rpc -> sslcon -> AnyLink/ocserv
```

- 真实 RPC 方法: `connect`、`disconnect`、`reconnect`、`status`、`config`、`stat`。
- 真实通信接入应替换 `ConnectionService` 实现，尽量不改 GUI。

## 八、原版和路由优化参考

- Qt 原版关闭窗口逻辑参考 `src/anylink.cpp:86-97`，当前 Swift 版本采用菜单栏常驻和 Dock `.accessory` 模式。
- Qt 原版断线逻辑参考 `src/anylink.cpp:319-335`。
- AF_ROUTE 优化设计在外层仓库 `docs/afroute-optimization/`:
  - `routepipe.go`: 流水线路由实现
  - `routebench.go`: 性能对比
  - `AnyLink界面设计思路.md`: GUI 视觉参考
  - `AnyLink安装与首启提权设计.md`: 后续安装/提权流程
  - `AnyLink自动重连与通配域名设计.md`: 后续自动重连流程
- AF_ROUTE 补丁目标文件: `/Volumes/MobileDisk/DEV/GO/sslcon/utils/vpnc/vpnc_darwin.go`。
- 路由优化当前不属于 Swift GUI 任务，除非用户明确安排，不要修改。

## 九、构建和验证

工作目录:

```bash
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift/TunnelPilot
```

构建命令:

```bash
xcodebuild -project "TunnelPilot.xcodeproj" -scheme "TunnelPilot" -configuration Debug -sdk macosx -derivedDataPath "/tmp/TunnelPilotDerivedData" build
```

最近构建结果: `BUILD SUCCEEDED`（已包含连接日志、顶部应用菜单精简和 Keychain 测试代码清理）。

注意:

- Xcode 文件系统同步组会自动发现 `TunnelPilot/TunnelPilot/*.swift`，通常不需要手工修改 `project.pbxproj`。
- 构建产物放在 `/tmp/TunnelPilotDerivedData`，不要复制进项目。
- Swift 工程目前被外层旧仓库的 `.gitignore` 忽略，但 `AnyLinkSwift` 是独立 Git 仓库。
- Swift 子仓库中可能有本机生成的 `.DS_Store`、`xcuserdata`，不要提交。
- 当前 Swift 子仓库工作区曾有旧 Swift Package 文件删除状态，提交前必须确认是否为用户有意变更，不要自动清理或恢复。

## 十、后续待办

按当前阶段优先级:

1. 继续完善 GUI 视觉和交互，以用户当前的 `GatewayView.swift`、`NativePopupButton.swift` 和 `AppDelegate.swift` 为基线。
2. 完善菜单栏常驻模式和多个独立窗口的生命周期边界。
3. 接入真实 `ConnectionService`，实现 WebSocket JSON-RPC，但需用户明确安排后再做。
4. 将连接日志从占位日志切换为真实 `vpnagent.log` 或通信层日志流，并保留当前窗口交互。
5. 实现安装/首启提权和 `vpnagent` 管理。
6. 实现自动重连和通配域名轮换。
7. 打包、签名、公证和 DMG 分发。
8. 单独处理 `sslcon` AF_ROUTE 优化补丁。

## 十一、协作规则

- 本项目是对 macOS 下原版 AnyLink 的 Swift 重构；任何修改，特别是功能和交互行为修改，实施前应先查阅原版 AnyLink 的相关实现，以原版行为作为参考基线，除非用户明确要求改变原有行为。
- 用户已经自行修改的 `GatewayView.swift`、`NativePopupButton.swift` 和 `AppDelegate.swift` 必须作为事实基线；后续修改前必须读取当前版本，不要按旧对话中的代码覆盖。
- 修改前先读取当前文件，不要按旧对话中的代码猜测。
- GUI 文字使用中文；TLS、DTLS、MTU、DNS、VPN、Secret 等标准技术标识可保留。
- 当前通信层必须保持占位，不得因为按钮、菜单栏或详情页面改动而发起真实连接。
- 顶部应用菜单（File、Edit、View、Window、Help）与右上角状态栏 `MenuBarExtra` 是两套不同机制；修改其中一套时不要误删或改变另一套。
- Keychain 密码调试输出仅用于一次性测试，已删除，后续不得将密码写入控制台、连接日志或普通配置文件。
- 修改完成后运行 `xcodebuild` 验证。
- 只有用户明确要求时才 commit/push；提交前排除 `.DS_Store`、`xcuserdata`、构建产物和敏感配置。

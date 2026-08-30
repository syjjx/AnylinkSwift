# Handoff - TunnelPilot macOS GUI 项目

> 更新日期: 2026-08-30
> 用途: 新会话从本文档恢复上下文，继续本项目

---

## 一、项目定位

- 目标: 将 AnyLink SSL VPN 客户端的 macOS GUI 用 Swift/SwiftUI 重写为原生应用。
- 当前应用显示名称: **隧道助手 安全客户端**。
- Xcode 工程内部名称: `TunnelPilot`。
- 平台: 仅 macOS，当前 Deployment Target 为 macOS 13.5。
- 当前阶段: **已完成 vpnagent 真实通信对接与打包分发**，可通过 DMG 分享。
- 原 Qt 工程只作参考；Go `sslcon` 仓库已打补丁（AF_ROUTE + 日志），见下文。

## 二、仓库和路径

| 路径 | 说明 |
|---|---|
| `/Volumes/MobileDisk/DEV/GO/anylink-client` | 原 Qt 项目，只读参考 |
| `/Volumes/MobileDisk/DEV/GO/sslcon` | Go 核心和 `vpnagent`，**已修改**（见下）；remote: `origin`=上游 bjdgyc/sslcon，`fork`=syjjx/sslcon |
| `/Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift` | Swift 子仓库，当前主战场 |
| `AnyLinkSwift/TunnelPilot` | Xcode 原生 macOS 工程 |
| `AnyLinkSwift/handoff.md` | 本交接文档 |
| `AnyLinkSwift/package.sh` | 一键打包脚本（构建 + 签名 + DMG） |

GitHub:

- 仓库: https://github.com/syjjx/AnylinkSwift
- Swift 子仓库 remote: `https://github.com/syjjx/AnylinkSwift.git`
- 分支: `main`
- Git 用户: `syjjx` / 邮箱: `syjjx@163.com`
- Swift 仓库最近提交: `f5c6e79 feat: 添加应用图标`（未推送）
- sslcon 仓库最近提交（本地）:
  - `42ebd39` README: 补充 Cisco AnyConnect/ASA 支持说明（当前 HEAD）
  - `c8d6cb5` vpn: 动态分流可观测性
  - `3adb512` vpnc(darwin): 添加已存在的路由时跳过而非报错
  - `0471572` vpn: CONNECT 请求头对齐 openconnect
  - `22a89fc` auth: 兼容 Cisco ASA 认证流程
  - `382a90f` CONFIG 时按 log_path 重建日志文件
  - `a510a9b` macOS 路由改用 AF_ROUTE 流水线安装

注意: 外层 `/Volumes/MobileDisk/DEV/GO/anylink-client` 是旧 Qt 仓库，remote 不是 Swift 仓库。Git 操作涉及 Swift 工程时，工作目录必须是 `AnyLinkSwift`；涉及 sslcon 时是 `/Volumes/MobileDisk/DEV/GO/sslcon`。

## 三、当前工程结构

```text
AnyLinkSwift/
├── package.sh                 # 打包脚本
├── .gitignore                 # 排除 .DS_Store/xcuserdata/build/
└── TunnelPilot/
    ├── TunnelPilot.xcodeproj/
    └── TunnelPilot/
        ├── TunnelPilotApp.swift
        ├── ContentView.swift          # 含 VPN 服务组件安装横幅
        ├── AppDelegate.swift
        ├── AppTheme.swift
        ├── Components.swift
        ├── ConnectionModels.swift
        ├── ConnectionService.swift   # 协议 + StubConnectionService
        ├── AgentConnectionService.swift  # 真实 WebSocket JSON-RPC 客户端
        ├── AgentInstaller.swift      # vpnagent 服务组件安装/卸载
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
        └── Assets.xcassets/           # 应用图标（蓝渐变盾牌锁孔）
```

### 文件职责（新增/变更部分）

- `AgentConnectionService.swift`: actor 化 WebSocket JSON-RPC 客户端，连接/断开/状态/流量轮询，处理 vpnagent 推送 DISCONNECT/ABORT。
- `AgentInstaller.swift`: 检测 daemon 安装状态（installed/outdated/missing），osascript 提权执行 `vpnagent install/uninstall`。
- `ConnectionManager.swift`: 消费通信层事件填充隧道信息/流量/路由；1s 流量差分计算实时速率；vpnagent.log 尾部追踪；VPN 服务组件状态。
- `MenuBarView.swift`: 连接状态显示合成图（白色 lock 轮廓 + 白色两行速度文本，8pt 等宽，见 ConnectionModels.menuBarImage）。

## 四、GUI 当前功能

### 1. 主窗口

- 固定 `820 x 600`，手工双栏（左侧栏 172pt），AppKit frame autosave 恢复位置。
- 顶部 VPN 服务组件横幅（非 installed 时显示，布局流内嵌不遮挡内容）。

### 2. 网关页

- 蓝色渐变连接状态卡 + 连接/断开按钮。
- 主机下拉框是 AppKit `NSPopUpButton`（`NativePopupButton`，新增 `isEnabled` 参数）。
- **连接建立后禁用**: 主机下拉框、配置管理按钮、OTP 输入框（与原版一致，断开恢复）。
- 连接按钮走真实 `AgentConnectionService`。

### 3. 状态页

- 显示通道类型、TLS/DTLS 加密套件、DTLS 端口、服务器地址、本地地址、VPN 地址、MTU、DNS。
- 数据来自 status RPC（真实），"查看连接详情"打开独立窗口。

### 4. 流量和路由详情窗口

- 独立 `Window("流量统计和路由详情", id: "connection-details")`。
- 左侧"排除路由"= SplitExclude，右侧"安全路由" = SplitInclude；掩码转前缀位数（同 Qt parseSubnet 语义）。
- 流量来自 stat RPC（每 1 秒轮询）。

### 5. 设置页

- 设置项 + **底部"VPN 服务组件"卡片**（横排一行：状态点 + 更新/卸载按钮）。
- 组件状态: 已安装 / 指向旧版本应用（outdated）/ 未安装（missing）。
- `SettingRow` 垂直内边距 9。

### 6. 配置管理

- 独立 `Window("配置管理", id: "profile-manager")`，左侧列表右侧表单。
- `profile.json` 兼容原版结构；密码存 Keychain。
- **Keychain 服务名已改为 `keychain.tunnelpilot`**（不再用原版的 `keychain.anylink`，避免授权弹窗；旧密码不迁移，需重新输入一次）。
- 密码框 Passwords 建议问题由用户自行处理，以当前代码为准。

### 7. 连接日志

- 独立 `Window("连接日志", id: "connection-logs")`，倒序显示、自动滚动到顶部。
- **真实日志**: 尾部追踪 `<临时目录>/vpnagent.log`（每秒轮询，inode 识别 vpnagent 重启重建文件，半行补齐，上限 5000 条）；应用自身事件以 `connection:` 前缀混排。

### 8. 菜单栏

- `MenuBarExtra` label: 未连接 `lock.open`（灰）；连接中 `arrow.triangle.2.circlepath`；已连接 **合成图**（`lock` 白色线条 + 白色两行速度文本 ↑上传/↓下载，绘制为一张 NSImage，绕开 MenuBarExtra 固定字体限制）；失败 `exclamationmark.shield.fill`。
- 速度显示仅连接状态出现；字号/颜色/行距调整位置: `ConnectionModels.swift` 的 `TrafficRates.menuBarImage(fontSize:)`。

## 五、菜单栏和窗口生命周期

- 顶部应用菜单由 `AppDelegate` 的 `installMinimalMenu()` 安装（仅 App + Edit）。
- 右上角状态栏图标菜单是 SwiftUI `MenuBarExtra`，两套机制互不混淆。
- `windowShouldClose`: 隐藏主窗口 + `.accessory` 模式，驻留菜单栏；打开时恢复 `.regular`。
- 不要用 `applicationShouldTerminateAfterLastWindowClosed` 退出；返回 `false`。

## 六、NativePopupButton 当前基线

这是用户已自行调整的文件，后续必须在当前版本上增量修改，不要覆盖、回退或重新生成:

- `AnyLinkSwift/TunnelPilot/TunnelPilot/NativePopupButton.swift`
- `AnyLinkSwift/TunnelPilot/TunnelPilot/GatewayView.swift`

当前 `NativePopupButton.swift` 的重要事实:

- `InsetPopupButtonCell` 自定义标题绘制区域；`titleLeftInset = 18`、`titleRightInset = 38`、`arrowRightInset = 14`（以用户当前值为准）。
- `drawBorderAndBackground` 不绘制背景边框，由 SwiftUI 外层负责。
- `AnchoredPopupButton.openMenu()` 菜单定位（`bounds.minX/minY`），不要擅自改回 `bounds.minY - 3`。
- **已新增 `isEnabled` 参数**（连接状态下禁用主机下拉），在 `updateItems` 中赋值 `button.isEnabled`，勿再无条件置 true。

## 七、通信层现状（真实实现）

```text
GUI <- WebSocket JSON-RPC ws://127.0.0.1:6210/rpc -> vpnagent -> AnyLink/ocserv
```

- `AgentConnectionService`（actor）: 二进制帧，**按请求 id 分发**（sslcon 用 `req.ID.Num` 选方法，不是 method 名）:
  - status=0, config=1, connect=2, disconnect=3, reconnect=4, interface=5, stat=7
- 连接流程: 开 WS → config（log_path/log_level 等）→ connect（OTP 拼到密码尾部）→ 成功后启动轮询（stat 1s，status 60s）。
- 服务端推送: id=3 会话关闭（.closed）、id=6 异常中断（.aborted），断开后 GUI 相应转状态。
- 事件流 `AsyncStream<AgentEvent>` 驱动 ConnectionManager 更新界面。
- `ConnectionService` 协议: `connect(to:otp:)` / `disconnect()` / `applySettings(_:)` / `events`；`StubConnectionService` 保留可切回。
- 细节坑: `JSONSerialization.data(withJSONObject:)` 对字符串 result（config/connect 回复）必须带 `.fragmentsAllowed`，否则 ObjC 异常崩溃（已修）。

## 八、sslcon 补丁与部署

- **AF_ROUTE 路由优化已落地**（`utils/vpnc/vpnc_darwin.go` + 单测，提交 `a510a9b`）: 流水线发送/统一收 ACK，3000 条路由 12s → 25ms。
- **InitLog 修复**（`rpc/rpc.go`，提交 `382a90f`）: 启用被注释的 `base.InitLog()`，config RPC 后 vpnagent 按 `log_path` 写 `<临时目录>/vpnagent.log`（GUI 日志窗口依赖此文件）。
- **Cisco AnyConnect/ASA 支持**（2026-08-30 合并自 `fork`(syjjx/sslcon) main，快进到 `42ebd39`，本地补丁已在上游）:
  - auth 阶段 XML 协议兼容: device-id 带平台文本、增加 group-access、移除多余 mac-address-list、group-select 按需输出、认证响应 Cookie 回传、User-Agent 对齐 AnyConnect `<version>` 格式、ASA 错误响应显式报错（`auth/auth.go` + `auth/auth_test.go`）。
  - CONNECT 隧道请求头对齐 openconnect（`X-CSTP-Address-Type/X-CSTP-Version/X-CSTP-Protocol/X-CSTP-Hostname`，`vpn/tunnel.go`）。
  - macOS 路由已存在时跳过而非报错，修复"本机局域网路由已存在（EEXIST）导致连接中断"（`utils/vpnc/vpnc_darwin.go` 提交 `3adb512`）。
  - 动态域名分流可观测性: status 可查看域名→IP 映射、Debug 日志输出嗅探记录（`vpn/tun.go`、`vpn/tunnel.go`、`utils/utils.go`、`session/session.go`、`proto/dtd.go`）。
  - 已在 Cisco ASA 5545 (v9.14) 全流程实测通过（认证→TLS 隧道→DTLS→路由→DNS→动态分流）；ocserv 亦验证通过。
- **构建要求**: go.mod 声明 `go 1.26.2`，本机低版本时 `GOTOOLCHAIN` 自动下载。根目录分别执行 `go build -o sslcon sslcon.go` 和 `go build -o vpnagent vpnagent.go`（两入口各自含 main）；`go test ./auth/` 验证单测。当前已用 Go 1.26.2 编译通过，二进制在仓库根目录。
- **ASA 使用提示**: 服务器发布多个用户组时需 `-g` 指定组名（组不对报 Login failed）；`-l Debug` 可输出完整认证日志（密码已打码）。
- 本机部署: 旧版 daemon（`~/AnyLink/AnyLink.app`）已被新应用接管；`vpnagent`/`sslcon` 随应用 bundle 分发，首启提权安装 daemon（plist `/Library/LaunchDaemons/sslcon.plist`，Label `sslcon`，KeepAlive）。
- 路由优化不在 Swift 仓库维护；改 sslcon 后需重新打包（构建阶段自动编译）。

## 九、构建、打包和验证

工作目录:

```bash
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift/TunnelPilot
```

Debug 构建:

```bash
xcodebuild -project "TunnelPilot.xcodeproj" -scheme "TunnelPilot" -configuration Debug -sdk macosx -derivedDataPath "/tmp/TunnelPilotDerivedData" build
```

打包（Release + 签名 + DMG）:

```bash
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift && ./package.sh /tmp
```

工程要点:

- **Xcode 构建阶段 "Embed VPN Agent Binaries"**: 每次构建自动从 `/Volumes/MobileDisk/DEV/GO/sslcon` 编译并拷入 `vpnagent`/`sslcon`（Debug/Release 都生效）。go 用绝对路径 `/usr/local/go/bin/go`（Xcode 脚本环境 PATH 精简）。
- **`ENABLE_USER_SCRIPT_SANDBOXING = NO`**（目标级）: Xcode 默认给脚本阶段开沙箱，会拒绝 go 写产物目录。
- **沙箱已移除**（`ENABLE_APP_SANDBOX` 与 entitlements 文件都删了）: 与 osascript 提权/管理 root daemon 冲突；原版 Qt 同样非沙箱。
- 签名: Apple Development 证书（团队 `AST9E8XUZV`）；**无 Developer ID 证书** → 外部分发遇 Gatekeeper 需右键打开或清 quarantine；要全网静默分发需付费会员 + 公证。
- 最近构建结果: `BUILD SUCCEEDED`。

## 十、后续待办

1. **自动重连与通配域名轮换**（参考 `AnyLink自动重连与通配域名设计.md`）: ABORT 事件目前仅转失败态，未自动重连。
2. **公证与正式分发**: 申请 Developer ID 证书 + `notarytool` 公证（`package.sh` 预留步骤）。
3. **打包产物验证**: 新机器上 DMG 安装 → 首启安装服务组件 → 连接全流程。
4. 可选: sslcon 本地补丁（AF_ROUTE/InitLog/ASA 支持）已并入 `fork`(syjjx/sslcon) main；如需可再提交 PR 到上游 bjdgyc/sslcon。
5. 可选（上架 App Store 才需要）: NEPacketTunnelProvider 路线重写，免 root。

## 十一、协作规则

- 本项目是对 macOS 下原版 AnyLink 的 Swift 重构；功能/交互修改先查原版实现作基线，除非用户明确改变。
- 用户已自行修改的文件（`GatewayView.swift`、`NativePopupButton.swift`、`AppDelegate.swift` 及密码框方案）必须作为事实基线，修改前先读当前版本。
- 修改前先读取当前文件，不要按旧对话中的代码猜测。
- GUI 文字使用中文；TLS、DTLS、MTU、DNS、VPN、Secret 等标准技术标识可保留。
- 通信层已是真实实现；不要再把界面改动退回占位。
- 顶部应用菜单与右上角 `MenuBarExtra` 是两套机制，修改一套不要误伤另一套。
- Keychain 密码不得写入控制台、日志或配置文件。
- 修改完成后运行 `xcodebuild` 验证。
- 只有用户明确要求时才 commit/push；提交前排除 `.DS_Store`、`xcuserdata`、`build/`、构建产物和敏感配置。

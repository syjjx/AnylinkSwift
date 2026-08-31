# Handoff - TunnelPilot macOS GUI 项目

> 更新日期: 2026-08-31
> 用途: 新会话从本文档恢复上下文，继续本项目

---

## 一、项目定位

- 目标: 将 AnyLink SSL VPN 客户端的 macOS GUI 用 Swift/SwiftUI 重写为原生应用。
- 当前应用显示名称: **隧道助手 安全客户端**。
- Xcode 工程内部名称: `TunnelPilot`（App 版本 `MARKETING_VERSION = 1.0`）。
- 平台: 仅 macOS，当前 Deployment Target 为 macOS 13.5。
- 当前阶段: **已完成 vpnagent 真实通信对接与打包分发**（DMG 含 Applications 快捷方式）；核心功能完备：压缩开关、组件版本检查、单实例、退出即断开、启动自动连接。
- 原 Qt 工程只作参考；Go `sslcon` 仓库已打补丁并升级到第二期功能（压缩/自动重连/VERSION），见下文。

## 二、仓库和路径

| 路径 | 说明 |
|---|---|
| `/Volumes/MobileDisk/DEV/GO/anylink-client` | 原 Qt 项目，只读参考 |
| `/Volumes/MobileDisk/DEV/GO/sslcon` | Go 核心和 `vpnagent`，**已修改**（见下）；remote: `origin`=上游 bjdgyc/sslcon，`fork`=syjjx/sslcon |
| `/Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift` | Swift 子仓库，当前主战场 |
| `AnyLinkSwift/TunnelPilot` | Xcode 原生 macOS 工程 |
| `AnyLinkSwift/handoff.md` | 本交接文档 |
| `AnyLinkSwift/package.sh` | 一键打包脚本（构建 + 签名 + DMG，含 Applications 快捷方式） |

GitHub:

- 仓库: https://github.com/syjjx/AnylinkSwift
- Swift 子仓库 remote: `https://github.com/syjjx/AnylinkSwift.git`
- 分支: `main`
- Git 用户: `syjjx` / 邮箱: `syjjx@163.com`
- Swift 仓库最近提交（均已推送）:
  - `565bd77` fix: 网关页连接按钮点击区域覆盖整个胶囊（contentShape）
  - `8c07835` build: DMG 打包加入 Applications 快捷方式，便于拖入安装
  - `040fcec` feat: 版本检查、压缩开关、单实例与多项体验优化
- sslcon 仓库最近提交（本地 HEAD = `03ffe94`，第二期功能）:
  - `03ffe94` feat: 版本号支持（version 子命令 + RPC VERSION 接口）
  - `3110f2b` feat: CLI connect 增加 --no-compression / --no-reconnect 开关
  - `c113e38` feat: STAT 接口返回压缩统计与压缩协商状态
  - `cbdf48f` feat: 数据压缩、会话超时/租期处理、自动重连增强
  - `42ebd39` README: 补充 Cisco AnyConnect/ASA 支持说明（此前的 HEAD）
  - `382a90f` CONFIG 时按 log_path 重建日志文件
  - `a510a9b` macOS 路由改用 AF_ROUTE 流水线安装

注意: 外层 `/Volumes/MobileDisk/DEV/GO/anylink-client` 是旧 Qt 仓库，remote 不是 Swift 仓库。Git 操作涉及 Swift 工程时，工作目录必须是 `AnyLinkSwift`；涉及 sslcon 时是 `/Volumes/MobileDisk/DEV/GO/sslcon`。

## 三、当前工程结构

```text
AnyLinkSwift/
├── package.sh                 # 打包脚本（构建+签名+DMG，暂存目录含 /Applications 软链接）
├── .gitignore                 # 排除 .DS_Store/xcuserdata/build/
└── TunnelPilot/
    ├── TunnelPilot.xcodeproj/
    └── TunnelPilot/
        ├── TunnelPilotApp.swift     # 三窗口 + MenuBarExtra；注入 AppDelegate<->ConnectionManager
        ├── ContentView.swift        # 顶部组件横幅（未安装/版本过旧时显示）
        ├── AppDelegate.swift        # 单实例、退出即断开、最小化菜单、窗口管理
        ├── AppTheme.swift
        ├── Components.swift
        ├── ConnectionModels.swift
        ├── ConnectionService.swift  # 仅协议（Stub 已删除）
        ├── AgentConnectionService.swift  # 真实 WebSocket JSON-RPC 客户端
        ├── AgentInstaller.swift     # vpnagent 服务组件安装/卸载 + 版本读取/比较
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
        └── Assets.xcassets/         # 应用图标（蓝渐变闪电，与 LogoMark 一致）
```

### 文件职责（新增/变更部分）

- `AgentConnectionService.swift`: actor 化 WebSocket JSON-RPC 客户端，连接/断开/状态/流量轮询，VERSION 查询（id=8），`resetConnection()`（daemon 重启后重建连接）。
- `AgentInstaller.swift`: 检测 daemon 安装状态（installed/outdated/missing），osascript 提权执行 `vpnagent install/uninstall`；`AgentVersionInfo`（运行/打包版本比较，语义化版本）；`bundledSSLConVersion()` 执行 bundle 内 `sslcon version` 解析（vpnagent 入口无 version 子命令）。
- `ConnectionManager.swift`: 消费通信层事件填充隧道信息/流量/路由；1s 流量差分；vpnagent.log 尾部追踪；组件状态与版本检查；启动自动连接（探测 6210 就绪即连）；连接后最小化。
- `AppDelegate.swift`: 单实例检测（bundle id `com.Syjjx.TunnelPilot`）、`applicationShouldTerminate` + `.terminateLater` 退出前断开 VPN、`minimizeMainWindow()`、窗口收起到菜单栏。
- `MenuBarView.swift`: 连接状态显示合成图（白色 lock 轮廓 + 白色两行速度文本，见 ConnectionModels.menuBarImage）。

## 四、GUI 当前功能

### 1. 主窗口

- 固定 `820 x 600`，手工双栏（左侧栏 172pt），AppKit frame autosave 恢复位置。
- 顶部 VPN 服务组件横幅：非 installed **或运行版本过旧**时显示，按钮"立即安装/立即更新"。
- **单实例**: 重复启动会激活已有实例并退出（AppDelegate.activateExistingInstanceIfAny）。
- **退出即断开**: ⌘Q/菜单退出时若已连接，先发 disconnect RPC（最多等 3s）再退出（对齐原版 Qt）；强杀进程则保持连接。

### 2. 网关页

- 蓝色渐变连接状态卡 + 连接/断开按钮（`contentShape(Capsule())` 保证整个胶囊可点击）。
- 主机下拉框是 AppKit `NSPopUpButton`（`NativePopupButton`，`isEnabled` 参数）。
- **连接建立后禁用**: 主机下拉框、配置管理按钮、OTP 输入框（断开恢复）。
- 连接按钮走真实 `AgentConnectionService`。

### 3. 状态页

- 显示通道类型、TLS/DTLS 加密套件、**TLS/DTLS 通道压缩**（`lzs`/`oc-lz4`/未启用）、DTLS 端口、服务器地址、本地地址、VPN 地址、MTU、DNS。
- 行字号已统一缩小（key 11pt/value 12pt/内边距 8）避免滚动条。
- 数据来自 status RPC（真实），"查看连接详情"打开独立窗口。

### 4. 流量和路由详情窗口

- 独立 `Window("流量统计和路由详情", id: "connection-details")`。
- 左侧"排除路由"= SplitExclude，右侧"安全路由" = SplitInclude；掩码转前缀位数（同 Qt parseSubnet 语义）。
- 流量来自 stat RPC（每 1 秒轮询）。

### 5. 设置页

- 设置项: 启动时自动连接 / 连接后最小化 / 证书不可信时终止 / 启用调试日志 / **数据压缩** / 不使用 DTLS 通道。
- 底部"VPN 服务组件"卡片: 状态点 + 更新/卸载按钮 + **版本行**（运行版本 · 打包版本，过旧时黄色提示）。
- 说明: "兼容思科协议"已移除（cisco_compat 固定 true，ASA 兼容是 sslcon 默认行为）；"界面使用本地语言"已隐藏（数据层字段保留，未来多语言可恢复）。

### 6. 配置管理

- 独立 `Window("配置管理", id: "profile-manager")`，左侧列表右侧表单。
- `profile.json` 兼容原版结构；密码存 Keychain（服务名 `keychain.tunnelpilot`，旧密码不迁移）。

### 7. 连接日志

- 独立 `Window("连接日志", id: "connection-logs")`，倒序显示、自动滚动到顶部。
- **NSTextView 实现**（支持跨行选择复制）+ 底部"复制全部/清空"按钮。
- 真实日志: 尾部追踪 `FileManager.default.temporaryDirectory/vpnagent.log`（注意不是 /tmp，是 /var/folders/.../T；每秒轮询，inode 识别重建，半行补齐，上限 5000 条）；应用事件以 `connection:`/`agent:` 前缀混排。

### 8. 菜单栏

- `MenuBarExtra` label: 未连接 `lock.open`（灰）；连接中 `arrow.triangle.2.circlepath`；已连接 **合成图**（lock + 白色两行速度文本）；失败 `exclamationmark.shield.fill`。
- 速度显示仅连接状态出现；绘制参数在 `TrafficRates.menuBarImage(fontSize:)`。

## 五、菜单栏和窗口生命周期

- 顶部应用菜单由 `AppDelegate.installMinimalMenu()` 安装（仅 App + Edit）。
- 右上角状态栏图标菜单是 SwiftUI `MenuBarExtra`，两套机制互不混淆。
- `windowShouldClose`: 隐藏主窗口 + `.accessory` 模式，驻留菜单栏；打开时恢复 `.regular`。
- `applicationShouldTerminateAfterLastWindowClosed` 返回 `false`。
- `minimizeMainWindow()`: 连接后最小化设置使用（orderOut + accessory）。

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
  - status=0, config=1, connect=2, disconnect=3, reconnect=4, interface=5, stat=7, **version=8**（VERSION 接口，返回 version/commit/agent_version/go_version）
- 连接流程: 开 WS → config（log_path/log_level/compression/no_dtls 等）→ connect（OTP 拼到密码尾部）→ 成功后启动轮询（stat 1s，status 60s）。
- 服务端推送: id=3 会话关闭（.closed）、id=6 异常中断（.aborted）。
- `ConnectionService` 协议: `connect(to:otp:)` / `disconnect()` / `applySettings(_:)` / `queryAgentVersion()` / `resetConnection()` / `events`。**Stub 已删除**，无占位实现。
- status 回复新增字段（增量，旧解析不受影响）: `cstp_compression` / `dtls_compression`（`none`/`lzs`/`oc-lz4`）、`compress_stat`（未协商为 null）、`idle_timeout` / `auth_expiration`。
- 细节坑: `JSONSerialization.data(withJSONObject:)` 对字符串 result（config/connect 回复）必须带 `.fragmentsAllowed`，否则 ObjC 异常崩溃（已修）。
- `resetConnection()`: daemon 重装/重启后旧 socket 半死，必须显式关闭重建（安装组件后先 reset 再查版本）。

## 八、启动行为与版本检查

- **启动自动连接**（设置开启时）: `autoConnectWhenReady()` 探测 127.0.0.1:6210 TCP 端口（每 500ms，上限 20s），就绪立即 connect；组件未安装（missing）时跳过并记日志。
- **组件版本检查**: 启动时 `refreshAgentVersion()` —— VERSION RPC 拿运行版本（失败时等 1.5s 重试一次），`bundledSSLConVersion()` 拿打包版本；运行 < 打包 → 横幅提示"点击更新"；运行版本查不到但 daemon 指向当前 bundle → 视为旧进程，提示更新。
- **连接后最小化**: connect 成功且设置开启 → `appDelegate?.minimizeMainWindow()`。
- **退出断开**: `applicationShouldTerminate` 返回 `.terminateLater`，Task 发 disconnect RPC 后 `reply(toApplicationShouldTerminate:)`；3s 兜底超时。重复实例（`isDuplicateInstance`）退出时跳过断开。

## 九、sslcon 补丁与部署

- **当前 HEAD `03ffe94`**，编译版本 `2.1.0`（`base.Version`，可 `-ldflags -X` 注入），二进制已在仓库根目录（`sslcon`/`vpnagent`）。
- **第二期功能**（fork main 新增，已编译验证，单测全过）:
  - 数据压缩: 协商 `X-CSTP-Accept-Encoding: oc-lz4,lzs`，LZS 为 openconnect 逐位移植（黄金向量验证），LZ4 标准 block；服务端 `compression` 决定是否启用。
  - 会话超时/租期: `idle_timeout`/`auth_expiration`，到期前 60s 告警（`ExpiryTimer`）。
  - 自动重连增强: 异常断线指数退避（1s→60s 封顶），用户主动断开不触发（`auto_reconnect` 默认 true）。
  - 版本号: `version` 子命令 + RPC VERSION（id=8）。
- 此前补丁: AF_ROUTE 路由优化（`a510a9b`）、InitLog 修复（`382a90f`）、Cisco ASA 支持（认证 XML 兼容/CONNECT 头对齐/路由 EEXIST 跳过/动态分流可观测性，已在 ASA 5545 v9.14 与 ocserv 实测）。
- **构建要求**: go.mod `go 1.26.2`；根目录分别执行 `go build -o sslcon sslcon.go` 和 `go build -o vpnagent vpnagent.go`；推荐带版本:
  ```bash
  go build -ldflags "-X sslcon/base.Version=2.1.0 -X sslcon/base.Commit=$(git rev-parse --short HEAD)" -o sslcon sslcon.go
  ```
  网络受限时 `GOPROXY=https://goproxy.cn,direct`（lz4 依赖需下载）。
- **ASA 使用提示**: 多用户组需 `-g` 指定组名（组不对报 Login failed）；`-l Debug` 完整认证日志（密码已打码）。
- 本机部署: `vpnagent`/`sslcon` 随 app bundle 分发（`Contents/MacOS/`），首启提权安装 daemon（plist `/Library/LaunchDaemons/sslcon.plist`，Label `sslcon`，KeepAlive）。
- 路由优化/压缩等不在 Swift 仓库维护；改 sslcon 后需重新打包（Xcode 构建阶段自动编译）。

## 十、构建、打包和验证

工作目录:

```bash
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift/TunnelPilot
```

Debug 构建:

```bash
xcodebuild -project "TunnelPilot.xcodeproj" -scheme "TunnelPilot" -configuration Debug -sdk macosx -derivedDataPath "/tmp/TunnelPilotDerivedData" build
```

打包（Release + 签名 + DMG，含 Applications 快捷方式）:

```bash
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift && ./package.sh /tmp
# 产物 /tmp/隧道助手.dmg
```

工程要点:

- **Xcode 构建阶段 "Embed VPN Agent Binaries"**: 每次构建自动从 `/Volumes/MobileDisk/DEV/GO/sslcon` 编译并拷入 `vpnagent`/`sslcon`（Debug/Release 都生效）。go 用绝对路径 `/usr/local/go/bin/go`。
- **`ENABLE_USER_SCRIPT_SANDBOXING = NO`**（目标级）; **沙箱已移除**（与 osascript 提权/管理 root daemon 冲突）。
- 签名: Apple Development 证书（团队 `AST9E8XUZV`）；无 Developer ID → 外部分发需右键打开或清 quarantine。
- 版本显示（侧栏/帮助页/config 上报）统一读 `CFBundleShortVersionString`（1.0）。
- 最近构建结果: `BUILD SUCCEEDED`。

## 十一、已知问题与后续待办

### 已知问题

- **新 mac 首次连接偶发失败**: 原版 AnyLink 卸载后可能残留旧 vpnagent 进程占用 6210（GUI 连到旧 daemon，报 "tun0 exist" 类错误——旧版 sslcon 用 water 库建 tun0），重启应用/清理残留后恢复。暂未处理，后续可考虑: 安装时 `bootout` 旧服务、GUI 连接前校验 daemon 版本并拦截。
- `useLocalLanguage` 设置项已从 UI 隐藏，数据层字段保留（AppSettings/PersistedConfiguration）。

### 后续待办

1. **自动重连 GUI 配合**: sslcon core 已支持 `auto_reconnect`（异常断线自动重连），GUI 目前 ABORT 事件仅转失败态；可考虑断开重连期间显示"重连中"状态。
2. **公证与正式分发**: 申请 Developer ID 证书 + `notarytool` 公证（`package.sh` 预留步骤）。
3. 可选: sslcon 本地补丁已并入 `fork`(syjjx/sslcon) main；如需可再提交 PR 到上游 bjdgyc/sslcon。
4. 可选（上架 App Store 才需要）: NEPacketTunnelProvider 路线重写，免 root。

## 十二、协作规则

- 本项目是对 macOS 下原版 AnyLink 的 Swift 重构；功能/交互修改先查原版实现作基线，除非用户明确改变。
- 用户已自行修改的文件（`GatewayView.swift`、`NativePopupButton.swift`、`AppDelegate.swift` 及密码框方案）必须作为事实基线，修改前先读当前版本。
- 修改前先读取当前文件，不要按旧对话中的代码猜测。
- GUI 文字使用中文；TLS、DTLS、MTU、DNS、VPN、Secret 等标准技术标识可保留。
- 通信层已是真实实现；不要再把界面改动退回占位。
- 顶部应用菜单与右上角 `MenuBarExtra` 是两套机制，修改一套不要误伤另一套。
- Keychain 密码不得写入控制台、日志或配置文件。
- 修改完成后运行 `xcodebuild` 验证。
- 只有用户明确要求时才 commit/push；提交前排除 `.DS_Store`、`xcuserdata`、`build/`、构建产物和敏感配置。

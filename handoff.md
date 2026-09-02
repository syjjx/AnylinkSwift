# Handoff - TunnelPilot macOS GUI 项目

> 更新日期: 2026-09-02
> 用途: 新会话从本文档恢复上下文，继续本项目

---

## 一、项目定位

- 目标: 将 AnyLink SSL VPN 客户端的 macOS GUI 用 Swift/SwiftUI 重写为原生应用。
- 当前应用显示名称: **隧道助手 安全客户端**。
- Xcode 工程内部名称: `TunnelPilot`（App 版本 `MARKETING_VERSION = 1.0`）。
- 平台: 仅 macOS，当前 Deployment Target 为 macOS 13.5。
- 当前阶段: **已完成 vpnagent 真实通信对接与打包分发**（DMG 含 Applications 快捷方式）；核心功能完备：压缩开关、组件版本检查、单实例、退出即断开、启动自动连接、**异常断开自动重连**（GUI 状态 + 取消支持）。
- 原 Qt 工程只作参考；Go `sslcon` 仓库已打补丁并升级到第二期功能（压缩/自动重连/VERSION），见下文。
- 工程/仓库已接入 GitHub Actions 手动构建（见"CI/CD 与发布配置"）；**两个仓库已转 private（或计划转），自动更新已放弃，改为手动更新**。

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

- 仓库: https://github.com/syjjx/AnylinkSwift（**private**）、https://github.com/syjjx/sslcon（**private**，fork 自 bjdgyc/sslcon）
- 分支: 均为 `main`
- Git 用户: `syjjx` / 邮箱: `syjjx@163.com`（本机 git 未配 user.name/email，自动推断为 `沈寅佳 <shenyinjia@...local>`，与用户自行提交一致）
- **推送授权**: 沙箱环境已配 SSH key（`~/.ssh/id_ed25519`），remote 已改为 SSH URL——`AnylinkSwift origin` = `git@github.com:syjjx/AnylinkSwift.git`，`sslcon fork` = `git@github.com:syjjx/sslcon.git`（sslcon `origin` 仍为 https 上游，**不推上游**）
- Swift 仓库最近提交（`43edbcd` 已推送，均已在 main）:
  - `43edbcd` build: Embed 脚本 sslcon 默认路径通用化（优先 `$HOME/DEV/GO/sslcon`，回退 `/Volumes/MobileDisk`）
  - `7345562` ci: 构建改为手动触发（workflow_dispatch + 可选发布版本）
  - `5f12b2a` ci: 新增 GitHub Actions 自动构建（Release 无签名构建 + DMG + tag 发布）
  - `feb2f41` build: 修复打包失败（derivedData 移至本地 /tmp，避开 actool 权限问题）
  - `2787f62` feat: 自动重连 GUI 配合（重连中状态 + 设置开关 + 探测感知）
  - `67d55a2` docs: handoff 记录组件版本误报修复（70ca4dd）
- sslcon 仓库最近提交（fork main，均已推送）:
  - `92a33a7` fix: DTLS 中断后自动重建并修复自动重连竞态，升级版本 2.1.3
  - `9da274d` fix: 压缩开关失效（关闭后协商仍开启），清除残留 Accept-Encoding 头并升级 2.1.2
  - `761bc2a` ci: 构建改为手动触发（workflow_dispatch）
  - `d4d8ace` ci: 增加 workflow_dispatch 手动触发
  - `aec17b6` ci: 增加 go vet/test 步骤完善自动验证
  - `fd5f6a2` feat: 自动重连支持取消（DISCONNECT 置 ActiveClose）并升级版本 2.1.1
  - `03ffe94` feat: 版本号支持（version 子命令 + RPC VERSION 接口）
  - `3110f2b` feat: CLI connect 增加 --no-compression / --no-reconnect 开关
  - `c113e38` feat: STAT 接口返回压缩统计与压缩协商状态
  - `cbdf48f` feat: 数据压缩、会话超时/租期处理、自动重连增强

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
- `ConnectionManager.swift`: 消费通信层事件填充隧道信息/流量/路由；1s 流量差分；vpnagent.log 尾部追踪；组件状态与版本检查；启动自动连接（探测 6210 就绪即连）；连接后最小化；**自动重连状态机**（ABORT 后进 `.reconnecting`，探测循环每 2s 重发 CONNECT 感知重连成功，重连中可点"断开"取消）。
- `AppDelegate.swift`: 单实例检测（bundle id `com.Syjjx.TunnelPilot`）、`applicationShouldTerminate` + `.terminateLater` 退出前断开 VPN、`minimizeMainWindow()`、窗口收起到菜单栏。
- `MenuBarView.swift`: 连接状态显示合成图（白色 lock 轮廓 + 白色两行速度文本，见 ConnectionModels.menuBarImage）。

## 四、GUI 当前功能

### 1. 主窗口

- 固定 `820 x 600`，手工双栏（左侧栏 172pt），AppKit frame autosave 恢复位置。
- 顶部 VPN 服务组件横幅：**未安装或运行版本过旧**时显示，按钮"立即安装/立即更新"。注意 `.outdated`（daemon 指向其他路径）但运行版本 ≥ 打包版本时不提示（如 Xcode 开发构建，见第十一节）。
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

- 设置项: 启动时自动连接 / 连接后最小化 / 证书不可信时终止 / 启用调试日志 / **数据压缩** / **异常断开自动重连**（默认开，CONFIG 发 `auto_reconnect`）/ 不使用 DTLS 通道。
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

- `MenuBarExtra` label: 未连接 `lock.open`（灰）；连接中/重连中 `arrow.triangle.2.circlepath`；已连接 **合成图**（lock + 白色两行速度文本）；失败 `exclamationmark.shield.fill`。重连中菜单栏"快速断开"可用（取消重连）。
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
- 连接流程: 开 WS → config（log_path/log_level/compression/no_dtls/auto_reconnect 等）→ connect（OTP 拼到密码尾部）→ 成功后启动轮询（stat 1s，status 60s）。
- 服务端推送: id=3 会话关闭（.closed）、id=6 异常中断（.aborted）。
- `ConnectionService` 协议: `connect(to:otp:)` / `disconnect()` / `applySettings(_:)` / `queryAgentVersion()` / `resetConnection()` / `events`。**Stub 已删除**，无占位实现。
- status 回复新增字段（增量，旧解析不受影响）: `cstp_compression` / `dtls_compression`（`none`/`lzs`/`oc-lz4`）、`compress_stat`（未协商为 null）、`idle_timeout` / `auth_expiration`。
- 细节坑: `JSONSerialization.data(withJSONObject:)` 对字符串 result（config/connect 回复）必须带 `.fragmentsAllowed`，否则 ObjC 异常崩溃（已修）。
- `resetConnection()`: daemon 重装/重启后旧 socket 半死，必须显式关闭重建（安装组件后先 reset 再查版本）。

## 八、启动行为与版本检查

- **启动自动连接**（设置开启时）: `autoConnectWhenReady()` 探测 127.0.0.1:6210 TCP 端口（每 500ms，上限 20s），就绪立即 connect；组件未安装（missing）时跳过并记日志。
- **组件版本检查**: 启动时 `refreshAgentVersion()` —— VERSION RPC 拿运行版本（失败时等 1.5s 重试一次），`bundledSSLConVersion()` 拿打包版本；运行 < 打包 → 横幅提示"点击更新"；运行版本查不到但 daemon 已安装（无论指向当前 bundle 还是其他副本）→ 视为旧进程，提示更新。横幅统一按 `agentNeedsAttention`（missing 或版本落后）显示；daemon 指向其他路径但运行版本 ≥ 打包版本时不提示。
- **连接后最小化**: connect 成功且设置开启 → `appDelegate?.minimizeMainWindow()`。
- **退出断开**: `applicationShouldTerminate` 返回 `.terminateLater`，Task 发 disconnect RPC 后 `reply(toApplicationShouldTerminate:)`；3s 兜底超时。重复实例（`isDuplicateInstance`）退出时跳过断开。

## 九、sslcon 补丁与部署

- **fork main HEAD `92a33a7`**，编译版本 `2.1.3`（`base.Version`，可 `-ldflags -X` 注入），二进制已在仓库根目录（`sslcon`/`vpnagent`）。
- **第二期功能**（fork main 新增，已编译验证，单测全过）:
  - 数据压缩: 协商 `X-CSTP-Accept-Encoding: oc-lz4,lzs`，LZS 为 openconnect 逐位移植（黄金向量验证），LZ4 标准 block；服务端 `compression` 决定是否启用。
  - 会话超时/租期: `idle_timeout`/`auth_expiration`，到期前 60s 告警（`ExpiryTimer`）。
  - 自动重连增强: 异常断线指数退避（1s→60s 封顶），用户主动断开不触发（`auto_reconnect` 默认 true）。
  - 版本号: `version` 子命令 + RPC VERSION（id=8）。
- **2.1.1 版本改动（`fd5f6a2` 已推送 fork main）**:
  - `rpc/rpc.go`: DISCONNECT 分支在 `autoReconnecting` 进行中时置 `ActiveClose` 取消自动重连（原实现 `CSess == nil` 时仅报错，GUI 无法在重连中停止退避循环）。
  - `base/version.go`: 默认版本号升为 `2.1.1`（**规则: 改 sslcon 代码必须递增版本号**，否则运行/打包版本比对无法区分新旧）。
- **2.1.3 版本改动（`92a33a7` 已推送 fork main，2026-09-02）**——DTLS 中断后自动重建 + 自动重连竞态修复:
  - `vpn/dtls.go`: DTLS 通道中断（典型场景: macOS 空闲时网络状态变化，如 DHCP 续租换 IP/WiFi 切换/休眠唤醒，UDP sendto 报 `EADDRNOTAVAIL/can't assign requested address`）或协商失败后，指数退避（5s→60s，会话关闭即退出）自动重建，成功后恢复 `DtlsConnected`，GUI 状态页自动回到 DTLS；此前 `monitor()` 注释明确"不考虑 DTLS 中途关闭情形"，通道一旦中断只能 TLS 单通道运行且永远无法恢复。
  - `session/session.go`: `ConnSession.Close()`/`DtlsSession.Close()` 改为会话作用域（仅当 `Sess.CSess == cSess`/`Sess.CSess.DSess == dSess` 才清理全局状态）。修复自动重连竞态: 旧会话清理延迟执行（TLS 读卡在半个 TCP 连接上，网络恢复后才报错，日志表现为重连成功后 2s 出现 `read dead timer exit`）时，会误将 `Sess.CSess` 置空、误关新会话的 `Sess.CloseChan`（触发误 ABORT/再次重连/孤儿会话，孤儿 DTLS 通道会存活数小时后才死）并误清新会话的 `DtlsConnected`/`DTLSCipherSuite`。
  - `utils/vpnc/vpnc_darwin.go`: VPN 服务器主机路由改为**先删后加**（替换残留旧网关路由，杜绝 `EADDRNOTAVAIL` 死路由）；`pipelineLocked` 容忍 RTM_DELETE 的 `ESRCH/no such process`（macOS 对删除不存在路由在 write 阶段直接返回 ESRCH）与 `ENOENT`，**否则首次连接必失败**（踩坑记录: 首版只容忍了 ACK 阶段的 ENOENT，导致所有连接报 `write route 0 (VPN server ... (replace)): no such process`）。
  - `vpn/tunnel.go`: `SetRoutes` 失败分支补 `return err`（既有 bug，缺失时会在已关闭会话上继续启动通道并误报 `tls channel negotiation succeeded` 后立即全部退出）。
  - `session/session_test.go`: 新增 `TestConnSessionCloseDoesNotTouchNewSession`/`TestDtlsSessionCloseDoesNotTouchNewSession` 回归测试。
  - 实测（2026-09-02）: 连接正常、TLS/DTLS 均按 85s 周期响应 DPD-RESP（`dtls.go:203` 为新代码行号，确认 daemon 已更新）。
- 此前补丁: AF_ROUTE 路由优化（`a510a9b`）、InitLog 修复（`382a90f`）、Cisco ASA 支持（认证 XML 兼容/CONNECT 头对齐/路由 EEXIST 跳过/动态分流可观测性，已在 ASA 5545 v9.14 与 ocserv 实测）。
- **构建要求**: go.mod `go 1.26.2`；根目录分别执行 `go build -o sslcon sslcon.go` 和 `go build -o vpnagent vpnagent.go`；推荐带版本:
  ```bash
  go build -ldflags "-X sslcon/base.Version=2.1.3 -X sslcon/base.Commit=$(git rev-parse --short HEAD)" -o sslcon sslcon.go
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

- **Xcode 构建阶段 "Embed VPN Agent Binaries"**: 每次构建自动编译并拷入 `vpnagent`/`sslcon`（Debug/Release 都生效）。sslcon 源码查找顺序（`43edbcd` 起）: 环境变量 `SSLCON_REPO` → `$HOME/DEV/GO/sslcon`（新设备）→ `/Volumes/MobileDisk/DEV/GO/sslcon`（旧设备）；go 默认 `/usr/local/go/bin/go`，可用 `GO_BIN` 覆盖。找不到 sslcon 时 warning 跳过（产物会缺二进制，需注意）。
- **`ENABLE_USER_SCRIPT_SANDBOXING = NO`**（目标级）; **沙箱已移除**（与 osascript 提权/管理 root daemon 冲突）。
- 签名: Apple Development 证书（团队 `AST9E8XUZV`）；无 Developer ID → 外部分发需右键打开或清 quarantine。
- 版本显示（侧栏/帮助页/config 上报）统一读 `CFBundleShortVersionString`（1.0）。
- 最近构建结果: `BUILD SUCCEEDED`。

### 打包失败排查（2026-08-31 已修复）

**症状**: `package.sh` 构建阶段失败，`GenerateAssetSymbols` 报:

```
Assets.xcassets: error: Failed to write Swift generated asset symbols.
    Description: You don't have permission to save the file "GeneratedAssetSymbols.swift" in the folder "DerivedSources".
    Failure Reason: You don't have permission. / Operation not permitted
```

**根因**: actool（asset catalog 编译）写 `DerivedSources` 目录时受文件系统 ACL/位置限制:

1. **derivedData 位于外置磁盘**（本项目为 `/Volumes/MobileDisk/...`）: actool 写文件被拒。
2. **`~/Library/Caches`** 带 macOS 默认 ACL `group:everyone deny delete`，同样触发（actool 写入流程含删除/rename）。

**解决**: `package.sh` 的 `DERIVED_DATA` 默认改为本地 `/tmp/TunnelPilotBuild`（`DERIVED_DATA="${DERIVED_DATA:-/tmp/TunnelPilotBuild}"`，可用环境变量覆盖）。已实测稳定；构建缓存可随时重建，无需保留。

**排查步骤**（若再遇到）:

```bash
# 1. 换 /tmp 或 Xcode 默认 DerivedData 路径构建，判断是否路径相关
xcodebuild -project TunnelPilot.xcodeproj -scheme TunnelPilot -configuration Release -derivedDataPath /tmp/TestBuild build
# 2. 检查 DerivedSources 权限/ACL
ls -le build/.../DerivedSources
```

### CI/CD 与发布配置（2026-08-31）

**触发方式（均已改为手动）**:

| 仓库 | Workflow | 触发 | 产物 |
|---|---|---|---|
| AnylinkSwift | `Build & Package` | Actions 页 Run workflow；inputs.version 留空=仅 DMG，填 `v1.x`=构建后发布 Release | `TunnelPilot-DMG` artifact（DMG 未签名） |
| sslcon | `CI` | Actions 页 Run workflow | 5 平台矩阵编译 + go vet/test |
| sslcon | `Release` | Actions 页 Run workflow（fork 自带） | 多平台安装包（tar.gz/7z）→ GitHub Release |

要点:

- AnylinkSwift workflow: macos-latest runner；checkout 双仓库（AnyLinkSwift + syjjx/sslcon 源码）→ setup-go（go-version-file: sslcon/go.mod）→ xcodebuild Release（`CODE_SIGNING_ALLOWED=NO` 无签名）→ hdiutil DMG → artifact。**嵌入的是 sslcon 远程 main 最新代码**，改 sslcon 后必须先 push 再构建。
- artifact 默认保留 90 天；要长期分发用 version input 发 GitHub Release。
- **发布 Release 需仓库 Settings → Actions → General → Workflow permissions = Read and write**（默认只读会导致发布步骤失败，artifact 不受影响）。
- **private 仓库 Actions 配额**: 免费账户 2000 分钟/月，macOS runner 按 10 倍扣减（≈200 分钟/月）。手动按需构建足够。
- **自动更新已放弃**（用户决定，手动更新即可）。若未来要做: private 仓库 Releases 资产需认证、app 无法内置凭据 → 需另建 public 发布仓库（只放产物）做更新源，或改用第三方对象存储。
- 两个仓库已转 private（或计划转）。

### 多设备开发（另一台机器继续开发）

新设备准备: Xcode（≥17）+ Go 1.26+（官方 pkg 装 `/usr/local/go/bin/go` 与脚本默认一致）+ SSH key（公钥加到 GitHub）+ 签名证书（旧设备钥匙串导出 .p12 含私钥导入，仅本地测试可跳过）。

```bash
git clone git@github.com:syjjx/sslcon.git ~/DEV/GO/sslcon
git clone git@github.com:syjjx/AnylinkSwift.git ~/DEV/GO/AnylinkSwift
```

clone 到 `~/DEV/GO/sslcon` 后 Embed 脚本零配置（默认路径已通用化）。两设备共存时**改代码前先 git pull**，避免冲突。

### 沙箱（AI 会话）环境限制（仅代理开发时相关）

- 写 workspace 之外（如 `sslcon` 仓库、`~/.ssh`、`~/.gitconfig`）需提升权限并经用户批准；Go 构建需设 `GOCACHE` 到 workspace 内（如 `GOCACHE=/Volumes/MobileDisk/DEV/GO/anylink-client/.gocache`）。
- 钥匙串/打包: 2026-09-02 实测——提升权限（danger-full-access）后 `security find-identity` 可见证书、`./package.sh` 可完整跑通（xcodebuild Release + codesign + hdiutil DMG，产物 `/tmp/隧道助手.dmg`）。若未提升权限则钥匙串 0 证书、无法签名/打 DMG。
- git 已配 SSH 授权（见第二节），push 成功但本地 remote-tracking ref 更新可能报 `cannot lock ref` 警告（sslcon 的 .git 在 workspace 外），以 `git ls-remote` 核对远程为准。
- 转 private 后匿名 GitHub API 失效，远程验证改用 SSH。

## 十一、已知问题与后续待办

### 已知问题

- **新 mac 首次连接偶发失败**: 原版 AnyLink 卸载后可能残留旧 vpnagent 进程占用 6210（GUI 连到旧 daemon，报 "tun0 exist" 类错误——旧版 sslcon 用 water 库建 tun0），重启应用/清理残留后恢复。暂未处理，后续可考虑: 安装时 `bootout` 旧服务、GUI 连接前校验 daemon 版本并拦截。
- `useLocalLanguage` 设置项已从 UI 隐藏，数据层字段保留（AppSettings/PersistedConfiguration）。

### 已修复

- **自动重连/空闲后 DTLS 协商丢失且无法恢复**（2026-09-02，sslcon `92a33a7` 升级 2.1.3）: 症状——重连后 GUI 状态页 DTLS 显示"没有"（通道类型 TLS）；日志 `dtls.go` `sendto: can't assign requested address`（macOS 空闲时网络状态变化，如 DHCP 续租换 IP/WiFi 切换/休眠唤醒，UDP socket 失效）后 `dtls channel exit`，且再无重建。根因——① sslcon 无 DTLS 恢复机制（`monitor()` 注释"不考虑 DTLS 中途关闭情形"，通道只随会话启动一次）；② `ConnSession.Close()`/`DtlsSession.Close()` 改全局 `Sess.CSess`/`Sess.CloseChan`，自动重连时旧会话延迟清理会误清新会话（误 ABORT/孤儿会话，孤儿 DTLS 通道存活数小时后才死）；③ VPN 服务器主机路由残留旧网关（EEXIST 跳过不替换）→ EADDRNOTAVAIL。修复详见第九节 2.1.3 版本改动。实测: 连接正常，TLS/DTLS 均按 85s 周期响应 DPD-RESP。
- **CI 无签名 DMG 在其它 Mac 报"已损坏"且无"仍要打开"**（2026-08-31）: Xcode 26 的 ld 即使 `CODE_SIGNING_ALLOWED=NO` 也会给主二进制嵌入 linker-signed ad-hoc 签名，但 bundle 无正式签名（无 `_CodeSignature`），签名与内容不一致 → Gatekeeper 判"已损坏"（只能移到废纸篓，无"仍要打开"）。修复: workflow 构建后对 bundle 整体做 ad-hoc 签名（`codesign --force --sign -`，先签 vpnagent/sslcon 再签 app，`codesign --verify --deep --strict` 校验）。产物变为"未信任但签名完整"→ 恢复"仍要打开"。注意: 无签名/仅 linker-signed 的 app 在其它 Mac 都会这样，本地 `package.sh` 因用真实证书签名不受影响。
- **开发构建误报"VPN 服务指向旧版本应用"**（`70ca4dd`）: `.outdated` 原为纯路径比对（plist 指向路径 ≠ 当前 bundle 路径），Xcode 开发构建（bundle 在 DerivedData/自定义路径）与 daemon 指向的 `/Applications` 打包版路径不同，即使运行版本 == 打包版本也误报。修复: 横幅/设置页改按版本判断——`.outdated` 但运行版本 ≥ 打包版本（`agentNeedsAttention == false`）视为可用不提示；运行版本未知（旧进程无 VERSION）仍保守提示（`treatUnknown` 已覆盖 `.outdated`）。涉及 `ConnectionManager.swift`（新增 `agentNeedsAttention`）、`ContentView.swift`（横幅条件）、`SettingsView.swift`（状态文字/颜色）。

### 后续待办

1. ~~**自动重连 GUI 配合**~~（已完成 2026-08-31）: `.reconnecting` 状态 + 设置项"异常断开自动重连"（CONFIG 补发 `auto_reconnect`，此前缺失导致 daemon 侧自动重连实际未开启）+ GUI 探测循环（每 2s 重发 CONNECT 感知重连成功）；依赖 sslcon 的 DISCONNECT 取消重连改动（版本 2.1.1），**未重装新 daemon 前取消重连不生效**。
2. **转 private 收尾**（进行中）: 两个仓库 Settings → Danger Zone → Change visibility；并确认 Settings → Actions → Workflow permissions = **Read and write**（发布 Release 必需）。
3. **公证与正式分发**（可选）: 申请 Developer ID 证书 + `notarytool` 公证——手动更新场景下仍推荐，可消除首次安装"仍要打开"；CI 发布流程可加公证步骤。
4. 可选: sslcon 本地补丁已并入 `fork`(syjjx/sslcon) main；如需可再提交 PR 到上游 bjdgyc/sslcon。
5. 可选（上架 App Store 才需要）: NEPacketTunnelProvider 路线重写，免 root。

### 已放弃

- **自动更新服务**: 用户决定不做（使用人数少，手动更新足够）。保留思路见"CI/CD 与发布配置"。

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
- **git 授权**: 代理环境已配 SSH（2026-08-31），commit/push 可直接执行（推送目标: AnylinkSwift → `origin main`；sslcon → `fork main`，勿推上游 `origin`）。
- **改 sslcon 代码必须递增版本号**（`base/version.go`，当前 2.1.3），否则运行/打包版本比对无法区分新旧。
- **CI 均为手动触发**（workflow_dispatch）；日常流程: 改代码 → push 两仓库 → AnylinkSwift Actions 页 Run workflow → 下载 DMG。
- 沙箱环境签名/打 DMG 受限，正式打包用本机 `./package.sh`（见"沙箱环境限制"）。

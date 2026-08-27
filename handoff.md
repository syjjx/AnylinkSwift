# Handoff — AnyLink Swift 重构项目

> 更新日期: 2026-08-27
> 用途: 新会话从本文档恢复上下文，继续本项目

---

## 一、项目概览

- **目标**: 将 AnyLink SSL VPN 客户端（原 Qt 版）用 Swift/SwiftUI 重写为 macOS 原生应用（仅 macOS）
- **两条主线**:
  1. **sslcon 路由优化补丁**（AF_ROUTE 流水线，已验证，待落地）
  2. **Swift GUI 重构**（骨架完成，通信层占位，UI 状态机驱动）
- 已确认: 只开发 GUI，通信层占位不实际连接（当前阶段）

## 二、仓库与目录

| 路径 | 说明 |
|---|---|
| `/Volumes/MobileDisk/DEV/GO/anylink-client` | Qt 原版（只读参考，Qt 6 + C++14） |
| `/Volumes/MobileDisk/DEV/GO/sslcon` | Go 核心（活跃仓库 `bjdgyc/sslcon`，补丁目标） |
| `/Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift` | **Swift 重构项目（主战场）** |
| `AnyLinkSwift/docs/afroute-optimization/` | 4 份设计文档 + 验证程序源码 |

GitHub: https://github.com/syjjx/AnylinkSwift.git（user: syjjx, email: syjjx@163.com，remote 已配置）

## 三、架构理解（关键事实，勿想当然）

- **通信链路**: GUI 客户端 ← WebSocket JSON-RPC（`ws://127.0.0.1:6210/rpc`）→ sslcon（Go 二进制）→ 远程 VPN 服务器（AnyLink/ocserv）
- **RPC 方法**: `connect` / `disconnect` / `reconnect` / `status` / `config` / `stat`；服务器推送事件: `DISCONNECT`（正常断开）/ `ABORT`（异常断开）/ status
- **reconnect 语义**（`sslcon/rpc/connect.go:38-48`）: 复用断线前仍存活的 TLS 连接 + 会话 Cookie，免认证；**不接收参数**；仅短时断线有效；**换域名必须走完整 connect**
- **vpnagent**: root LaunchDaemon（`/Library/LaunchDaemons/sslcon.plist`，Label: sslcon），随 app 打包（`Contents/MacOS/` 下），负责隧道/路由/提权
- **macOS 现状无 IPv6 路由处理**（SplitInclude 仅 IPv4，utun 只配 IPv4 地址）
- 用户环境: 当前默认路由在 utun4（开着 VPN），物理网关 172.20.40.1 (en0)

## 四、AF_ROUTE 优化（已验证，待落地）

**问题**: `vpnc_darwin.go` 的 `execCmd()` 逐条 `sh -c "route add"` spawn 进程，大路由表连接等 30s+（实测本机 ~4ms/条，3000 条 = 12s）

**验证结论（已实测）**:

| 指标 | exec 老方案 | AF_ROUTE 流水线 | 提升 |
|---|---|---|---|
| 3000 条添加 | ~12s | **25ms** | ~480x |
| 3000 条删除 | ~12s | **13ms** | ~950x |
| 成功率 | - | 3000/3000，0 失败 0 丢包 | - |

**关键实现要点**:
1. 必须**流水线**（先全部 write 再统一收 ACK），逐条等 ACK 会触发 ENOBUFS
2. socket 队列会被 `route` 命令的广播通知污染，需先 drain
3. rt_msghdr 布局与 SDK `sys/net/route.h` 一致（RTM_VERSION=5）；必须带 `RTF_HOST` 标志
4. 网关要从 `netstat -rn -f inet` 找（`route -n get default` 在 VPN 连接时无 gateway）
5. 设计成地址族无关（v4 `sockaddr_in` 16B / v6 `sockaddr_in6` 28B）

**完整代码**: `docs/afroute-optimization/routepipe.go`（流水线）+ `routebench.go`（对比测试）

**TODO**: 修改 `/Volumes/MobileDisk/DEV/GO/sslcon/utils/vpnc/vpnc_darwin.go`（SetRoutes / ResetRoutes / DynamicAddIncludeRoutes / DynamicAddExcludeRoutes），保留 setDNS（scutil 一次性，不慢），提交 PR 到 bjdgyc/sslcon

**验证命令**: `sudo /tmp/routebench -n 500`、`sudo /tmp/routepipe -n 3000 -delay 15`

## 五、Swift 项目进度（当前状态）

**已提交**: `4045be6`（init 骨架）、`b14d7a2`（通信层占位 + 状态机）

```
AnyLinkSwift/Sources/AnyLink/
├── AnyLinkApp.swift          # 820×600 固定窗口，注入 ConnectionManager
├── MainWindow.swift          # NavigationSplitView 双栏（侧边栏 172px）
├── SidebarView.swift         # 品牌区 + 四导航 + 状态药丸（状态机驱动）
├── StatusBarView.swift       # 底部状态条（28px，状态机驱动）
├── Theme/AppTheme.swift      # 主题色（浅/深自动适配）+ 圆角常量
├── Services/
│   ├── ConnectionModels.swift    # ConnectionState / VPNStatus / ConnectionEvent
│   ├── ConnectionService.swift   # 通信层抽象协议（@MainActor）
│   ├── StubConnectionService.swift # 占位实现（模拟 1.5s 连接，不实际通信）
│   └── ConnectionManager.swift   # 状态机（ObservableObject，UI 唯一数据源）
└── Views/                    # Gateway / Status / Settings / Help
```

**构建**: `swift build`（Swift 6.2.3 / Xcode 26.2，平台 macOS 13+）、`swift run`

## 六、设计文档索引（重构参考，都在 `docs/afroute-optimization/`）

1. **AnyLink界面设计思路.md** — UI 规范: 双栏布局、配色（主色 #0a84ff、成功 #34c759）、四页面要点、SF Symbols、SwiftUI 落地对照表、窗口 820×600
2. **AnyLink安装与首启提权设计.md** — 安装流程: dmg 拖拽 + 首启检测 LaunchDaemon → AuthorizationServices 提权 `vpnagent install`（备选 osascript / SMAppService / NEPacketTunnelProvider）
3. **AnyLink自动重连与通配域名设计.md** — 状态机（idle/connecting/connected/reconnecting/failed）+ **两级重连**（先同域名 reconnect，连接真断才换域名）+ 通配域名规律生成（`<prefix><NN>.72k.cn`，每次重连换域名）+ OTP 阻塞停止自动重连
4. **README.md** — AF_ROUTE 优化完整方案 + 核心代码 + 补丁 TODO

## 七、待办（按优先级）

1. **sslcon AF_ROUTE 补丁**：修改 vpnc_darwin.go，用 routepipe.go 的流水线替换 execCmd
2. **Swift GUI 细化**：按设计文档完善四页面（当前是基础骨架，各页面细节/动效/状态待补）
3. **通信层真实实现**：实现 `ConnectionService`（URLSessionWebSocketTask 连 6210/rpc，JSON-RPC 2.0），替换 Stub，UI 零改动
4. **安装/首启提权流程**：AuthorizationServices + vpnagent install（详见设计文档 2）
5. **自动重连 + 通配域名轮换**：按设计文档 3 实现状态机扩展
6. **打包分发**：.app bundle、签名（Developer ID）、公证（notarytool）、dmg
7. 可选: 为 AF_ROUTE 补丁提 PR 到 bjdgyc/sslcon

## 八、常用命令速查

```bash
# Swift
cd /Volumes/MobileDisk/DEV/GO/anylink-client/AnyLinkSwift
swift build && swift run

# sslcon 构建（两个独立 main）
cd /Volumes/MobileDisk/DEV/GO/sslcon
go build -trimpath -ldflags "-s -w" -o sslcon sslcon.go
go build -trimpath -ldflags "-s -w" -o vpnagent vpnagent.go

# 路由验证
sudo /tmp/routebench -n 500
sudo /tmp/routepipe -n 3000 -delay 15
netstat -rn -f inet | grep 10.231

# 查看 sslcon daemon
cat /Library/LaunchDaemons/sslcon.plist
ls ~/AnyLink/AnyLink.app/Contents/MacOS/   # 旧版安装产物（AnyLink/sslcon/vpnagent）
```

## 九、注意事项

- 提交前 `swift build` 验证；提交用 git config 已设的 syjjx / syjjx@163.com
- 开发调试用 Swift 编译产物即可，**不要**装新版 app 与旧版 ~/AnyLink 冲突（两个 daemon 抢 6210 端口）
- 删除旧版正确顺序: 先 `sudo launchctl bootout system /Library/LaunchDaemons/sslcon.plist` 或运行 `~/AnyLink/uninstall.app`，再删目录
- Qt 原版断线逻辑参考: `anylink.cpp:319-335`（DISCONNECT 不重连 / ABORT 1.5s 快速重连 / 失败 3s 完整重连）

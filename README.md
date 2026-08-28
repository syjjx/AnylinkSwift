# 隧道助手 安全客户端（TunnelPilot）

AnyLink SSL VPN 的 macOS 原生客户端，使用 Swift/SwiftUI 重写，对接 `vpnagent`（Go）建立 AnyLink/ocserv 隧道。

- 显示名称: **隧道助手 安全客户端**
- 平台: macOS 13.5+
- 架构: x86_64 / arm64

## 功能特性

- **真实 VPN 通信**: 通过 WebSocket JSON-RPC（`ws://127.0.0.1:6210/rpc`）与 vpnagent 对接，支持连接/断开/重连、状态、流量统计
- **菜单栏常驻**: 窗口关闭后驻留菜单栏；连接状态下实时显示隧道上传/下载速率
- **服务组件管理**: 首启横幅引导提权安装 vpnagent 系统服务（LaunchDaemon），设置页可更新/卸载
- **真实连接日志**: 尾部追踪 vpnagent 日志文件，与进程同步刷新
- **配置管理**: 多网关配置，密码保存于 macOS Keychain
- **路由优化**: 内置 sslcon AF_ROUTE 流水线补丁，大路由表秒级安装
- **打包分发**: 一键脚本产出 DMG

## 架构

```text
┌─────────────────┐   WebSocket JSON-RPC   ┌────────────────────┐   AnyLink/ocserv
│  隧道助手 GUI    │ ─────────────────────► │ vpnagent (root)     │ ─────────────►
│  SwiftUI/AppKit │  ws://127.0.0.1:6210   │ sslcon 内核          │     VPN 隧道
└─────────────────┘                        └────────────────────┘
```

- GUI 与 vpnagent 之间使用 JSON-RPC 2.0（按请求 id 分发方法: status/config/connect/disconnect/reconnect/interface/stat）
- `vpnagent`/`sslcon` 二进制随应用打包，首启提权注册为系统 LaunchDaemon（`/Library/LaunchDaemons/sslcon.plist`）

## 构建

### 开发构建

```bash
cd TunnelPilot
xcodebuild -project "TunnelPilot.xcodeproj" -scheme "TunnelPilot" \
  -configuration Debug -sdk macosx \
  -derivedDataPath /tmp/TunnelPilotDerivedData build
```

Xcode 工程内置构建阶段 "Embed VPN Agent Binaries"，每次构建自动从本地 `sslcon` 仓库编译并打入 `vpnagent`/`sslcon`（路径可用环境变量 `SSLCON_REPO`、`GO_BIN` 覆盖）。

### 打包分发

```bash
./package.sh /tmp   # 产物: /tmp/隧道助手.dmg
```

脚本流程: Release 构建 → 逐个签名（含 Go 二进制）→ DMG。签名使用本机可用的 Apple Development 证书；对外公开分发需 Developer ID 证书 + 公证。

### 分享说明

- U盘/内网盘/IM 直传通常可直接运行；浏览器下载的副本会被 Gatekeeper 拦截，需右键打开一次，或执行 `xattr -dr com.apple.quarantine /Applications/TunnelPilot.app`
- 首次启动需输入管理员密码安装 VPN 服务组件（VPN 建网卡/加路由需要 root）

## 工程结构

```text
AnyLinkSwift/
├── package.sh                     # 打包脚本
└── TunnelPilot/
    ├── TunnelPilot.xcodeproj/
    └── TunnelPilot/
        ├── TunnelPilotApp.swift           # 应用入口与窗口
        ├── AgentConnectionService.swift   # WebSocket JSON-RPC 客户端
        ├── AgentInstaller.swift           # vpnagent 服务组件安装/卸载
        ├── ConnectionManager.swift        # 连接状态源与事件消费
        ├── ConnectionService.swift        # 通信协议抽象
        ├── ConnectionModels.swift         # 数据模型
        ├── GatewayView.swift              # 网关页
        ├── StatusView.swift               # 状态页
        ├── SettingsView.swift             # 设置页
        ├── ProfileManagerView.swift       # 配置管理窗口
        ├── ConnectionLogsView.swift       # 连接日志窗口
        ├── MenuBarView.swift              # 菜单栏
        └── ...
```

## 相关仓库

| 仓库 | 说明 |
|---|---|
| [syjjx/sslcon](https://github.com/syjjx/sslcon) | Go 通信核心（fork，含 AF_ROUTE 路由优化与日志修复） |
| [bjdgyc/sslcon](https://github.com/bjdgyc/sslcon) | sslcon 上游（MIT） |
| [bjdgyc/anylink](https://github.com/bjdgyc/anylink) | AnyLink 服务端 |
| [tlslink/anylink-client](https://github.com/tlslink/anylink-client) | Qt 原版客户端（GPL-3.0，本项目界面/行为参考） |

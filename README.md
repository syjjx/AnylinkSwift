# AnyLink Swift 版（macOS）

AnyLink Secure Client 的 SwiftUI 原生重构版。

## 设计文档

- `docs/afroute-optimization/AnyLink界面设计思路.md` — UI 设计规范（双栏布局、主题、四页面）
- `docs/afroute-optimization/AnyLink安装与首启提权设计.md` — macOS 安装与首启提权流程
- `docs/afroute-optimization/AnyLink自动重连与通配域名设计.md` — 自动重连状态机 + 通配域名轮换
- `docs/afroute-optimization/README.md` — sslcon AF_ROUTE 路由优化方案

## 构建运行

```bash
swift build
swift run
```

或在 Xcode 中直接打开 `Package.swift` 运行。

## 目录结构

```
Sources/AnyLink/
├── AnyLinkApp.swift          # 应用入口（820×600 固定窗口，注入 ConnectionManager）
├── MainWindow.swift          # NavigationSplitView 双栏布局 + 导航
├── SidebarView.swift         # 侧边栏（品牌区 / 导航 / 状态药丸）
├── StatusBarView.swift       # 底部状态条
├── Theme/AppTheme.swift      # 主题色 / 圆角 / 间距常量
├── Services/
│   ├── ConnectionModels.swift    # 连接状态机 / VPN 状态 / 事件定义
│   ├── ConnectionService.swift   # 通信层抽象协议（对应 sslcon RPC）
│   ├── StubConnectionService.swift  # 占位实现（模拟连接，不实际通信）
│   └── ConnectionManager.swift   # 状态机管理（UI 唯一数据源）
└── Views/                    # 网关 / 状态 / 设置 / 帮助 四个页面
```

## 通信层

当前为**占位实现**（`StubConnectionService`）：模拟 1.5 秒连接延迟并填充状态数据，
UI 可完整开发调试。后续接入 sslcon 时实现 `ConnectionService` 协议（WebSocket JSON-RPC）
替换 Stub 即可，UI 层无需改动。

协议对应关系（sslcon RPC → ConnectionService）：
`connect` → `connect()`、`reconnect` → `reconnect()`、`disconnect` → `disconnect()`、
推送事件 `DISCONNECT/ABORT/status` → `ConnectionEvent`。

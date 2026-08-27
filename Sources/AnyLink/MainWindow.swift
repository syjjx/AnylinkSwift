import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case gateway = "网关"
    case status = "状态"
    case settings = "设置"
    case help = "帮助"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gateway: "globe"
        case .status: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        }
    }
}

struct MainWindow: View {
    @State private var selection: SidebarItem? = .gateway

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                StatusBarView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection ?? .gateway {
        case .gateway: GatewayView()
        case .status: StatusView()
        case .settings: SettingsView()
        case .help: HelpView()
        }
    }
}

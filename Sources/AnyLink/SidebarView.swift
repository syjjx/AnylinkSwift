import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject private var manager: ConnectionManager

    var body: some View {
        VStack(spacing: 0) {
            brand
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            Spacer(minLength: 0)
            statusPill
                .padding(10)
        }
        .navigationSplitViewColumnWidth(min: 172, ideal: 172, max: 172)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("AnyLink")
                    .font(.headline)
                Text("v0.1.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(pillColor)
                .frame(width: 8, height: 8)
            Text(pillText)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.border.opacity(0.6), in: Capsule())
    }

    private var pillColor: Color {
        switch manager.state {
        case .connected: AppTheme.success
        case .connecting, .reconnecting: AppTheme.warning
        case .failed: .red
        case .idle: AppTheme.secondaryText
        }
    }

    private var pillText: String {
        switch manager.state {
        case .connected: "已连接"
        case .connecting: "连接中"
        case .reconnecting: "重连中"
        case .failed: "连接失败"
        case .idle: "未连接"
        }
    }
}

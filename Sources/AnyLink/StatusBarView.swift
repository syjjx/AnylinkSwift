import SwiftUI

struct StatusBarView: View {
    var body: some View {
        HStack {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 6, height: 6)
            Text("已连接")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            Text("AnyLink Secure Client")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(AppTheme.card)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

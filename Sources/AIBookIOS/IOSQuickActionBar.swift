import SwiftUI

/// 页底横向快捷条。每颗按钮按文字撑开，可左右滑动。
struct IOSQuickActionBar<Actions: View>: View {
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                actions()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .iosPanelChrome(edge: .top)
    }
}

/// 底栏胶囊按钮，标签完整显示不被截断。
struct IOSQuickActionButton: View {
    let titleKey: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(BookL10n.string(titleKey))
                .font(.subheadline)
                .foregroundStyle(IOSPaper.ink) // 与书页墨色一致，不用系统蓝
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false) // 按文案定宽
        }
        .buttonStyle(.bordered)
        .tint(IOSPaper.ink)
        .disabled(disabled)
    }
}
import SwiftUI

/// 换页入口。外观和右上角「更多」相同：圆圈按钮，点开是系统下拉。
struct IOSBubbleMenu: View {
    @ObservedObject var shell: IOSShellModel

    var body: some View {
        Menu {
            ForEach(IOSPage.bubbleOrder) { page in
                Button {
                    shell.select(page) // 选中后切到那一页，下拉自己会收起
                } label: {
                    pageLabel(page) // 当前页打勾，和系统菜单一致
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle") // 与右上角更多同一枚图标
                .font(.title3)
                .foregroundStyle(IOSPaper.ink)
        }
        .accessibilityLabel(BookL10n.string(shell.page.titleKey)) // 读出当前页，不和右侧更多混成一个
    }

    /// 当前页带勾，其余只写名称。
    @ViewBuilder
    private func pageLabel(_ page: IOSPage) -> some View {
        if shell.page == page {
            Label(BookL10n.string(page.titleKey), systemImage: "checkmark") // 标明现在停在这一页
        } else {
            Text(BookL10n.string(page.titleKey)) // 其余页只留名字
        }
    }
}

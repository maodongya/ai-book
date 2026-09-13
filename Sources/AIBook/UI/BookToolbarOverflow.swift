import SwiftUI

/// 顶栏水平空间不足时，按 full → compact → minimal 顺序选用首个能放下的布局。
struct BookToolbarOverflowRow<Full: View, Compact: View, Minimal: View>: View {
    @ViewBuilder var full: () -> Full // 宽窗完整按钮
    @ViewBuilder var compact: () -> Compact // 中等宽度
    @ViewBuilder var minimal: () -> Minimal // 最窄，通常只留图标

    var body: some View {
        ViewThatFits(in: .horizontal) {
            full()
            compact()
            minimal() // 谁先放得下用谁，避免手动算宽度
        }
    }
}

/// 将一组顶栏菜单项收进「更多」下拉（窄窗口溢出降级）。
struct BookToolbarOverflowMenu<Content: View>: View {
    /// 可选帮助文案；nil 时用默认「更多」。
    var help: String?
    @ObservedObject private var settings = AppSettings.shared
    @ViewBuilder var content: () -> Content // 被收进去的菜单项

    var body: some View {
        let _ = settings.localizationRevision
        BookToolbarMenuButton(title: BookL10n.string("action.more"), menuContent: content)
            .help(help ?? BookL10n.string("help.toolbarOverflowDefault"))
    }
}

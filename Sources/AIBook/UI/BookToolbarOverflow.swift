import SwiftUI

/// 顶栏水平空间不足时，按 full → compact → minimal 顺序选用首个能放下的布局。
struct BookToolbarOverflowRow<Full: View, Compact: View, Minimal: View>: View {
    @ViewBuilder var full: () -> Full
    @ViewBuilder var compact: () -> Compact
    @ViewBuilder var minimal: () -> Minimal

    var body: some View {
        ViewThatFits(in: .horizontal) {
            full()
            compact()
            minimal()
        }
    }
}

/// 将一组顶栏菜单项收进「更多」下拉（窄窗口溢出降级）。
struct BookToolbarOverflowMenu<Content: View>: View {
    var help: String = "更多顶栏操作"
    @ViewBuilder var content: () -> Content

    var body: some View {
        BookToolbarMenuButton(title: "更多", menuContent: content)
            .help(help)
    }
}

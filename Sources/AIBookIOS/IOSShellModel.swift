import Foundation

/// iOS 壳层：当前页、气泡开合、阅读时是否收起气泡。不持有正文。
@MainActor
final class IOSShellModel: ObservableObject {
    /// 当前铺满屏幕的那一页。
    @Published private(set) var page: IOSPage = .source
    /// 气泡已经开始向右拉。
    @Published private(set) var panelExtended = false
    /// 功能菜单已经向下展开。
    @Published private(set) var menuDropped = false
    /// 阅读页隐藏气泡，退出后再回来。
    @Published private(set) var readingImmersive = false
    /// 进入阅读之前停在哪一页，返回时回到那里。
    private var pageBeforeReading: IOSPage = .source

    /// 阅读中不留侧栏气泡。
    var showsBubble: Bool { !readingImmersive } // 退出阅读后底边入口再出现

    /// 菜单算打开：向右或向下任一段还在。
    var menuOpen: Bool { panelExtended || menuDropped } // 收起动画走完才算关

    /// 按下气泡：先只向右拉，菜单先别掉下来。
    func openMenu() {
        panelExtended = true // 第一段：向右拉开
        menuDropped = false // 第二段交给 revealMenu，避免两段同时发生
    }

    /// 拉开之后再把菜单向下打开。
    func revealMenu() {
        guard panelExtended else { return } // 没拉开时不单独掉菜单
        menuDropped = true // 第二段：向下展开
    }

    /// 先收菜单，面板还留着，方便视图做反向的慢动作。
    func beginClose() {
        menuDropped = false // 先向上收回条目
    }

    /// 菜单收完再把半圆收回屏幕边。
    func finishClose() {
        panelExtended = false // 向左收回气泡
    }

    /// 选中菜单里的一页，并立刻开始收起。
    func select(_ page: IOSPage) {
        if page == .reading {
            enterReading() // 阅读会额外记住来处
            return
        }
        if self.page == .reading {
            readingImmersive = false // 从阅读跳到其它页时先露出气泡
        }
        self.page = page // 单页切换，不保留 Mac 的左右同时摊开
        beginClose() // 选完就收菜单
        finishClose()
    }

    /// 从当前页进入沉浸阅读，并记住回来的地方。
    func enterReading() {
        if page != .reading {
            pageBeforeReading = page // 只在离开非阅读页时记，避免把自己记成阅读
        }
        page = .reading // 底栏和气泡都让开
        readingImmersive = true
        beginClose()
        finishClose()
    }

    /// 阅读顶边的返回。回到进入阅读前的那一页。
    func exitReading() {
        page = pageBeforeReading // 设计要求回到进入前的页，不是总回原文
        readingImmersive = false // 气泡重新可用
    }
}

import Foundation

/// iOS 壳层：当前页与阅读沉浸。底栏负责换页，不再保留半圆拉开动画状态。
@MainActor
final class IOSShellModel: ObservableObject {
    /// 当前铺满屏幕的那一页。
    @Published private(set) var page: IOSPage = .source
    /// 阅读页隐藏底栏，退出后再回来。
    @Published private(set) var readingImmersive = false
    /// 进入阅读之前停在哪一页，返回时回到那里。
    private var pageBeforeReading: IOSPage = .source

    var showsBubble: Bool { !readingImmersive }

    func select(_ page: IOSPage) {
        if page == .reading {
            enterReading()
            return
        }
        if self.page == .reading {
            readingImmersive = false
        }
        self.page = page
    }

    func enterReading() {
        if page != .reading {
            pageBeforeReading = page
        }
        page = .reading
        readingImmersive = true
    }

    func exitReading() {
        page = pageBeforeReading
        readingImmersive = false
    }
}
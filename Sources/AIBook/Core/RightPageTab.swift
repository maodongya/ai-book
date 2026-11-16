import Foundation

/// 右页就是读书助手。旧会话里的进化 tab 名读不出来，会留在助手页。
enum RightPageTab: String, CaseIterable, Identifiable {
    case readingAssistant

    /// ForEach / Identifiable 用 rawValue，和持久化键一致。
    var id: String { rawValue } // 不要另造 id，避免和落盘对不上

    /// 选项卡按钮标题，走目录。
    var localizedTitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant")
        }
    }

    /// SF Symbol 名，给 tab 图标；不是资源目录文件名。
    var icon: String {
        switch self {
        case .readingAssistant: return "book.pages"
        }
    }

    /// 页内副标题，比 tab 名多一句职责说明。
    var pageSubtitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant.subtitle")
        }
    }

    /// 顶栏下拉菜单标题。与 tab 按钮 rawValue 区分，对齐「讲解操作」这类命名。
    var toolbarMenuTitle: String? {
        switch self {
        case .readingAssistant:
            return nil
        }
    }
}

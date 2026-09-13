import Foundation

/// 右页两个选项卡：读书助手 / AI 进化。只描述 tab 身份和文案，不负责切换状态。
enum RightPageTab: String, CaseIterable, Identifiable {
    case readingAssistant
    case aiEvolution

    /// ForEach / Identifiable 用 rawValue，和持久化键一致。
    var id: String { rawValue } // 不要另造 id，避免和落盘对不上

    /// 选项卡按钮标题，走目录。
    var localizedTitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant") // 读书助手 tab 名
        case .aiEvolution:
            return BookL10n.string("tab.aiEvolution") // 进化 tab 名
        }
    }

    /// SF Symbol 名，给 tab 图标；不是资源目录文件名。
    var icon: String {
        switch self {
        case .readingAssistant: return "book.pages" // 阅读页语义
        case .aiEvolution: return "arrow.triangle.2.circlepath" // 循环/升级语义
        }
    }

    /// 页内副标题，比 tab 名多一句职责说明。
    var pageSubtitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant.subtitle") // 助手页说明，和 title 分 key
        case .aiEvolution:
            return BookL10n.string("tab.aiEvolution.subtitle") // 进化页说明
        }
    }

    /// 顶栏下拉菜单标题。与 tab 按钮 rawValue 区分，对齐「讲解操作」这类命名。
    var toolbarMenuTitle: String? {
        switch self {
        case .readingAssistant:
            return nil // 助手顶栏不走「操作」菜单，避免和讲解操作重复
        case .aiEvolution:
            return BookL10n.string("evolution.operations") // 进化顶栏「进化操作」
        }
    }
}

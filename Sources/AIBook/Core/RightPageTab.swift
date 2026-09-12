import Foundation

enum RightPageTab: String, CaseIterable, Identifiable {
    case readingAssistant
    case aiEvolution

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant")
        case .aiEvolution:
            return BookL10n.string("tab.aiEvolution")
        }
    }

    var icon: String {
        switch self {
        case .readingAssistant: return "book.pages"
        case .aiEvolution: return "arrow.triangle.2.circlepath"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .readingAssistant:
            return BookL10n.string("tab.readingAssistant.subtitle")
        case .aiEvolution:
            return BookL10n.string("tab.aiEvolution.subtitle")
        }
    }

    /// 顶栏下拉菜单标题（与 Tab 按钮 `rawValue` 区分，对齐「讲解操作」等命名）。
    var toolbarMenuTitle: String? {
        switch self {
        case .readingAssistant:
            return nil
        case .aiEvolution:
            return BookL10n.string("evolution.operations")
        }
    }
}

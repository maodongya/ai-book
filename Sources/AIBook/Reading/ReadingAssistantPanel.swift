import Foundation

/// 读书助手右页内的分栏：讲解对话 vs 翻译编辑区。
enum ReadingAssistantPanel: String, CaseIterable, Identifiable, Codable {
    case explanation
    case translation

    var id: String { rawValue }

    /// Legacy persisted values used Chinese titles before i18n.
    static func fromPersisted(_ raw: String) -> ReadingAssistantPanel? {
        switch raw {
        case explanation.rawValue, "讲解结果":
            return .explanation
        case translation.rawValue, "翻译结果":
            return .translation
        default:
            return nil
        }
    }

    var icon: String {
        switch self {
        case .explanation:
            return "sparkles.text.clipboard"
        case .translation:
            return "character.book.closed"
        }
    }

    /// 顶栏胶囊按钮短标题（右页分栏用完整 rawValue）。
    var toolbarTitle: String {
        switch self {
        case .explanation:
            return BookL10n.string("panel.explanation")
        case .translation:
            return BookL10n.string("panel.translation")
        }
    }

    var toolbarHelp: String {
        switch self {
        case .explanation:
            return BookL10n.string("panel.explanation.help")
        case .translation:
            return BookL10n.string("panel.translation.help")
        }
    }
}

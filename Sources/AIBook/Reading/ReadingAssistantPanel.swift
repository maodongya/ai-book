import Foundation

/// 读书助手右页内的分栏：讲解对话 vs 翻译编辑区。
enum ReadingAssistantPanel: String, CaseIterable, Identifiable, Codable {
    case explanation // rawValue 已入偏好，改名会丢选中栏
    case translation

    /// Identifiable，ForEach 用 rawValue。
    var id: String { rawValue } // Identifiable，ForEach 用 rawValue

    /// 旧版偏好存的是中文标题，新值是英文 rawValue。认不出回 nil，不猜。
    static func fromPersisted(_ raw: String) -> ReadingAssistantPanel? {
        switch raw {
        case explanation.rawValue, "讲解结果": // 新旧两种键都指讲解
            return .explanation
        case translation.rawValue, "翻译结果":
            return .translation
        default:
            return nil // 脏值交给调用方回默认，这里不猜
        }
    }

    /// 顶栏图标，跟工具栏文案成对。
    var icon: String {
        switch self {
        case .explanation:
            return "sparkles.text.clipboard"
        case .translation:
            return "character.book.closed"
        }
    }

    /// 顶栏胶囊短标题。完整栏名走 rawValue 的旧调用不要用这个。
    var toolbarTitle: String {
        switch self {
        case .explanation:
            return BookL10n.string("panel.explanation")
        case .translation:
            return BookL10n.string("panel.translation")
        }
    }

    /// 鼠标悬停说明，比标题多一句「这里干什么」。
    var toolbarHelp: String {
        switch self {
        case .explanation:
            return BookL10n.string("panel.explanation.help")
        case .translation:
            return BookL10n.string("panel.translation.help")
        }
    }
}

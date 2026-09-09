import Foundation

/// 读书助手右页内的分栏：讲解对话 vs 翻译编辑区。
enum ReadingAssistantPanel: String, CaseIterable, Identifiable, Codable {
    case explanation = "讲解结果"
    case translation = "翻译结果"

    var id: String { rawValue }

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
            return "讲解"
        case .translation:
            return "翻译"
        }
    }

    var toolbarHelp: String {
        switch self {
        case .explanation:
            return "切换到右页讲解结果分栏"
        case .translation:
            return "切换到右页翻译结果分栏"
        }
    }
}

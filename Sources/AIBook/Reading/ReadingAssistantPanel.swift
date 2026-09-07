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
}

import Foundation

enum RightPageTab: String, CaseIterable, Identifiable {
    case readingAssistant = "读书助手"
    case aiEvolution = "AI进化"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .readingAssistant: return "book.pages"
        case .aiEvolution: return "arrow.triangle.2.circlepath"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .readingAssistant:
            return "\(ReadingAssistant.tagline) · 讲解与翻译"
        case .aiEvolution:
            return "Cursor Agent 风格 · 思考过程与工具步骤追踪"
        }
    }
}

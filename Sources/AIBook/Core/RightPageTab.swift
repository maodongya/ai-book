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
            return "讲解对话与翻译内容分栏展示"
        case .aiEvolution:
            return "Cursor Agent 风格 · 思考过程与工具步骤追踪"
        }
    }

    /// 顶栏下拉菜单标题（与 Tab 按钮 `rawValue` 区分，对齐「讲解操作」等命名）。
    var toolbarMenuTitle: String? {
        switch self {
        case .readingAssistant:
            return nil
        case .aiEvolution:
            return "进化操作"
        }
    }
}

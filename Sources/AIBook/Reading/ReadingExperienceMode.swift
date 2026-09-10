import Foundation

/// Top-level reading experience: learning (AI-assisted) vs immersive paginated reading.
enum ReadingExperienceMode: String, CaseIterable, Identifiable {
    case learning
    case reading

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .learning: return "学习模式"
        case .reading: return "阅读模式"
        }
    }

    var enterButtonTitle: String {
        switch self {
        case .learning: return "阅读模式"
        case .reading: return "学习模式"
        }
    }
}

/// Reading spread layout: dual-page spread or single-page fullscreen.
enum ReadingLayoutMode: String, CaseIterable, Identifiable {
    case spread
    case fullscreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spread: return "双页"
        case .fullscreen: return "全屏"
        }
    }
}

/// Learning mode split layout: dual pane, left-only, or right-only.
enum LearningPaneFocus: String, CaseIterable, Identifiable {
    case both
    case leading
    case trailing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .both: return "双页"
        case .leading: return "左全屏"
        case .trailing: return "右全屏"
        }
    }
}

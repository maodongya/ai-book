import Foundation

/// Top-level reading experience: learning (AI-assisted) vs immersive paginated reading.
enum ReadingExperienceMode: String, CaseIterable, Identifiable {
    case learning
    case reading

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .learning: return BookL10n.string("mode.learning")
        case .reading: return BookL10n.string("mode.reading")
        }
    }

    var enterButtonTitle: String {
        switch self {
        case .learning: return BookL10n.string("mode.reading")
        case .reading: return BookL10n.string("mode.learning")
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
        case .spread: return BookL10n.string("layout.spread")
        case .fullscreen: return BookL10n.string("layout.fullscreen")
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
        case .both: return BookL10n.string("layout.spread")
        case .leading: return BookL10n.string("layout.leftFullscreen")
        case .trailing: return BookL10n.string("layout.rightFullscreen")
        }
    }
}

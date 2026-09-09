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

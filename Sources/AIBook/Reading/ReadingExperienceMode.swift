import Foundation

/// 顶层体验：学习（有 AI 右页）还是沉浸翻页。rawValue 已入偏好。
enum ReadingExperienceMode: String, CaseIterable, Identifiable {
    case learning // 左右分栏，右页是助手
    case reading // 沉浸阅读，助手收起

    /// Identifiable，ForEach 用 rawValue。
    var id: String { rawValue }

    /// 模式切换按钮上的当前模式名。
    var displayName: String {
        switch self {
        case .learning: return BookL10n.string("mode.learning")
        case .reading: return BookL10n.string("mode.reading")
        }
    }

    /// 按钮写的是「切到对面」，所以 learning 显示「阅读」。
    var enterButtonTitle: String {
        switch self {
        case .learning: return BookL10n.string("mode.reading")
        case .reading: return BookL10n.string("mode.learning")
        }
    }
}

/// 摊开双页还是单页全屏。rawValue 已入偏好。
enum ReadingLayoutMode: String, CaseIterable, Identifiable {
    case spread // 左右两页
    case fullscreen // 单页铺满

    /// Identifiable，ForEach 用 rawValue。
    var id: String { rawValue }

    /// 模式或页签的界面标题。
    var displayName: String {
        switch self {
        case .spread: return BookL10n.string("layout.spread")
        case .fullscreen: return BookL10n.string("layout.fullscreen")
        }
    }
}

/// 学习模式焦点：双栏、只左、只右。
enum LearningPaneFocus: String, CaseIterable, Identifiable {
    case both
    case leading // 只看原文
    case trailing // 只看助手

    /// Identifiable，ForEach 用 rawValue。
    var id: String { rawValue }

    /// 模式或页签的界面标题。
    var displayName: String {
        switch self {
        case .both: return BookL10n.string("layout.spread")
        case .leading: return BookL10n.string("layout.leftFullscreen")
        case .trailing: return BookL10n.string("layout.rightFullscreen")
        }
    }
}

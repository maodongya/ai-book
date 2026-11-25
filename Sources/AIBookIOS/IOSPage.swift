import Foundation

/// iPhone 一次只铺一页。气泡菜单的顺序跟界面设计稿：原文、翻译、讲解、设置。
enum IOSPage: String, Equatable, CaseIterable, Identifiable {
    case source
    case translation
    case explanation
    case settings
    case reading

    var id: String { rawValue } // ForEach 用稳定身份，不跟标题文案走

    /// 气泡里的四项。阅读从原文进入，不占这四个入口。
    static let bubbleOrder: [IOSPage] = [.source, .translation, .explanation, .settings]

    /// 目录里已有的短标题，避免 iOS 再写一套按钮名。
    var titleKey: String {
        switch self {
        case .source: return "context.label.source" // 原文
        case .translation: return "target.translation" // 翻译
        case .explanation: return "target.explanation" // 讲解
        case .settings: return "settings.book" // 设置入口沿用 book 设置
        case .reading: return "mode.reading" // 阅读模式
        }
    }

    /// 宽屏时右边助手只在讲解或翻译出现，设置和阅读仍独占整屏。
    var sitsBesideSource: Bool {
        self == .translation || self == .explanation // 并排只服务对照，不把设置拆成半页
    }
}

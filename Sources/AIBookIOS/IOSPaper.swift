import SwiftUI

/// iOS 纸色与墨色。在 Mac 令牌上略加深对比，阅读更轻松。
@MainActor
enum IOSPaper {
    private static weak var styleSource: BookStyleManager?

    /// 根视图挂上风格管理器后，全应用从这里取色。
    static func bind(_ manager: BookStyleManager) {
        styleSource = manager // 弱引用，避免和单例循环
    }

    private static var tokens: BookStyleTokens {
        styleSource?.tokens ?? BookStyleCatalog.baseTokens(for: .classicStudy) // 未绑定时用房书房风
    }

    private static var darkScheme: Bool {
        styleSource?.colorScheme == .dark
    }

    /// 正文纸。
    static var page: Color {
        IOSColorContrast.page(tokens.colors.pageLeft, darkScheme: darkScheme)
    }
    /// 正文墨。
    static var ink: Color {
        IOSColorContrast.ink(tokens.colors.ink, darkScheme: darkScheme)
    }
    /// 次要说明。
    static var inkMuted: Color {
        IOSColorContrast.inkMuted(tokens.colors.inkMuted, darkScheme: darkScheme)
    }
    /// 译文/对照等次级正文。
    static var inkSecondary: Color {
        IOSColorContrast.inkMuted(tokens.colors.inkSecondary, darkScheme: darkScheme)
    }
    /// 顶栏、底栏、快捷条面板底。
    static var panel: Color {
        IOSColorContrast.panel(tokens.colors.menuPanelFill, border: tokens.colors.menuPanelBorder, darkScheme: darkScheme)
    }
    /// 面板与纸面分隔线。
    static var panelBorder: Color {
        tokens.colors.menuPanelBorder.opacity(darkScheme ? 0.55 : 0.72)
    }
    /// 阅读正文字体。
    static var readingFont: Font { tokens.typography.readingFont }
    /// 标题字号，与 Mac label 接近。
    static var titleFont: Font { tokens.typography.titleFont }
    /// 风格 revision，body 里读一下可触发重绘。
    static var revision: String { styleSource?.revision ?? "-" }
}
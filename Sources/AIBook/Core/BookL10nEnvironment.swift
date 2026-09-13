import SwiftUI

/// SwiftUI Environment 里的界面语言世代号。只当 key，不存语言本身。
private struct BookLocalizationRevisionKey: EnvironmentKey {
    /// 未注入时为 0，表示还没发生过语言切换。
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// 用户改界面语言时 +1，逼依赖它的 View 重绘。不是语言代码。
    var bookLocalizationRevision: Int {
        get { self[BookLocalizationRevisionKey.self] } // 读世代号，没有写入则是 0
        set { self[BookLocalizationRevisionKey.self] = newValue } // 由设置页在切语言后写入
    }
}

extension View {
    /// 往子树灌当前 locale 和世代号，不重置整窗，避免 sheet / 滚动位置被清掉。
    func bookLocalizationEnvironment() -> some View {
        modifier(BookLocalizationEnvironmentModifier()) // 用 modifier 包一层，调用方可链式写
    }
}

/// 观察 AppSettings，把 activeLocale 和 localizationRevision 写入 Environment。
private struct BookLocalizationEnvironmentModifier: ViewModifier {
    /// 单例设置；只听语言世代，不在这里改其它偏好。
    @ObservedObject private var settings = AppSettings.shared

    /// 给内容灌 locale + 世代号，语言一切换两处一起变。
    func body(content: Content) -> some View {
        content
            .environment(\.locale, BookL10n.activeLocale) // 系统 Locale，FormatStyle / 第三方控件会跟
            .environment(\.bookLocalizationRevision, settings.localizationRevision) // 自有世代号，逼 BookL10n.string 的调用方重跑 body
    }
}

/// 在 body 里点一次世代号，语言变了 SwiftUI 就会失效重绘。不改 Environment，只当观察哨。
struct BookL10nRefreshScope<Content: View>: View {
    /// 读 AppSettings.localizationRevision，触发观察。
    @ObservedObject private var settings = AppSettings.shared
    /// 被包住的界面，语言变了会重执行。
    @ViewBuilder var content: () -> Content

    var body: some View {
        let _ = settings.localizationRevision // 故意读一下，否则只有子树自己取了 string 才会刷新
        content() // 原样展开，不加额外布局
    }
}

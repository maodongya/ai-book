import SwiftUI

/// Environment 里的风格令牌。缺省是书房风，避免预览空白。
private struct BookStyleTokensKey: EnvironmentKey {
    static let defaultValue = BookStyleCatalog.baseTokens(for: .classicStudy)
}

extension EnvironmentValues {
    /// 当前书页配色/字体令牌。
    var bookStyle: BookStyleTokens {
        get { self[BookStyleTokensKey.self] }
        set { self[BookStyleTokensKey.self] = newValue }
    }
}

extension View {
    /// 灌 manager + 令牌 + 颜色模式，根视图用。
    func bookStyleEnvironment(_ manager: BookStyleManager) -> some View {
        environmentObject(manager)
            .environment(\.bookStyle, manager.tokens)
            .preferredColorScheme(manager.colorScheme) // 跟随预设的亮/暗，不跟系统
    }

    /// 订阅风格变化，输入没变的 chrome/按钮也会重绘。
    func bookStyleRefreshing() -> some View {
        modifier(BookStyleRefreshingModifier())
    }
}

/// 把当前令牌和 revision 写进子树，切预设时整支 chrome 失效。
private struct BookStyleRefreshingModifier: ViewModifier {
    @ObservedObject private var styleManager = BookStyleManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.bookStyle, styleManager.tokens)
            .environmentObject(styleManager)
            .preferredColorScheme(styleManager.colorScheme)
            .id(styleManager.revision) // revision 变就拆身份，强制重建
    }
}

/// 内层（按钮样式、胶囊）从 manager 读令牌，切风格时自己失效。
struct BookStyleObserver<Content: View>: View {
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ViewBuilder var content: (BookStyleTokens) -> Content

    var body: some View {
        content(styleManager.tokens)
            .environment(\.bookStyle, styleManager.tokens)
    }
}

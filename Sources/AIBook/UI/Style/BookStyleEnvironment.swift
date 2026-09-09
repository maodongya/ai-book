import SwiftUI

private struct BookStyleTokensKey: EnvironmentKey {
    static let defaultValue = BookStyleCatalog.baseTokens(for: .classicStudy)
}

extension EnvironmentValues {
    var bookStyle: BookStyleTokens {
        get { self[BookStyleTokensKey.self] }
        set { self[BookStyleTokensKey.self] = newValue }
    }
}

extension View {
    func bookStyleEnvironment(_ manager: BookStyleManager) -> some View {
        environmentObject(manager)
            .environment(\.bookStyle, manager.tokens)
            .preferredColorScheme(manager.colorScheme)
    }

    /// Subscribe to style changes so chrome/buttons redraw even when their inputs are unchanged.
    func bookStyleRefreshing() -> some View {
        modifier(BookStyleRefreshingModifier())
    }
}

private struct BookStyleRefreshingModifier: ViewModifier {
    @ObservedObject private var styleManager = BookStyleManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.bookStyle, styleManager.tokens)
            .environmentObject(styleManager)
            .preferredColorScheme(styleManager.colorScheme)
            .id(styleManager.revision)
    }
}

/// Inner views (button styles, capsules) read tokens from the manager so they invalidate on switch.
struct BookStyleObserver<Content: View>: View {
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ViewBuilder var content: (BookStyleTokens) -> Content

    var body: some View {
        content(styleManager.tokens)
            .environment(\.bookStyle, styleManager.tokens)
    }
}

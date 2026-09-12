import SwiftUI

private struct BookLocalizationRevisionKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// Bumps when the user changes interface language (forces dependent views to redraw).
    var bookLocalizationRevision: Int {
        get { self[BookLocalizationRevisionKey.self] }
        set { self[BookLocalizationRevisionKey.self] = newValue }
    }
}

extension View {
    /// Propagate locale + revision without resetting the whole window (keeps sheets/state stable).
    func bookLocalizationEnvironment() -> some View {
        modifier(BookLocalizationEnvironmentModifier())
    }
}

private struct BookLocalizationEnvironmentModifier: ViewModifier {
    @ObservedObject private var settings = AppSettings.shared

    func body(content: Content) -> some View {
        content
            .environment(\.locale, BookL10n.activeLocale)
            .environment(\.bookLocalizationRevision, settings.localizationRevision)
    }
}

/// Read in `body` so SwiftUI invalidates when language changes.
struct BookL10nRefreshScope<Content: View>: View {
    @ObservedObject private var settings = AppSettings.shared
    @ViewBuilder var content: () -> Content

    var body: some View {
        let _ = settings.localizationRevision
        content()
    }
}

import Foundation

/// Loads Cursor / LLM credentials on launch so the app does not repeatedly ask for keys.
@MainActor
enum CursorAuthBootstrap {
    static func applyOnLaunch() {
        let settings = AppSettings.shared
        settings.refreshCursorAPIKeyFromSources()

        if settings.cursorAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let fileKey = CursorAPIKeyStore.loadFromLocalFiles(),
           !fileKey.isEmpty {
            settings.saveCursorAPIKey(fileKey)
        }

        if settings.cursorBridgePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let bridge = CursorService.defaultBridgeDirectory()?.path {
            settings.cursorBridgePath = bridge
        }

        if settings.explanationSource == .cursor,
           !settings.isCursorRunnable,
           settings.isLLMConfigured {
            settings.explanationSource = .llm
        }
    }
}

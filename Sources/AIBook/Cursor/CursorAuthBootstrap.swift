import Foundation

/// Loads Cursor / LLM credentials on launch so the app does not repeatedly ask for keys.
@MainActor
enum CursorAuthBootstrap {
    static func applyOnLaunch() {
        let settings = AppSettings.shared
        settings.reloadCursorAPIKey()

        if settings.cursorBridgePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let bridge = CursorService.defaultBridgeDirectory()?.path {
            settings.cursorBridgePath = bridge
        }
    }
}

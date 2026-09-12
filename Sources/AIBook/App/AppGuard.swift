import AppKit
import Foundation

/// Cross-cutting guards for explanation source validation and unsaved edits.
@MainActor
enum AppGuard {
    static func bookLLMErrorMessage(for settings: AppSettings) -> String? {
        if settings.isBookLLMConfigured { return nil }
        if settings.bookProvider == .ollama {
            return BookL10n.string("guard.ollama")
        }
        return BookL10n.format("guard.apiKey", settings.bookProvider.rawValue)
    }

    static func evolutionSourceErrorMessage(for settings: AppSettings) -> String? {
        if settings.isCursorRunnable { return nil }
        if !settings.isCursorBridgeReady {
            return settings.cursorBridgeStatusMessage
        }
        return BookL10n.string("guard.cursorEvolution")
    }

    /// Reading + evolution entry points that previously shared one backend.
    static func explanationSourceErrorMessage(for settings: AppSettings) -> String? {
        evolutionSourceErrorMessage(for: settings)
    }

    /// Self-evolution requires Cursor local bridge.
    static func evolutionErrorMessage(for settings: AppSettings) -> String? {
        evolutionSourceErrorMessage(for: settings)
    }

    static func confirmDiscardUnsavedChanges() -> Bool {
        let alert = NSAlert()
        alert.messageText = BookL10n.string("alert.discard.title")
        alert.informativeText = BookL10n.string("alert.discard.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: BookL10n.string("alert.discard.confirm"))
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmOverwriteExistingFile(at url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = BookL10n.string("alert.overwrite.title")
        alert.informativeText = BookL10n.format("alert.overwrite.message", url.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: BookL10n.string("alert.overwrite.confirm"))
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}

enum EvolutionServiceError: LocalizedError {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message
        }
    }
}

import SwiftUI

/// 顶栏功能菜单与系统菜单共用的快捷键定义与展示文案。
enum BookKeyboardShortcuts {
    // MARK: - Document

    static let newDocument = KeyboardShortcut("n")
    static let openDocument = KeyboardShortcut("o")
    static let save = KeyboardShortcut("s")
    static let saveAs = KeyboardShortcut("S", modifiers: [.command, .shift])
    static let exportSelection = KeyboardShortcut("s", modifiers: [.command, .option])

    // MARK: - Explanation

    static let explainSelection = KeyboardShortcut("r")
    static let explainFullText = KeyboardShortcut("R", modifiers: [.command, .shift])

    // MARK: - Selection

    static let selectAllLeftPage = KeyboardShortcut("a", modifiers: [.command, .control])
    static let selectAllTranslation = KeyboardShortcut("a", modifiers: [.command, .control, .shift])

    // MARK: - Speech

    static let readOriginalSelectionOrFull = KeyboardShortcut("r", modifiers: [.command, .option])
    static let readTranslationFull = KeyboardShortcut("t", modifiers: [.command, .option])

    // MARK: - Features

    static let classicSupplement = KeyboardShortcut("c", modifiers: [.command, .shift])
    static let evolution = KeyboardShortcut("e")
    static let readingMode = KeyboardShortcut("p", modifiers: [.command, .shift])

    // MARK: - Display hints

    static let newDocumentHint = "⌘N"
    static let openDocumentHint = "⌘O"
    static let saveHint = "⌘S"
    static let saveAsHint = "⌘⇧S"
    static let exportSelectionHint = "⌘⌥S"
    static let explainSelectionHint = "⌘R"
    static let explainFullTextHint = "⌘⇧R"
    static let selectAllLeftPageHint = "⌘⌃A"
    static let selectAllTranslationHint = "⌘⌃⇧A"
    static let readOriginalHint = "⌘⌥R"
    static let readTranslationFullHint = "⌘⌥T"
    static let classicSupplementHint = "⌘⇧C"
    static let evolutionHint = "⌘E"
    static let readingModeHint = "⌘⇧P"

    static var documentMenuSummary: String {
        BookL10n.format(
            "menuSummary.document",
            newDocumentHint, openDocumentHint, saveHint, saveAsHint, selectAllLeftPageHint, classicSupplementHint
        )
    }

    static var explanationMenuSummary: String {
        BookL10n.format("menuSummary.explanation", explainSelectionHint, explainFullTextHint)
    }

    static var translationMenuSummary: String {
        BookL10n.format("menuSummary.translation", readTranslationFullHint, selectAllTranslationHint)
    }

    static var speechMenuSummary: String {
        BookL10n.format("menuSummary.speech", readOriginalHint, readTranslationFullHint)
    }

    static var evolutionMenuSummary: String {
        BookL10n.format("menuSummary.evolution", evolutionHint)
    }
}

extension View {
    @ViewBuilder
    func bookMenuShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}

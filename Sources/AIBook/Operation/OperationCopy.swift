import Foundation

/// 操作助手的界面文案。业务判断仍用枚举，这里只做展示。
enum OperationCopy {
    /// 确认框和状态行用的短名称。
    static func title(for action: OperationAction) -> String {
        switch action {
        case .explainSelection: return BookL10n.string("operation.action.explainSelection")
        case .explainFullText: return BookL10n.string("operation.action.explainFullText")
        case .translateWordByWord: return BookL10n.string("operation.action.translateWordByWord")
        case .translateParagraph: return BookL10n.string("operation.action.translateParagraph")
        case .readOriginalSelection: return BookL10n.string("operation.action.readOriginalSelection")
        case .readOriginalFull: return BookL10n.string("operation.action.readOriginalFull")
        case .readTranslationSelection: return BookL10n.string("operation.action.readTranslationSelection")
        case .readTranslationFull: return BookL10n.string("operation.action.readTranslationFull")
        case .readExplanationSelection: return BookL10n.string("operation.action.readExplanationSelection")
        case .readExplanationFull: return BookL10n.string("operation.action.readExplanationFull")
        case .pauseSpeech: return BookL10n.string("operation.action.pauseSpeech")
        case .resumeSpeech: return BookL10n.string("operation.action.resumeSpeech")
        case .stopSpeech: return BookL10n.string("operation.action.stopSpeech")
        case .stopCurrentRun: return BookL10n.string("operation.action.stopCurrentRun")
        case .toggleReadingMode: return BookL10n.string("operation.action.toggleReadingMode")
        case .setPaneFocus(let focus): return BookL10n.format("operation.action.setPaneFocus", paneTitle(focus))
        case .showAssistantPanel(let panel): return BookL10n.format("operation.action.showAssistantPanel", panelTitle(panel))
        case .showRightPage(let page): return BookL10n.format("operation.action.showRightPage", pageTitle(page))
        case .showExplanationLanguage(let language): return BookL10n.format("operation.action.showExplanationLanguage", languageTitle(language))
        case .showTranslationLanguage(let language): return BookL10n.format("operation.action.showTranslationLanguage", languageTitle(language))
        case .openLibraryFile(let name): return BookL10n.format("operation.action.openLibraryFile", name)
        case .openFilePanel: return BookL10n.string("operation.action.openFilePanel")
        case .openDirectoryPanel: return BookL10n.string("operation.action.openDirectoryPanel")
        case .save: return BookL10n.string("operation.action.save")
        case .saveAs: return BookL10n.string("operation.action.saveAs")
        case .saveSelectionAs: return BookL10n.string("operation.action.saveSelectionAs")
        case .saveAsAIBook: return BookL10n.string("operation.action.saveAsAIBook")
        case .selectAllLeft: return BookL10n.string("operation.action.selectAllLeft")
        case .selectAllRight: return BookL10n.string("operation.action.selectAllRight")
        case .supplementClassic: return BookL10n.string("operation.action.supplementClassic")
        case .startEvolution: return BookL10n.string("operation.action.startEvolution")
        case .analyzeOptimizations: return BookL10n.string("operation.action.analyzeOptimizations")
        }
    }

    /// 跳过原因。
    static func reason(_ reason: OperationSkipReason) -> String {
        switch reason {
        case .noSelection: return BookL10n.string("operation.skip.noSelection")
        case .emptyBody: return BookL10n.string("operation.skip.emptyBody")
        case .languageNotEnabled: return BookL10n.string("operation.skip.languageNotEnabled")
        case .languageContentMissing: return BookL10n.string("operation.skip.languageContentMissing")
        case .libraryNoMatch: return BookL10n.string("operation.skip.libraryNoMatch")
        case .libraryMultipleMatches: return BookL10n.string("operation.skip.libraryMultipleMatches")
        case .speechNotActive: return BookL10n.string("operation.skip.speechNotActive")
        case .speechNotPaused: return BookL10n.string("operation.skip.speechNotPaused")
        case .busy: return BookL10n.string("operation.skip.busy")
        }
    }

    /// 状态行：听到的话加上这一步。
    static func stepLine(action: OperationAction, reason: OperationSkipReason?) -> String {
        if let reason {
            return BookL10n.format("operation.skipped", title(for: action), Self.reason(reason))
        }
        return BookL10n.format("operation.doing", title(for: action))
    }

    private static func paneTitle(_ focus: String) -> String {
        switch focus {
        case "leading": return BookL10n.string("layout.leftFullscreen")
        case "trailing": return BookL10n.string("layout.rightFullscreen")
        default: return BookL10n.string("layout.spread")
        }
    }

    private static func panelTitle(_ panel: String) -> String {
        panel == "translation" ? BookL10n.string("panel.translation") : BookL10n.string("panel.explanation")
    }

    private static func pageTitle(_ page: String) -> String {
        page == "evolution" ? BookL10n.string("tab.aiEvolution") : BookL10n.string("tab.readingAssistant")
    }

    private static func languageTitle(_ raw: String) -> String {
        TranslationTargetLanguage(rawValue: raw)?.localizedName ?? raw
    }
}

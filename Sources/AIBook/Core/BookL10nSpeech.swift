import Foundation

extension SpeechEngineMode {
    var localizedName: String {
        switch self {
        case .fast: return BookL10n.string("speech.engine.fast")
        case .balanced: return BookL10n.string("speech.engine.balanced")
        case .natural: return BookL10n.string("speech.engine.natural")
        case .relaxed: return BookL10n.string("speech.engine.relaxed")
        }
    }
}

extension SpeechLanguageMode {
    var localizedName: String {
        switch self {
        case .efficient: return BookL10n.string("speech.lang.efficient")
        case .balanced: return BookL10n.string("speech.engine.balanced")
        case .deep: return BookL10n.string("speech.lang.deep")
        }
    }

    var localizedDescription: String {
        switch self {
        case .efficient: return BookL10n.string("speech.desc.lang.efficient")
        case .balanced: return BookL10n.string("speech.desc.lang.balanced")
        case .deep: return BookL10n.string("speech.desc.lang.deep")
        }
    }
}

extension SpeechEngineMode {
    var localizedDescription: String {
        switch self {
        case .fast: return BookL10n.string("speech.desc.fast")
        case .balanced: return BookL10n.string("speech.desc.balanced")
        case .natural: return BookL10n.string("speech.desc.natural")
        case .relaxed: return BookL10n.string("speech.desc.relaxed")
        }
    }
}

extension SpeechSource {
    var label: String {
        switch self {
        case .originalFull: return BookL10n.string("speech.source.originalFull")
        case .originalSelection: return BookL10n.string("speech.source.originalSelection")
        case .translationFull: return BookL10n.string("speech.source.translationFull")
        case .translationSelection: return BookL10n.string("speech.source.translationSelection")
        case .explanationFull: return BookL10n.string("speech.source.explanationFull")
        case .explanationSelection: return BookL10n.string("speech.source.explanationSelection")
        case .aiReply: return BookL10n.string("speech.source.aiReply")
        }
    }
}

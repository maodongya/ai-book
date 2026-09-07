import AVFoundation
import Foundation

/// Reads explanation text with macOS system voices (`AVSpeechSynthesizer`).
@MainActor
final class ExplanationSpeechReader: NSObject {
    static let shared = ExplanationSpeechReader()

    enum PreviewError: LocalizedError {
        case voiceNotSelected
        case voiceUnavailable

        var errorDescription: String? {
            switch self {
            case .voiceNotSelected:
                return "未选择讲解声音。"
            case .voiceUnavailable:
                return "当前系统语音不可用。"
            }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var selectedVoiceCache: [SpeechEngineMode: String] = [:]

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    var isBusy: Bool {
        isSpeaking
    }

    func previewSelectedVoice() throws {
        stop()

        guard let voice = SpeechVoiceStore.resolvedVoiceForSpeaking() else {
            throw PreviewError.voiceNotSelected
        }
        guard SpeechVoiceStore.isReadyForUse(voice) else {
            throw PreviewError.voiceUnavailable
        }

        speakUnits(
            [SpeechTextSanitizer.SpeechUnit(spoken: "你好，这是 AIBook 讲解语音试听。", pauseAfter: .sentence)],
            voiceID: voice.id,
            mode: AppSettings.shared.speechEngineMode
        )
    }

    func speak(_ text: String, preferLowLatency: Bool = false) {
        stop()

        let languageMode = AppSettings.shared.speechLanguageMode
        let units = SpeechTextSanitizer.speechUnits(for: text, mode: languageMode)
        guard !units.isEmpty else { return }

        let mode = preferLowLatency ? SpeechEngineMode.fast : AppSettings.shared.speechEngineMode
        let voiceID = SpeechVoiceStore.resolvedVoiceForSpeaking()?.id ?? bestSystemChineseVoiceID()
        speakUnits(units, voiceID: voiceID, mode: mode)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func speakUnits(
        _ units: [SpeechTextSanitizer.SpeechUnit],
        voiceID: String?,
        mode: SpeechEngineMode
    ) {
        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: "zh-CN")

        for unit in units {
            guard !unit.spoken.isEmpty else { continue }
            let utterance = AVSpeechUtterance(string: unit.spoken)
            utterance.voice = voice
            utterance.rate = systemRate(for: mode)
            utterance.pitchMultiplier = systemPitch(for: mode)
            utterance.postUtteranceDelay = systemDelay(after: unit.pauseAfter, mode: mode)
            synthesizer.speak(utterance)
        }
    }

    private func systemRate(for mode: SpeechEngineMode) -> Float {
        switch mode {
        case .fast:
            return 0.50
        case .balanced:
            return 0.44
        case .natural:
            return 0.40
        case .relaxed:
            return 0.36
        }
    }

    private func systemPitch(for mode: SpeechEngineMode) -> Float {
        switch mode {
        case .fast:
            return 1.02
        case .balanced:
            return 1.01
        case .natural:
            return 1.03
        case .relaxed:
            return 1.06
        }
    }

    private func systemDelay(for mode: SpeechEngineMode) -> TimeInterval {
        switch mode {
        case .fast:
            return 0.02
        case .balanced:
            return 0.06
        case .natural:
            return 0.09
        case .relaxed:
            return 0.12
        }
    }

    private func systemDelay(after pause: SpeechTextSanitizer.SpeechPauseKind, mode: SpeechEngineMode) -> TimeInterval {
        let base = systemDelay(for: mode)
        switch pause {
        case .brief:
            return base + 0.06
        case .comma:
            return base + 0.12
        case .clause:
            return base + 0.20
        case .sentence:
            return base + 0.34
        }
    }

    private func bestSystemChineseVoiceID() -> String? {
        let mode = AppSettings.shared.speechEngineMode
        if let cached = selectedVoiceCache[mode],
           AVSpeechSynthesisVoice(identifier: cached) != nil {
            return cached
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        guard !voices.isEmpty else { return nil }

        func qualityScore(_ voice: AVSpeechSynthesisVoice) -> Int {
            switch voice.quality {
            case .default: return 1
            case .enhanced: return 2
            case .premium: return 3
            @unknown default: return 1
            }
        }

        let sorted = voices.sorted { lhs, rhs in
            let lhsScore = qualityScore(lhs)
            let rhsScore = qualityScore(rhs)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.gender != rhs.gender {
                return lhs.gender == .female
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let best = sorted.first(where: { $0.gender == .female })?.identifier ?? sorted.first?.identifier
        if let best {
            selectedVoiceCache[mode] = best
        }
        return best
    }
}

extension ExplanationSpeechReader: AVSpeechSynthesizerDelegate {}

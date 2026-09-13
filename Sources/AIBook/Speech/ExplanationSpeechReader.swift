import AVFoundation
import Foundation

/// 用系统声朗读讲解。不走第三方 TTS；停/续/试听都走这一份合成器。
@MainActor
final class ExplanationSpeechReader: NSObject {
    /// 全局一份，避免两路合成器抢扬声器。
    static let shared = ExplanationSpeechReader()

    /// 试听失败：没选声或系统声还没下完。
    enum PreviewError: LocalizedError {
        case voiceNotSelected
        case voiceUnavailable

        /// 给设置页弹窗用的中文。
        var errorDescription: String? {
            switch self {
            case .voiceNotSelected:
                return "未选择讲解声音。"
            case .voiceUnavailable:
                return "当前系统语音不可用。"
            }
        }
    }

    private let synthesizer = AVSpeechSynthesizer() // 系统合成器，delegate 回主线程收尾
    private var selectedVoiceCache: [SpeechEngineMode: String] = [:] // 按语速档缓存「最好中文女声」
    private var pendingUtteranceCount = 0 // 分段 utterance 未完成数，归零才关会话
    private(set) var isSessionActive = false // 已入队但合成器可能还没响，UI 仍当在读
    var onSpeakingStateChange: (() -> Void)? // 开/停/取消时刷新朗读按钮

    /// 单例构造：挂上 delegate 才能收到 didFinish。
    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 合成器正在出声。
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// 用户点了暂停，队列还在。
    var isPaused: Bool {
        synthesizer.isPaused
    }

    /// 会话已开或合成器忙，朗读按钮应显示停止。
    var isBusy: Bool {
        isSessionActive || synthesizer.isSpeaking || synthesizer.isPaused
    }

    /// 立刻静音但保留队列，resume 从断点续。
    func pause() {
        guard isSessionActive, !synthesizer.isPaused else { return }
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .immediate) // .word 会拖半句，讲解要立刻停
    }

    /// 只在已暂停时续读，避免空调用打乱队列。
    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
    }

    /// 试听当前选中声。没选或未就绪直接抛，不默念系统默认。
    func previewSelectedVoice() throws {
        stop() // 先清队列，避免试听叠在正文朗读上

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

    /// 朗读讲解正文。preferLowLatency 强制快档，翻页预览用。
    func speak(_ text: String, preferLowLatency: Bool = false) {
        stop()

        let languageMode = AppSettings.shared.speechLanguageMode // 中/英/跟随，决定怎么切句
        let units = SpeechTextSanitizer.speechUnits(for: text, mode: languageMode) // 去标记、按标点切停顿
        guard !units.isEmpty else { return }

        let mode = preferLowLatency ? SpeechEngineMode.fast : AppSettings.shared.speechEngineMode // 预览抢快，正文跟设置
        let voiceID = SpeechVoiceStore.resolvedVoiceForSpeaking()?.id ?? bestSystemChineseVoiceID() // 没选则拣最好中文女声
        speakUnits(units, voiceID: voiceID, mode: mode)
    }

    /// 立刻停并清会话。wasBusy 才回调，避免空停刷 UI。
    func stop() {
        pendingUtteranceCount = 0
        let wasBusy = isSessionActive || synthesizer.isSpeaking || synthesizer.isPaused
        isSessionActive = false
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        if wasBusy {
            onSpeakingStateChange?()
        }
    }

    /// 把切好的句段入队。空段直接关会话。
    private func speakUnits(
        _ units: [SpeechTextSanitizer.SpeechUnit],
        voiceID: String?,
        mode: SpeechEngineMode
    ) {
        let spokenUnits = units.filter { !$0.spoken.isEmpty }
        guard !spokenUnits.isEmpty else {
            isSessionActive = false
            return
        }

        pendingUtteranceCount = spokenUnits.count
        isSessionActive = true
        onSpeakingStateChange?()

        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: "zh-CN") // identifier 失效就退回系统中文

        for unit in spokenUnits {
            let utterance = AVSpeechUtterance(string: unit.spoken)
            utterance.voice = voice
            utterance.rate = systemRate(for: mode)
            utterance.pitchMultiplier = systemPitch(for: mode)
            utterance.postUtteranceDelay = systemDelay(after: unit.pauseAfter, mode: mode)
            synthesizer.speak(utterance) // 顺序入队，停顿靠 postUtteranceDelay
        }
    }

    /// 一段结束：计数归零且合成器闲了才关会话。
    private func handleUtteranceEnded(on synthesizer: AVSpeechSynthesizer) {
        guard pendingUtteranceCount > 0 else { return }
        pendingUtteranceCount -= 1
        guard pendingUtteranceCount == 0, !synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        isSessionActive = false
        onSpeakingStateChange?()
    }

    /// 系统语速。AVSpeech 0.5 已偏快，自然档压到 0.40。
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

    /// 音高微调，舒缓档略抬避免发闷。
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

    /// 档位基础句间停顿。
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

    /// 标点停顿叠在档位基础上，句号最长。
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

    /// 没选手动声时：按质量>女声>名字拣一条中文，并按档位缓存。
    private func bestSystemChineseVoiceID() -> String? {
        let mode = AppSettings.shared.speechEngineMode
        if let cached = selectedVoiceCache[mode],
           AVSpeechSynthesisVoice(identifier: cached) != nil {
            return cached
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        guard !voices.isEmpty else { return nil }

        /// premium > enhanced > default；未知档当 default。
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

extension ExplanationSpeechReader: AVSpeechSynthesizerDelegate {
    /// 合成器在后台线程回调，跳回主线程改计数。
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            handleUtteranceEnded(on: synthesizer)
        }
    }

    /// 取消整段：直接关会话，不再等剩余 utterance。
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard isSessionActive else { return }
            pendingUtteranceCount = 0
            isSessionActive = false
            onSpeakingStateChange?()
        }
    }
}

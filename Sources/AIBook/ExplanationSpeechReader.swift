import AVFoundation
import Foundation

/// Reads explanation text with selectable system or downloaded neural voices.
@MainActor
final class ExplanationSpeechReader: NSObject {
    static let shared = ExplanationSpeechReader()

    enum PreviewError: LocalizedError {
        case voiceNotSelected
        case voiceNotDownloaded
        case voiceUnavailable
        case sampleMissing
        case playbackFailed

        var errorDescription: String? {
            switch self {
            case .voiceNotSelected:
                return "未选择讲解声音。"
            case .voiceNotDownloaded:
                return "请先下载该在线女声模型后再试听。"
            case .voiceUnavailable:
                return "当前系统语音不可用。"
            case .sampleMissing:
                return "已下载的语音样本文件缺失，请重新下载。"
            case .playbackFailed:
                return "无法播放语音，请检查系统音量。"
            }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private(set) var isSynthesizing = false
    private var neuralAudioCache: [String: Data] = [:]
    private var neuralAudioCacheOrder: [String] = []
    private let maxCachedItems = 100
    private var warmedNeuralVoiceIDs: Set<String> = []
    private var selectedSystemVoiceCache: [SpeechEngineMode: String] = [:]
    /// 在线合成失败时回调（已自动回退系统语音前触发）。
    var onSpeakIssue: ((String) -> Void)?

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking || (audioPlayer?.isPlaying ?? false)
    }

    /// True while synthesizing or actively playing audio.
    var isBusy: Bool {
        isSynthesizing || isSpeaking
    }

    /// Instant preview: play cached sample for downloaded neural voices, system TTS otherwise.
    func previewSelectedVoice() throws {
        stop()

        guard let voice = SpeechVoiceCatalog.option(for: SpeechVoiceStore.selectedVoiceID) else {
            throw PreviewError.voiceNotSelected
        }

        if voice.isNeural {
            guard SpeechVoiceStore.isReadyForUse(voice) else {
                throw PreviewError.voiceNotDownloaded
            }
            let sampleURL = SpeechVoiceStore.sampleFileURL(for: voice.id)
            guard SpeechVoiceStore.hasValidNeuralSample(voice.id) else {
                throw PreviewError.sampleMissing
            }
            try playAudioFile(at: sampleURL)
            return
        }

        guard SpeechVoiceStore.isReadyForUse(voice) else {
            throw PreviewError.voiceUnavailable
        }
        speakWithSystemVoice(
            [SpeechTextSanitizer.SpeechUnit(spoken: "你好，这是 AIBook 讲解语音试听。", pauseAfter: .sentence)],
            voiceID: voice.id
        )
    }

    func speak(_ text: String, preferLowLatency: Bool = false) {
        stop()

        let languageMode = AppSettings.shared.speechLanguageMode
        let units = SpeechTextSanitizer.speechUnits(for: text, mode: languageMode)
        guard !units.isEmpty else { return }

        let speechMode = AppSettings.shared.speechEngineMode
        let isFastMode = speechMode == .fastLocal

        // 极速 / 显式低延时：仅用系统语音；在线模式走用户所选讲解声音。
        if isFastMode || preferLowLatency {
            if let systemVoiceID = bestSystemChineseVoiceID() {
                speakWithSystemVoice(units, voiceID: systemVoiceID)
            } else {
                speakWithSystemFallback(units)
            }
            return
        }

        guard let voice = SpeechVoiceStore.resolvedVoiceForSpeaking() else {
            speakWithSystemFallback(units)
            return
        }

        if voice.isNeural {
            isSynthesizing = true
            speakTask = Task {
                defer { self.isSynthesizing = false }
                let speakable = units.filter { !$0.spoken.isEmpty }
                guard !speakable.isEmpty else { return }

                var nextAudioTask: Task<Data, Error>?
                defer { nextAudioTask?.cancel() }
                do {
                    for (index, unit) in speakable.enumerated() {
                        guard !Task.isCancelled else { return }
                        let sentenceProsody = prosodyForSentence(unit.spoken, voiceID: voice.id, mode: speechMode)
                        let audio: Data
                        if let nextAudioTask {
                            audio = try await nextAudioTask.value
                        } else {
                            audio = try await cachedNeuralAudio(
                                for: unit.spoken,
                                voiceID: voice.id,
                                profile: neuralProfile(for: speechMode),
                                prosody: sentenceProsody
                            )
                        }
                        if index + 1 < speakable.count {
                            let upcoming = speakable[index + 1]
                            let upcomingProsody = prosodyForSentence(upcoming.spoken, voiceID: voice.id, mode: speechMode)
                            nextAudioTask = Task { [weak self] in
                                guard let self else { throw CancellationError() }
                                return try await self.cachedNeuralAudio(
                                    for: upcoming.spoken,
                                    voiceID: voice.id,
                                    profile: self.neuralProfile(for: speechMode),
                                    prosody: upcomingProsody
                                )
                            }
                        } else {
                            nextAudioTask = nil
                        }
                        guard !Task.isCancelled else { return }
                        try await playAudioDataAndWait(audio)
                        if index + 1 < speakable.count {
                            try await Task.sleep(
                                nanoseconds: SpeechTextSanitizer.pauseNanoseconds(
                                    after: unit.pauseAfter,
                                    engineMode: speechMode
                                )
                            )
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    onSpeakIssue?(message)
                    speakWithSystemFallback(units)
                }
            }
        } else {
            speakWithSystemVoice(units, voiceID: voice.id)
        }
    }

    /// Prewarms selected neural voice to reduce first-play delay.
    func prewarmCurrentVoice() async {
        let mode = AppSettings.shared.speechEngineMode
        guard mode != .fastLocal else { return }
        guard let voice = SpeechVoiceStore.resolvedVoiceForSpeaking(), voice.isNeural else { return }
        guard warmedNeuralVoiceIDs.contains(voice.id) == false else { return }

        do {
            _ = try await cachedNeuralAudio(
                for: "好的。",
                voiceID: voice.id,
                profile: neuralProfile(for: mode),
                prosody: prosodyForSentence("好的。", voiceID: voice.id, mode: mode)
            )
            warmedNeuralVoiceIDs.insert(voice.id)
        } catch {
            // Warmup is best-effort; ignore failures.
        }
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        isSynthesizing = false
        finishPlaybackWait()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func speakWithSystemVoice(_ units: [SpeechTextSanitizer.SpeechUnit], voiceID: String) {
        let voice = AVSpeechSynthesisVoice(identifier: voiceID)
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        let mode = AppSettings.shared.speechEngineMode
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

    private func speakWithSystemFallback(_ units: [SpeechTextSanitizer.SpeechUnit]) {
        let voice = AVSpeechSynthesisVoice(language: "zh-CN")
        let mode = AppSettings.shared.speechEngineMode
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

    private func cachedNeuralAudio(
        for sentence: String,
        voiceID: String,
        profile: EdgeTTSService.NeuralAudioProfile,
        prosody: EdgeTTSService.NeuralProsody
    ) async throws -> Data {
        let key = "\(voiceID)#\(profile.outputFormatCode)#\(prosody.rate)#\(prosody.pitch)#\(prosody.volume)#\(sentence)"
        if let cached = neuralAudioCache[key] {
            return cached
        }
        let audio = try await EdgeTTSService.synthesize(
            text: sentence,
            voiceID: voiceID,
            profile: profile,
            prosodyOverride: prosody
        )
        neuralAudioCache[key] = audio
        neuralAudioCacheOrder.append(key)
        if neuralAudioCacheOrder.count > maxCachedItems, let oldest = neuralAudioCacheOrder.first {
            neuralAudioCacheOrder.removeFirst()
            neuralAudioCache.removeValue(forKey: oldest)
        }
        return audio
    }

    private func prosodyForSentence(
        _ sentence: String,
        voiceID: String,
        mode: SpeechEngineMode
    ) -> EdgeTTSService.NeuralProsody {
        let cjkDensity = cjkCharacterDensity(in: sentence)
        let length = sentence.count
        let hasQuestion = sentence.contains("？") || sentence.contains("?")
        let hasExclaim = sentence.contains("！") || sentence.contains("!")

        var rate: Int
        var pitch: Int
        var volume: Int

        switch mode {
        case .fastLocal:
            return EdgeTTSService.NeuralProsody(rate: "+8%", pitch: "+0Hz", volume: "+0%")
        case .balancedNeural:
            rate = 2
            pitch = 2
            volume = 2
        case .neuralQuality:
            rate = -2
            pitch = 6
            volume = 4
        case .studioBeauty:
            rate = -4
            pitch = 8
            volume = 5
        }

        let isXiaoyi = voiceID == SpeechVoiceCatalog.defaultNeuralVoiceID
        if mode == .studioBeauty, isXiaoyi {
            if length <= 12 {
                rate = 0
                pitch = 10
            } else if length >= 45 {
                rate = -10
                pitch = 7
            } else if length >= 28 {
                rate = -8
                pitch = 8
            } else {
                rate = -6
                pitch = 9
            }

            if hasQuestion {
                pitch += 4
                volume += 1
            }
            if hasExclaim {
                volume += 2
                pitch += 2
            }
        } else if mode == .studioBeauty, length >= 40 {
            rate -= 2
        }

        if cjkDensity >= 0.85 {
            rate -= 1
            volume += 1
        }

        return EdgeTTSService.NeuralProsody(
            rate: "\(rate >= 0 ? "+" : "")\(rate)%",
            pitch: "\(pitch >= 0 ? "+" : "")\(pitch)Hz",
            volume: "\(volume >= 0 ? "+" : "")\(volume)%"
        )
    }

    /// 汉字密度越高，越适合放慢语速、略增音量，利于古文/讲解咬字。
    private func cjkCharacterDensity(in sentence: String) -> Double {
        guard !sentence.isEmpty else { return 0 }
        let cjkCount = sentence.unicodeScalars.filter { scalar in
            let value = scalar.value
            return (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
        }.count
        return Double(cjkCount) / Double(sentence.count)
    }

    private func neuralProfile(for mode: SpeechEngineMode) -> EdgeTTSService.NeuralAudioProfile {
        switch mode {
        case .fastLocal:
            return .fast
        case .balancedNeural:
            return .balanced
        case .neuralQuality:
            return .studio
        case .studioBeauty:
            return .beauty
        }
    }

    private func systemRate(for mode: SpeechEngineMode) -> Float {
        switch mode {
        case .fastLocal:
            return 0.50
        case .balancedNeural:
            return 0.44
        case .neuralQuality:
            return 0.40
        case .studioBeauty:
            return 0.36
        }
    }

    private func systemPitch(for mode: SpeechEngineMode) -> Float {
        switch mode {
        case .fastLocal:
            return 1.02
        case .balancedNeural:
            return 1.01
        case .neuralQuality:
            return 1.03
        case .studioBeauty:
            return 1.06
        }
    }

    private func systemDelay(for mode: SpeechEngineMode) -> TimeInterval {
        switch mode {
        case .fastLocal:
            return 0.02
        case .balancedNeural:
            return 0.06
        case .neuralQuality:
            return 0.09
        case .studioBeauty:
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
        if let cached = selectedSystemVoiceCache[mode],
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
        let femaleBest = sorted.first(where: { $0.gender == .female })?.identifier
        let best = femaleBest ?? sorted.first?.identifier
        if let best {
            selectedSystemVoiceCache[mode] = best
        }
        return best
    }

    private func playAudioFile(at url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
        guard audioPlayer?.play() == true else {
            audioPlayer = nil
            throw PreviewError.playbackFailed
        }
    }

    private func playAudioData(_ data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
        guard audioPlayer?.play() == true else {
            audioPlayer = nil
            throw PreviewError.playbackFailed
        }
    }

    private func playAudioDataAndWait(_ data: Data) async throws {
        try playAudioData(data)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.playbackContinuation = continuation
        }
    }

    private func finishPlaybackWait() {
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func handlePlaybackFinished(for player: AVAudioPlayer) {
        if audioPlayer === player {
            audioPlayer = nil
        }
        finishPlaybackWait()
    }
}

extension ExplanationSpeechReader: AVSpeechSynthesizerDelegate {}

extension ExplanationSpeechReader: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.handlePlaybackFinished(for: player)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.handlePlaybackFinished(for: player)
        }
    }
}

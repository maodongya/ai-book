import AVFoundation
import Foundation

/// 用系统声音朗读原文、讲解或译文。iOS 不另接第三方语音。
@MainActor
final class IOSSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var speaking = false
    @Published private(set) var paused = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self // 读完把按钮从停止改回朗读
    }

    /// 从头读这一段。空文本不发声。
    func speak(_ text: String) {
        let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate) // 新的一段替换正在读的
        let utterance = AVSpeechUtterance(string: spoken)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
        speaking = true
        paused = false
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word) // 停在词边界，方便继续
        paused = true
    }

    /// 从暂停处接着读。
    func resume() {
        synthesizer.continueSpeaking()
        paused = false
    }

    /// 立刻停下。
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speaking = false
        paused = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speaking = false // 自然读完
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speaking = false
    }
}

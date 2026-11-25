import AVFoundation
import Foundation
import Speech

/// 按住时听一句，松开后把文字交回去。不在按下之前持续监听。
@MainActor
final class IOSSpeechListener: NSObject {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var transcript = ""
    private var tapInstalled = false // 没装 tap 时不能 removeTap

    /// 已授权才开始。未决定时抛给界面去提示。
    func start() throws {
        try prepareSession() // 录音会话必须先激活
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-Hans"))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else { throw CocoaError(.featureUnsupported) }
        teardown()
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            Task { @MainActor in
                self?.transcript = text // 松开后还要读到这句
            }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    /// 停麦克风并返回目前听到的文字。
    func stop() -> String {
        request?.endAudio()
        teardown()
        return transcript
    }

    /// 录音权限和识别权限都要有。
    private func prepareSession() throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break // 麦克风已允许
        case .undetermined:
            AVAudioApplication.requestRecordPermission { _ in } // 系统框，这一次按住不等结果
            throw CocoaError(.userCancelled)
        default:
            throw CocoaError(.userCancelled)
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in } // 这一次按住不等系统框
            throw CocoaError(.userCancelled)
        default:
            throw CocoaError(.userCancelled)
        }
    }

    /// 拆掉 tap。没在跑时不能 removeTap。
    private func teardown() {
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0) // 只拆这一次装上的
            tapInstalled = false
        }
        task?.cancel()
        task = nil
        request = nil
    }
}

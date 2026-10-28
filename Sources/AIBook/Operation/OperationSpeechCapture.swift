import AVFoundation
import Foundation
import Speech

/// 听写失败。界面只区分拒绝和不可用。
enum OperationSpeechFailure: Error {
    case needsPermission // 还没点允许
    case denied // 用户拒绝
    case unavailable // 没有识别器或引擎起不来
}

/// 按住期间的听写。测试不覆盖这一层。
@MainActor
protocol OperationSpeechCapturing: AnyObject {
    func start() throws
    func stop() -> String
}

/// macOS 语音识别。系统语言支持端侧时只用端侧。
@MainActor
final class OperationSpeechCapture: OperationSpeechCapturing {
    private let engine = AVAudioEngine() // 麦克风缓冲
    private var request: SFSpeechAudioBufferRecognitionRequest? // 当前这一句
    private var task: SFSpeechRecognitionTask? // 识别任务
    private var transcript = "" // 最新一句
    private var tapInstalled = false // 没装 tap 时不能 removeTap

    /// 已授权才开始听。未决定时先弹出系统权限。
    func start() throws {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break // 可以听
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { _ in } // 系统框，这一次按住不等结果
            throw OperationSpeechFailure.needsPermission
        case .denied, .restricted:
            throw OperationSpeechFailure.denied
        @unknown default:
            throw OperationSpeechFailure.denied
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw OperationSpeechFailure.unavailable // 当前语言没有识别器
        }
        teardown() // 清掉上一次的 tap
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true // 按住过程中不断更新
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true // 有端侧就不出设备
        }
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return } // 没结果就保持上一句
            Task { @MainActor in
                self?.transcript = text // 回到主线程写
            }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { // 没有输入设备
            teardown()
            throw OperationSpeechFailure.unavailable
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer) // 音频线程，只往请求里送缓冲
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start() // 这里才会弹出麦克风权限
        } catch {
            teardown()
            throw OperationSpeechFailure.unavailable
        }
    }

    /// 停止并返回目前听到的文字。
    func stop() -> String {
        request?.endAudio() // 告诉识别器说完了
        teardown()
        return transcript
    }

    /// 停引擎并拆掉 tap。没在跑时 removeTap 会抛，所以先看 isRunning。
    private func teardown() {
        if engine.isRunning {
            engine.stop() // 先停再拆 tap
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0) // 没装过会抛异常
            tapInstalled = false
        }
        task?.cancel() // 识别任务结束
        task = nil
        request = nil
    }
}

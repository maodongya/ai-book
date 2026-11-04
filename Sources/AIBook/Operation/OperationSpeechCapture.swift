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
    func stop() async -> String // 等最后一次识别结果，不能立刻取消
    func setPartialHandler(_ handler: @escaping (String) -> Void)
}

/// macOS 语音识别。不强制端侧，避免本机没有语音包时一句都听不到。
@MainActor
final class OperationSpeechCapture: OperationSpeechCapturing {
    private let engine = AVAudioEngine() // 麦克风缓冲
    private var request: SFSpeechAudioBufferRecognitionRequest? // 当前这一句
    private var task: SFSpeechRecognitionTask? // 识别任务
    private var transcript = "" // 最新一句
    private var tapInstalled = false // 没装 tap 时不能 removeTap
    private var onPartial: ((String) -> Void)? // 按住时把半成品交给界面
    private var stopWait: CheckedContinuation<Void, Never>? // 等 isFinal，只恢复一次
    private var session = 0 // 新的一句开始后，上一句的停止不能拆掉新引擎

    /// 界面用它刷新「正在听」后面的文字。
    func setPartialHandler(_ handler: @escaping (String) -> Void) {
        onPartial = handler
    }

    /// 已授权才开始听。未决定时先弹出系统权限。
    func start() throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break // 麦克风已允许
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in } // 系统框，这一次按住不等结果
            throw OperationSpeechFailure.needsPermission
        case .denied, .restricted:
            throw OperationSpeechFailure.denied
        @unknown default:
            throw OperationSpeechFailure.denied
        }
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
        let supported = Array(SFSpeechRecognizer.supportedLocales())
        guard let locale = OperationSpeechLocale.resolve(
            uiIdentifier: BookL10n.activeLocale.identifier, // 跟界面语言，不跟 Mac 地区
            supported: supported,
            isAvailable: { SFSpeechRecognizer(locale: $0)?.isAvailable == true }
        ), let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw OperationSpeechFailure.unavailable // 界面语言、简体和本机都没有听写包
        }
        session += 1 // 先占住这一句，再拆上一句
        teardown() // 清掉上一次的 tap
        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true // 按住过程中不断更新
        self.request = request
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            Task { @MainActor in
                guard let self else { return }
                if let text {
                    self.transcript = text // 松开后还要读到这句
                    self.onPartial?(text) // 顶栏跟着变
                }
                if isFinal || error != nil {
                    self.completeStopWait() // 结果或失败都结束等待
                }
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

    /// 停止麦克风，再等识别器交出最后一句。立刻 cancel 会把文字丢掉。
    func stop() async -> String {
        let stopping = session // 等待期间如果又按住了，后面的清理要让开
        request?.endAudio() // 告诉识别器说完了
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        if task != nil {
            await withCheckedContinuation { continuation in
                stopWait = continuation
                let capture = self
                Task.detached { [weak capture] in
                    try? await Task.sleep(nanoseconds: 900_000_000) // 不等主线程空闲才开始计时
                    await capture?.completeStopWait()
                }
            }
        }
        let text = transcript
        guard stopping == session else { return text } // 新的一句已经在听
        task?.cancel()
        task = nil
        request = nil
        return text
    }

    /// 等待结束。重复调用只恢复一次。
    private func completeStopWait() {
        stopWait?.resume()
        stopWait = nil
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

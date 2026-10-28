import Foundation

/// 一次松开麦克风时界面提供的快照、状态和执行入口。
struct OperationTurn {
    var snapshot: OperationContextSnapshot
    var state: OperationRuntimeState
    var client: OperationCompletionClient
    var perform: (OperationAction) -> Void
}

/// 顶栏麦克风的听写、解析和状态。确认框打开时不再开始新的一句。
@MainActor
final class OperationAssistantModel: ObservableObject {
    @Published var isListening = false // 按钮高亮
    @Published var statusText = "" // 听到的话和当前步骤
    @Published var showsStatus = false // 空闲时收起
    @Published var showsConfirm = false // 只有进化和分析
    @Published var confirmMessage = ""

    var makeTurn: (() -> OperationTurn)? // 界面每次松开时提供

    private let speech: OperationSpeechCapturing
    private let keys = OperationHoldKeyMonitor()
    private var confirmContinuation: CheckedContinuation<Bool, Never>?
    private var working = false // 请求或执行还没结束

    init(speech: OperationSpeechCapturing? = nil) {
        self.speech = speech ?? OperationSpeechCapture() // 默认实现是主线程上的听写
        keys.onDown = { [weak self] in
            self?.beginHold()
        }
        keys.onUp = { [weak self] in
            Task { @MainActor in
                await self?.endHold()
            }
        }
    }

    /// 装上前台 Option+空格。
    func installKeys() {
        keys.start()
    }

    /// 拆掉按键监视。
    func removeKeys() {
        keys.stop()
    }

    /// 按住开始听。确认或请求进行中则忽略。
    func beginHold() {
        guard confirmContinuation == nil, !working, !isListening else { return }
        do {
            try speech.start()
            isListening = true
            showsStatus = true
            statusText = BookL10n.string("operation.listening")
        } catch OperationSpeechFailure.needsPermission {
            show(BookL10n.string("operation.speech.needsPermission"))
        } catch OperationSpeechFailure.denied {
            show(BookL10n.string("operation.speech.denied"))
        } catch {
            show(BookL10n.string("operation.speech.unavailable"))
        }
    }

    /// 松开后识别、解析、执行。
    func endHold() async {
        guard isListening else { return }
        isListening = false
        let heard = speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty else {
            show(BookL10n.string("operation.notHeard")) // 没听清不请求模型
            return
        }
        guard let makeTurn else {
            show(BookL10n.format("operation.heard", heard))
            return
        }
        let turn = makeTurn()
        working = true
        statusText = BookL10n.format("operation.heard", heard)
        showsStatus = true
        defer { working = false }
        let plan: OperationPlan
        do {
            plan = try await OperationPlanner.plan(utterance: heard, snapshot: turn.snapshot, client: turn.client)
        } catch {
            statusText = error.localizedDescription // 网络或密钥错误，不执行
            return
        }
        guard !plan.actions.isEmpty else {
            statusText = BookL10n.format("operation.noMatch", heard)
            return
        }
        var lines = [BookL10n.format("operation.heard", heard)]
        let log = await OperationExecutor.execute(plan: plan, state: turn.state, confirm: { action in
            await self.askConfirm(heard: heard, action: action)
        }, perform: { action in
            lines.append(OperationCopy.stepLine(action: action, reason: nil))
            self.statusText = lines.joined(separator: " · ")
            turn.perform(action)
        })
        for skip in log.skipped {
            lines.append(OperationCopy.stepLine(action: skip.action, reason: skip.reason))
        }
        statusText = lines.joined(separator: " · ")
    }

    /// 用户点确认或取消。重复调用只生效一次。
    func resolveConfirm(_ accepted: Bool) {
        guard let continuation = confirmContinuation else { return }
        confirmContinuation = nil
        showsConfirm = false
        continuation.resume(returning: accepted)
    }

    /// 关掉状态，不影响已经执行的操作。
    func dismissStatus() {
        guard !isListening, !working, confirmContinuation == nil else { return }
        showsStatus = false
        statusText = ""
    }

    /// 弹出确认并等待。
    private func askConfirm(heard: String, action: OperationAction) async -> Bool {
        confirmMessage = BookL10n.format("operation.confirm.message", heard, OperationCopy.title(for: action))
        showsConfirm = true
        return await withCheckedContinuation { continuation in
            confirmContinuation = continuation
        }
    }

    /// 失败或空结果都留在同一条状态上。
    private func show(_ text: String) {
        statusText = text
        showsStatus = true
        isListening = false
    }
}

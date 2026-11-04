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
    @Published var isBusy = false // 识别或理解还没结束，关闭按钮这时是停止

    var makeTurn: (() -> OperationTurn)? // 界面每次松开时提供

    private let speech: OperationSpeechCapturing
    private let keys = OperationHoldKeyMonitor()
    private var confirmContinuation: CheckedContinuation<Bool, Never>?
    private var working = false // 请求或执行还没结束
    private var utteranceTask: Task<Void, Never>? // 松开后的这一轮，停止时取消
    private var generation = 0 // 停止后，旧一轮不能再改状态

    init(speech: OperationSpeechCapturing? = nil) {
        self.speech = speech ?? OperationSpeechCapture() // 默认实现是主线程上的听写
        self.speech.setPartialHandler { [weak self] text in
            guard let self, self.isListening else { return } // 松开之后不再改「正在听」
            self.statusText = BookL10n.format("operation.listeningText", text)
        }
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

    /// 按住开始听。理解还没结束时，这一下先停掉上一轮。
    func beginHold() {
        if isListening { // 松开没送到时，下一次按下先把上一句执行掉
            Task { await endHold() }
            return
        }
        guard confirmContinuation == nil else { return }
        if working || utteranceTask != nil { // 卡住的理解不能把麦克风一直占住
            cancelUtterance()
        }
        isListening = true // 先亮起来，不等引擎
        showsStatus = true
        statusText = BookL10n.string("operation.listening")
        do {
            try speech.start()
        } catch OperationSpeechFailure.needsPermission {
            show(BookL10n.string("operation.speech.needsPermission"))
        } catch OperationSpeechFailure.denied {
            show(BookL10n.string("operation.speech.denied"))
        } catch {
            show(BookL10n.string("operation.speech.unavailable"))
        }
    }

    /// 松开后识别、解析、执行。这一轮单独放进可取消的任务。
    func endHold() async {
        guard isListening else { return }
        isListening = false
        isBusy = true
        showsStatus = true
        statusText = BookL10n.string("operation.recognizing") // 松开后立刻离开「正在听」
        generation += 1
        let token = generation
        utteranceTask?.cancel()
        let task = Task { @MainActor in
            await self.finishHold(token: token)
        }
        utteranceTask = task
        await task.value
        if utteranceTask == task {
            utteranceTask = nil
        }
    }

    /// 停掉正在听或正在理解的这一轮，并放开麦克风。
    func cancelUtterance() {
        generation += 1 // 进行中的那一轮醒来后不能再改状态
        utteranceTask?.cancel()
        utteranceTask = nil
        working = false
        isBusy = false
        let needsEngineStop = isListening
        isListening = false
        if confirmContinuation != nil {
            resolveConfirm(false) // 确认框还开着就当作取消
        }
        statusText = BookL10n.string("operation.stopped")
        showsStatus = true
        if needsEngineStop {
            Task { _ = await self.speech.stop() } // 还按着就松开麦克风
        }
    }

    /// 识别、请求模型、执行。token 过期说明用户已经停止。
    private func finishHold(token: Int) async {
        defer {
            if generation == token {
                working = false
                isBusy = false
            }
        }
        let heard = await speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        guard generation == token else { return }
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
        statusText = BookL10n.format("operation.understanding", heard) // 请求模型时也能看见
        showsStatus = true
        let plan: OperationPlan
        do {
            plan = try await OperationPlanner.plan(utterance: heard, snapshot: turn.snapshot, client: turn.client)
        } catch is CancellationError {
            return // 状态已经写成已停止
        } catch {
            guard generation == token else { return }
            statusText = error.localizedDescription // 网络或密钥错误，不执行
            return
        }
        guard generation == token else { return }
        guard !plan.actions.isEmpty else {
            statusText = BookL10n.format("operation.noMatch", heard)
            return
        }
        var lines = [BookL10n.format("operation.heard", heard)]
        let log = await OperationExecutor.execute(plan: plan, state: turn.state, confirm: { action in
            guard self.generation == token else { return false }
            return await self.askConfirm(heard: heard, action: action)
        }, perform: { action in
            guard self.generation == token else { return }
            lines.append(OperationCopy.stepLine(action: action, reason: nil))
            self.statusText = lines.joined(separator: " · ")
            turn.perform(action)
        })
        guard generation == token else { return }
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

    /// 理解中是停止这一轮；空闲时只收起状态。
    func dismissStatus() {
        if isListening || working || isBusy || utteranceTask != nil || confirmContinuation != nil {
            cancelUtterance()
            return
        }
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

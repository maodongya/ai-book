import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// AI 进化会话：优化队列、分析/进化请求与 token 预算。
final class ReadingEvolutionSession: ObservableObject {
    unowned var host: ReadingViewModel!  // VM 注入


    /// 进化会话第一条欢迎。
    static var defaultEvolutionWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: EvolutionAssistant.welcomeMessage)  // 当前语言欢迎
    }

    @Published var evolutionChatInput = "" {  // 进化输入
        didSet { host.persistChatSession() }  // 输入也落盘
    }
    @Published var optimizationQueue = OptimizationQueue.empty  // 待办/完成/跳过
    @Published var evolutionRunKind: ReadingEvolutionRunKind = .none  // 分析/进化/追问
    @Published var evolutionLastRequestId: String?  // 上次 Cursor 请求号
    @Published var executingEvolutionCommandNumber: Int?  // 正在跑的命令号，停了好回滚
    @Published var isEvolutionRebuilding = false  // 打包安装中
    @Published var evolutionRebuildStatus = ""  // 升级文案
    @Published var evolutionSessionTokensConsumed = 0  // 本会话累加
    @Published var evolutionAgentContextTokens = 0  // 桥回报的现场上下文
    @Published var showsExecutionTrace = false  // 工具步骤区
    private let optimizationQueueStore = OptimizationQueueStore(  // 队列 JSON
        fileURL: OptimizationQueueStore.defaultFileURL  // 固定路径
    )
    private var autoEvolutionTask: Task<Void, Never>?  // 启动后延迟串下一件
    private var didScheduleAutoEvolution = false  // 只排一次，避免 onAppear 重入
    var evolutionPromptMessages: [ChatMessage] = []  // 进化源历史

    /// 队列状态短文案，顶栏用。
    var evolutionStatusLabel: String? { SelfEvolution.statusLabel(from: optimizationQueue) }
    /// 按编号排的优化项，侧栏列表。
    var evolutionItems: [OptimizationItem] { optimizationQueue.items.sorted { $0.number < $1.number } }
    /// 还有未做完的优化项。
    var hasPendingOptimization: Bool { optimizationQueue.nextPending() != nil }

    /// 进化对话里已有用户或助手发言。
    var hasEvolutionConversation: Bool {
        evolutionPromptMessages.contains { !isEvolutionWelcomeMessage($0) }  // 有非欢迎才算有对话
    }



    /// 从 JSON/笔记迁入内存。
    func loadOptimizationQueue() {
        do {
            optimizationQueue = try optimizationQueueStore.migrateFromReadmeNotesIfNeeded(  // JSON 没有就从笔记迁
                ReadmeNotesStore.shared.loadInitialContent()  // 编号行
            )
        } catch {
            host.errorMessage = BookL10n.format("vm.error.loadQueue", error.localizedDescription)  // 坏文件
            optimizationQueue = .empty  // 失败空队列，不崩
        }
    }


    /// 队列落盘。
    func persistOptimizationQueue() {
        do {
            try optimizationQueueStore.save(optimizationQueue) // 调用可能失败的方法
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveQueue", error.localizedDescription)  // 写失败
        }
    }


    /// 当前模型窗 + 已用。
    func evolutionTokenBudget(additionalPrompt: String?) -> ModelTokenBudget {
        let settings = AppSettings.shared  // 模型窗
        return EvolutionTokenCalculator.budget(  // 会话+现场+流
            sessionConsumedTokens: evolutionSessionTokensConsumed,  // 已花
            agentLiveContextTokens: evolutionAgentContextTokens,  // 桥回报
            messages: evolutionPromptMessages,  // 历史估
            input: evolutionChatInput,  // 输入框
            streamingThinking: host.streamingThinking,  // 正在出的思考
            streamingResponse: host.streamingResponse,  // 正在出的正文
            toolSteps: host.streamingToolSteps,  // 工具结果也占
            additionalPrompt: additionalPrompt,  // 即将发出的
            usesCursor: true,  // 进化只算 Cursor 窗
            cursorModel: settings.resolvedCursorModel,  // 当前 Cursor 模型
            llmModel: settings.model,  // 对照用
            llmProvider: settings.provider  // 对照用
        )
    }


    /// 进化强制走 Cursor 桥。
    func ensureEvolutionUsesCursor() {
        let settings = AppSettings.shared  // 模型窗
        settings.reloadCursorAPIKey()  // 可能刚填了 Key
        if settings.explanationSource != .cursor {  // 讲解源被改走 LLM
            settings.explanationSource = .cursor  // 进化强制拉回来
        }
    }


    /// 超限拦下并提示。
    private func guardEvolutionTokenLimit(for prompt: String, action: String) -> Bool {
        let budget = evolutionTokenBudget(additionalPrompt: prompt)  // 含即将发出的
        if let message = budget.blockMessage(for: action) {  // 超限文案带动作名
            host.errorMessage = message  // 顶栏
            return false  // 调用方不发
        }
        return true  // 异常当干净，不挡入队
    }


    /// 累加本轮 usage。
    func recordEvolutionTokenUsage(_ usage: LLMTokenUsage) {
        guard usage.totalTokens > 0 else { return }  // 空用量不累
        evolutionSessionTokensConsumed += usage.totalTokens  // 只加 total
    }


    /// 刷新顶栏上下文估计。
    private func updateEvolutionAgentContextTokens(_ tokens: Int) {
        evolutionAgentContextTokens = max(0, tokens)  // 负值当 0
    }


    /// 桥不回头条时用字符估。
    func recordEvolutionCursorEstimate(
        prompt: String,
        history: [ChatMessage],
        reply: String,
        thinking: String?
    ) {
        var promptTokens = TokenEstimator.estimate(prompt)  // 当前句
        for message in history {  // 历史正文+思考
            promptTokens += TokenEstimator.estimate(message.content)  // 正文
            if let messageThinking = message.thinking {  // 思考也占
                promptTokens += TokenEstimator.estimate(messageThinking)  // 估
            }
        }
        let completionTokens = TokenEstimator.estimate(reply)  // 回复
            + TokenEstimator.estimate(thinking ?? "")  // 加思考
        recordEvolutionTokenUsage(  // 走同一累加
            LLMTokenUsage(promptTokens: promptTokens, completionTokens: completionTokens)  // total 由结构算
        )
    }


    /// 停任务、清时间线。
    func clearEvolutionExecutionState() {
        executingEvolutionCommandNumber = nil  // 不再指向那条
        evolutionRunKind = .none  // 收尾后不是分析也不是进化
    }


    /// 失败/取消时 running 改回 pending。
    func revertRunningOptimization(number: Int) {
        guard let item = optimizationQueue.items.first(where: { $0.number == number }) else { return }  // 号没了
        if optimizationQueue.revertRunningToPending(id: item.id) {  // 只有 running 才回
            persistOptimizationQueue()  // 落盘
        }
    }

    /// 界面语言变了，刷新进化欢迎语。(keeps session data).

    func saveEvolutionCommands() {
        guard !optimizationQueue.items.isEmpty else {  // 空不存
            host.errorMessage = BookL10n.string("vm.error.queueEmptySave")  // 提示
            return  // 草稿不入队
        }
        let formatted = NumberedNoteFormatter.format(optimizationQueue)  // N、正文
        exportEvolutionCommands(  // 另存面板
            formatted,
            panelTitle: BookL10n.string("vm.panel.saveEvolutionCommands"),
            panelMessage: BookL10n.string("vm.panel.saveEvolutionCommandsMsg"),
            successPrefix: BookL10n.string("vm.saved.evolutionCommands")
        )
    }

    /// 从本地编号命令文本文件加载优化队列。

    func openEvolutionCommands() {
        guard !host.isRunning else { return }  // 跑着不覆盖队列

        let panel = NSOpenPanel()  // 打开命令文件
        panel.title = BookL10n.string("vm.panel.openEvolutionCommands")  // 标题
        panel.message = BookL10n.string("vm.panel.openEvolutionCommandsMsg")  // 说明格式
        panel.allowedContentTypes = [.plainText]  // 文本
        panel.allowsMultipleSelection = false  // 一份
        panel.canChooseDirectories = false  // 不要目录
        panel.directoryURL = DocumentExporter.lastDirectoryURL  // 上次

        guard panel.runModal() == .OK, let url = panel.url else { return }  // 取消

        do {
            let text = try String(contentsOf: url, encoding: .utf8)  // utf8
            let imported = OptimizationQueue.importFromNotes(text)  // 编号行
            guard !imported.items.isEmpty else {  // 不像命令
                host.errorMessage = BookL10n.string("vm.error.noValidCommands")  // 提示
                return  // 草稿不入队
            }
            if optimizationQueue.items.contains(where: { $0.status == .running }) {  // 有 running 不覆盖
                host.errorMessage = BookL10n.string("vm.error.evolutionRunningOpen")  // 先停
                return  // 草稿不入队
            }
            if !optimizationQueue.items.isEmpty,  // 已有队列先问
               !host.document.confirmReplaceOptimizationQueue() {  // 取消则停
                return  // 草稿不入队
            }

            optimizationQueue = imported  // 整表换
            persistOptimizationQueue()  // 落盘
            host.document.syncLeftPageWithEvolutionCommands(from: url, formatted: NumberedNoteFormatter.format(imported))  // 左页跟队列
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 记住
            host.errorMessage = nil  // 清错
            let count = imported.items.count  // 提示用
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.evolutionCommands", count, url.lastPathComponent))  // 打开条数
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openEvolutionCommands", error.localizedDescription)  // 读失败
        }
    }

    /// 队列非空才能导出命令。
    var canSaveEvolutionCommands: Bool {
        !optimizationQueue.items.isEmpty  // 空不能存
    }

    /// 没在跑才能打开命令文件。
    var canOpenEvolutionCommands: Bool {
        !host.isRunning  // 跑着不能开
    }


    /// 队列导出编号笔记。
    private func exportEvolutionCommands(
        _ content: String,
        panelTitle: String,
        panelMessage: String,
        successPrefix: String
    ) {
        guard !content.isEmpty else { return }  // 空不开面板

        let directory = DocumentExporter.defaultDirectory(currentFileURL: host.document.currentFileURL)  // 同目录
        guard let destination = DocumentExporter.runSavePanel(  // 取消 nil
            title: panelTitle,
            message: panelMessage,
            suggestedName: DocumentExporter.evolutionCommandsSuggestedName,
            directory: directory
        ) else { return }

        if FileManager.default.fileExists(atPath: destination.path),  // 覆盖问
           !AppGuard.confirmOverwriteExistingFile(at: destination) {  // 取消
            return  // 草稿不入队
        }

        do {
            try DocumentExporter.write(content, to: destination) // 调用可能失败的方法
            host.document.syncLeftPageWithEvolutionCommands(from: destination, formatted: content)  // 左页切到这份
            host.errorMessage = nil  // 清错
            let count = optimizationQueue.items.count  // 条数
            host.document.showTransientSaveMessage(BookL10n.format("vm.saved.itemsTo", successPrefix, count, destination.lastPathComponent))  // 已存
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveEvolutionCommands", error.localizedDescription)  // 写失败
        }
    }


    /// 欢迎语不进 API 历史。
    private func isEvolutionWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && message.content == EvolutionAssistant.welcomeMessage  // 比正文，语言变了也能认
    }


    /// 按命令号开一轮改文件。
    func startEvolution() {
        host.selectRightPageTab(.aiEvolution)  // 切进化
        ensureEvolutionWelcome()  // 空则欢迎
        ensureEvolutionUsesCursor()  // 强制 Cursor

        if let running = optimizationQueue.items.first(where: { $0.status == .running }) {  // 残留 running 先回 pending
            _ = optimizationQueue.revertRunningToPending(id: running.id)  // 避免卡死
            persistOptimizationQueue()  // 落盘
        }

        guard let pending = optimizationQueue.nextPending() else {  // 没有待办
            host.errorMessage = BookL10n.string("vm.needAnalyzeFirst")  // 先分析
            AutoEvolutionCoordinator.clearChain()  // 停链
            return  // 草稿不入队
        }

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {  // Key/源码
            host.errorMessage = configError  // fail-closed
            return  // 草稿不入队
        }

        guard SelfEvolution.sourceProjectReady else {  // 找不到仓库
            host.errorMessage = BookL10n.format("vm.error.sourceProjectMissing", SelfEvolution.sourceProjectPath())  // 带路径
            return  // 草稿不入队
        }

        let projectPath = SelfEvolution.sourceProjectPath()  // 给 planner
        let prompt = EvolutionPlanner.buildEvolutionPrompt(  // 当前条+队列+路径
            queue: optimizationQueue,  // 已有条不重复
            pending: pending,  // 这一条
            projectPath: projectPath  // 源码根
        )
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.evolve")) else { return }  // 超限不发

        guard optimizationQueue.markRunning(id: pending.id) else { return }  // 标 running 失败则停
        persistOptimizationQueue()  // 落盘
        AutoEvolutionCoordinator.markChainActive()  // 装完还能串下一件

        host.sendMessage(  // 编排器走 Cursor
            prompt,
            displayText: BookL10n.format("vm.display.evolutionItem", pending.number),  // 气泡「第 N 条」
            isEvolution: true,  // 旧布尔
            evolutionCommandNumber: pending.number,  // 失败回滚
            triggerEvolutionRebuild: true,  // 改完打包
            evolutionRunKind: .evolution  // 新 Agent
        )
    }


    /// 只出建议，不改仓库。
    func analyzeOptimizations() {
        host.selectRightPageTab(.aiEvolution)  // 切进化
        ensureEvolutionWelcome()  // 空则欢迎
        ensureEvolutionUsesCursor()  // 强制 Cursor
        guard !host.isRunning, !isEvolutionRebuilding else { return }  // 升级中也不分析

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {  // Key/源码
            host.errorMessage = configError  // fail-closed
            return  // 草稿不入队
        }
        guard SelfEvolution.sourceProjectReady else {  // 找不到仓库
            host.errorMessage = BookL10n.format("vm.error.sourceProjectMissing", SelfEvolution.sourceProjectPath())  // 带路径
            return  // 草稿不入队
        }

        let direction = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)  // 输入当分析方向
        if !direction.isEmpty {  // 用掉就清空
            evolutionChatInput = ""  // 先清再发，防重
        }

        let prompt = EvolutionAnalyzer.buildAnalysisPrompt(  // 只读建议
            queue: optimizationQueue,  // 已有条不重复
            projectPath: SelfEvolution.sourceProjectPath(),  // 源码
            direction: direction.isEmpty ? nil : direction  // 空则自由分析
        )
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.analyze")) else { return }  // 超限

        evolutionRunKind = .analysis  // fetch 用分析 prompt
        host.sendMessage(  // 编排器走 Cursor
            prompt,
            displayText: direction.isEmpty ? BookL10n.string("vm.display.analyze") : BookL10n.format("vm.display.analyzeWith", direction),  // 气泡
            isEvolution: true,  // 旧布尔
            evolutionCommandNumber: nil,  // 分析不占命令号
            triggerEvolutionRebuild: false,  // 追问不自动装
            evolutionRunKind: .analysis  // 一次一 Agent，跑完关
        )
    }


    /// 跳过当前 pending。
    func skipOptimization(id: UUID) {
        guard !host.isRunning else { return }  // 跑着不覆盖队列
        if optimizationQueue.skip(id: id) {  // pending 才能跳
            persistOptimizationQueue()  // 落盘
        }
    }


    /// 已完成改回 pending。
    func restoreOptimization(id: UUID) {
        guard !host.isRunning else { return }  // 跑着不覆盖队列
        if optimizationQueue.restore(id: id) {  // completed/skipped 回 pending
            persistOptimizationQueue()  // 落盘
        }
    }


    /// 从队列删掉。
    func deleteOptimization(id: UUID) {
        guard !host.isRunning else { return }  // 跑着不覆盖队列
        optimizationQueue.remove(id: id)  // 直接删
        persistOptimizationQueue()  // 落盘
    }


    /// 置顶，nextPending 优先。
    func pinOptimization(id: UUID) {
        guard !host.isRunning else { return }  // 跑着不覆盖队列
        optimizationQueue.pin(id: id)  // nextPending 先拿它
        persistOptimizationQueue()  // 落盘
    }


    /// 手加一条。
    func addUserOptimization(title: String) {
        guard !host.isRunning else { return }  // 跑着不覆盖队列
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)  // 空不建
        guard !trimmed.isEmpty else { return }  // 空白标题拒
        _ = optimizationQueue.addUserItem(title: trimmed)  // 编号自增
        persistOptimizationQueue()  // 落盘
    }


    /// 进化输入条发送。空串直接回。
    func sendEvolutionChatInput() {
        let text = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)  // 空回
        guard !text.isEmpty else { return }  // 不发

        ensureEvolutionUsesCursor()  // 强制 Cursor
        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {  // Key/源码
            host.errorMessage = configError  // fail-closed
            return  // 草稿不入队
        }

        evolutionChatInput = ""  // 先清再发，防重
        let prompt = buildEvolutionChatPrompt(for: text)  // 带队列摘要
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.followUp")) else { return }  // 超限
        host.sendMessage(  // 编排器走 Cursor
            prompt,
            displayText: text,  // 气泡用原文
            isEvolution: true,  // 旧布尔
            triggerEvolutionRebuild: false,  // 追问不自动装
            evolutionRunKind: .followUp  // 复用 Agent
        )
    }


    /// 自动进化开着且还有 pending 才串下一件。
    func scheduleAutoEvolutionIfNeeded() {
        guard !didScheduleAutoEvolution else { return }  // onAppear 只排一次
        didScheduleAutoEvolution = true  // 即使没启动也记下

        let settings = AppSettings.shared  // 模型窗
        let pending = optimizationQueue.items.filter { $0.status == .pending }.count  // 待办数
        guard AutoEvolutionCoordinator.shouldAutoStart(  // 总开关+链条+待办
            autoEvolutionEnabled: settings.autoEvolutionEnabled,  // 设置
            isChainActive: AutoEvolutionCoordinator.isChainActive,  // 上一轮装完留下的
            pendingCount: pending  // 没有待办不启动
        ) else {
            if pending == 0 {  // 链条也清
                AutoEvolutionCoordinator.clearChain()  // 停链
            }
            return  // 草稿不入队
        }

        autoEvolutionTask?.cancel()  // 旧的作废
        autoEvolutionTask = Task { @MainActor [weak self] in  // 2.5 秒后，等 UI 起来
            try? await Task.sleep(nanoseconds: 2_500_000_000)  // 2.5s
            guard !Task.isCancelled else { return }  // 取消
            guard let self, !self.host.isRunning else { return }  // 已经在跑就让它自己串
            guard self.optimizationQueue.nextPending() != nil else {  // 待办没了
                AutoEvolutionCoordinator.clearChain()  // 停链
                return  // 草稿不入队
            }
            if AppGuard.evolutionSourceErrorMessage(for: settings) != nil { return }  // 没配不自动弹一堆错
            guard self.host.canRunEvolution else {  // token 超了
                AutoEvolutionCoordinator.clearChain()  // 停链
                self.host.errorMessage = self.host.evolutionTokenBudget.blockMessage(for: BookL10n.string("vm.action.autoEvolve"))  // 提示为啥停
                return  // 草稿不入队
            }
            self.startEvolution()  // 串下一件
        }
    }


    /// 进化完打包安装。
    func handleEvolutionRebuild(projectPath: String, continueChain: Bool = true) async {
        await MainActor.run { // 等待异步完成
            isEvolutionRebuilding = true  // 升级中禁分析
            evolutionRebuildStatus = BookL10n.string("vm.rebuild.running")  // 顶栏
        }

        let result = await AppRelauncher.rebuildAndRelaunch(  // 打包并拉起新进程
            projectPath: projectPath,  // 源码根
            continueChain: continueChain  // 成功后是否继续自动
        )

        await MainActor.run { // 等待异步完成
            isEvolutionRebuilding = false  // 失败才回到这里；成功会杀进程
            evolutionRebuildStatus = ""  // 清
        }

        guard !result.succeeded else { return }  // 成功不会走到，防守

        await MainActor.run { // 等待异步完成
            let message = result.message ?? BookL10n.string("vm.rebuild.failedDefault")  // 脚本输出
            host.errorMessage = message  // 顶栏
            host.appendDisplayedMessage(  // 告诉用户先提交
                ChatMessage(  // 脏工作区
                    role: .assistant,
                    content: BookL10n.format("vm.rebuild.failedStop", message)
                ),
                to: .evolution  // 进化气泡
            )
        }
    }

    /// 一轮助手结果：正文、思考、可选降级提示。
    private struct AssistantReplyOutcome {
        let text: String  // 未使用的本地结构，留给对称
        let thinking: String?  // 未使用
        let fallbackNotice: String?  // 未使用
    }


    /// 拼进化提示，带当前命令。
    private func buildEvolutionChatPrompt(for question: String) -> String {
        let queueSummary = optimizationQueue.items  // 给模型看进度
            .sorted { $0.number < $1.number }  // 编号序
            .map { item in  // 一行一条
                let mark: String  // 状态符
                switch item.status {  // 写全，禁止 default
                case .completed: mark = "✓"  // 完成
                case .running: mark = "▶"  // 进行
                case .skipped: mark = "—"  // 跳过
                case .pending: mark = "○"  // 待办
                }
                return "\(mark) #\(item.number) \(item.title)"  // 短行
            }
            .joined(separator: "\n")  // 一项一行

        let definition = SelfEvolution.productDefinition  // 产品约束
            .map { "- \($0)" }  // 列表
            .joined(separator: "\n")  // 一项一行

        // 定义+队列+路径+问题
        let body = """
        【AIBook 产品定义】
        \(definition)

        【优化队列摘要】
        \(queueSummary.isEmpty ? "（队列为空）" : queueSummary)

        【源码目录】
        \(SelfEvolution.sourceProjectPath())

        【用户问题】
        \(question)
        """

        return body  // 整段当 user
    }


    /// 空对话先插欢迎语。
    func ensureEvolutionWelcome() {
        if evolutionPromptMessages.isEmpty {  // 空才插
            evolutionPromptMessages = [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]  // 欢迎
        }
    }


    /// 按回复和命令号更新队列状态。
    func applyEvolutionQueueUpdate(reply: String, commandNumber: Int?) {
        guard let number = commandNumber,  // 抠不到号就不改队列
              let item = optimizationQueue.items.first(where: { $0.number == number })  // 对上那条
        else { return }  // 没有对应项

        let summary = EvolutionPlanner.parseCompletionSummary(from: reply, number: number)  // 从回复抽摘要
            ?? BookL10n.format("vm.evolution.itemExecuted", number)  // 抽不出用默认

        if item.status == .running {  // 正常路径
            _ = optimizationQueue.markCompleted(id: item.id, summary: summary)  // running → done
        } else if let index = optimizationQueue.items.firstIndex(where: { $0.id == item.id }) {  // 不是 running 也写成完成（重放）
            optimizationQueue.items[index].status = .completed  // 强制完成
            optimizationQueue.items[index].completionSummary = summary  // 摘要
            optimizationQueue.updatedAt = Date()  // 排序/落盘时间
        }
        persistOptimizationQueue()  // 落盘
        host.document.syncLeftPageFromOptimizationQueue()  // 左页更新
    }


    /// 分析回复收成草稿并入队。
    func handleAnalysisCompletion(reply: String) {
        if let projectPath = SelfEvolution.sourceProjectDirectory()?.path,  // 有源码才看 git
           !gitWorkingTreeIsClean(at: projectPath) {  // 脏了不入队，避免叠改
            host.appendDisplayedMessage(  // 告诉用户先提交
                ChatMessage(  // 脏工作区
                    role: .assistant,
                    content: BookL10n.string("vm.evolution.analysisDirty")
                ),
                to: .evolution  // 进化气泡
            )
            return  // 草稿不入队
        }

        let drafts = EvolutionAnalyzer.parseItems(from: reply)  // 从分析回复抽条
        if drafts.isEmpty {  // 模型没给出可入队的
            host.appendDisplayedMessage(  // 告诉用户先提交
                ChatMessage(role: .assistant, content: BookL10n.string("vm.evolution.noNewItems")),  // 没有新项
                to: .evolution  // 进化气泡
            )
            return  // 草稿不入队
        }

        let report = optimizationQueue.merge(drafts: drafts)  // 去重合并
        persistOptimizationQueue()  // 落盘
        host.document.syncLeftPageFromOptimizationQueue()  // 左页更新
        host.appendDisplayedMessage(  // 告诉用户先提交
            ChatMessage(role: .assistant, content: report.summaryChinese),  // 新增/重复统计
            to: .evolution  // 进化气泡
        )
        UserDefaults.standard.removeObject(forKey: "evolutionUtilityTab")  // 清旧 Tab 记忆
    }


    /// 工作区脏则不自动进化。
    private func gitWorkingTreeIsClean(at projectPath: String) -> Bool {
        let process = Process()  // git status --porcelain
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")  // 系统 git
        process.arguments = ["-C", projectPath, "status", "--porcelain"]  // 有输出就是脏
        let pipe = Pipe()  // 收 stdout
        process.standardOutput = pipe  // 给后面读
        process.standardError = Pipe()  // stderr 丢掉
        do {
            try process.run() // 调用可能失败的方法
            process.waitUntilExit()  // 同步等
            guard process.terminationStatus == 0 else { return true }  // git 失败当干净，避免误拦分析
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""  // porcelain
            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空=干净
        } catch {
            return true  // 异常当干净，不挡入队
        }
    }


    /// 从用户文案抠「N、」。
    func extractEvolutionCommandNumber(from displayText: String) -> Int? {
        let pattern = #"第\s*(\d+)\s*条"#  // 气泡「第 N 条」
        guard let regex = try? NSRegularExpression(pattern: pattern),  // 编译失败当没号
              let match = regex.firstMatch(  // 第一处
                in: displayText,  // 屏上那句
                range: NSRange(displayText.startIndex..., in: displayText)  // 全文
              ),
              let range = Range(match.range(at: 1), in: displayText)  // 数字捕获
        else { return nil }  // 抠不到
        return Int(displayText[range])  // 转 Int
    }


}

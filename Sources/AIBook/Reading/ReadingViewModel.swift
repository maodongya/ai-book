import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 双页读书编排：左页原文、右页讲解/翻译/进化，以及 AI 与朗读请求的状态机。
final class ReadingViewModel: ObservableObject {
    static let untitledMarker = "未命名"  // 还没存盘的左页标题

    /// 单次助手/进化请求的聚合结果（正文、思考链、回退提示）。
    struct AssistantReplyOutcome {
        let text: String  // 最终回复正文
        let thinking: String?  // 思考链；讲解为 nil
        let fallbackNotice: String?  // 回退通道时单独一条提示
    }

    let document = ReadingDocumentSession()  // 左页文件、选区、目录
    let mode = ReadingModeSession()  // 学习/阅读、分页摊
    let translation = ReadingTranslationSession()  // 译文和对齐
    let assistant = ReadingAssistantSession()  // 讲解对话和朗读
    let evolution = ReadingEvolutionSession()  // 进化队列和对话

    @Published var rightPageTab: RightPageTab = .readingAssistant {
        didSet {
            guard !isRestoringSession else { return }  // 恢复中不覆盖磁盘
            syncDisplayedChatMessages()  // 按恢复的 Tab 填
            persistChatSession()  // 落盘，刷新后还是空对话
        }
    }
    @Published var isLoading = false
    @Published var isRunning = false
    @Published var streamingThinking = ""
    @Published var streamingResponse = ""
    @Published var streamingToolStatus = ""
    @Published var streamingToolSteps: [ExecutionStep] = []
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var showBookSettings = false
    @Published var showUserManual = false

    let llmService = LLMService()  // 读书助手通道
    let cursorService = CursorService()  // 进化本地 Agent
    private let chatSessionStore = ChatSessionStore.shared  // 对话落盘
    var isRestoringSession = false  // 恢复期间抑制 didSet 持久化
    var activeTask: Task<Void, Never>?  // 当前请求，停止时 cancel
    var suppressReplySpeech = false  // 点停止后不再读收尾
    private var cancellables = Set<AnyCancellable>()  // 子会话转发订阅


    private var messageOrchestrator: ReadingMessageOrchestrator!  // init 末尾再绑，避免自引用半初始化

    /// 初始化并连接宿主与会话。
    init() {
        document.host = self  // 子会话回指
        mode.host = self  // 分页要读左页
        translation.host = self  // 译文要切 Tab
        assistant.host = self  // 讲解要发消息
        evolution.host = self  // 进化走编排器
        wireSessionChangeForwarding()  // 子 @Published 冒泡到 VM
        translation.translationScrollSync.sourceView = translation.sourceTextScrollProxy  // 左页滚动代理
        translation.translationScrollSync.translationView = translation.translationTextScrollProxy  // 右页滚动代理
        translation.syncTranslationScrollPresentation()  // 代理和锚点
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in  // 合成器状态回按钮
            self?.assistant.syncExplanationSpeechState()  // 弱引用，VM 释放不留回调
        }
        document.loadReadmeNotes()  // 编号笔记
        evolution.loadOptimizationQueue()  // 上次队列
        evolution.ensureEvolutionWelcome()  // 补欢迎
        restoreChatSession()  // 磁盘会话
        syncDisplayedChatMessages()  // 按恢复的 Tab 填
        translation.refreshTranslationAlignmentStaleState()  // 原文和哈希对不上标 stale
        persistChatSession()  // 落盘，刷新后还是空对话
        document.restoreDirectoryBrowserSessions()  // 目录根和展开
        messageOrchestrator = ReadingMessageOrchestrator()  // 现在 VM 已完整
        messageOrchestrator.host = self  // 编排器回指
    }

    /// 子会话 `@Published` 变化时转发到 VM，保证 SwiftUI 刷新。
    private func wireSessionChangeForwarding() {
        document.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables) // 订阅并保存 Combine 引用
        mode.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables) // 订阅并保存 Combine 引用
        translation.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables) // 订阅并保存 Combine 引用
        assistant.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables) // 订阅并保存 Combine 引用
        evolution.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables) // 订阅并保存 Combine 引用
    }


    /// Cursor 上下文占用，超限要提示。
    var cursorContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(  // 按设置的百分比截
            fileContent: document.fileContent,  // 左页全文
            selectedText: document.selectedText,  // 选区优先进上下文
            history: assistant.readingPromptMessages,  // 讲解历史
            input: assistant.readingChatInput,  // 输入框也占额度
            contextPercent: AppSettings.shared.cursorContextPercent  // Cursor 条
        )
    }

    /// 书内 LLM 上下文占用。
    var llmContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(  // 按设置的百分比截
            fileContent: document.fileContent,  // 左页全文
            selectedText: document.selectedText,  // 选区优先进上下文
            history: assistant.readingPromptMessages,  // 讲解历史
            input: assistant.readingChatInput,  // 输入框也占额度
            contextPercent: AppSettings.shared.bookContextPercent,  // 本书设置的百分比
            limitCharacters: LLMContextLimits.maxCharacters  // 读书助手另有上限
        )
    }

    /// 进化正在跑的工具短名，状态条用。
    var evolutionLiveToolLabel: String? {
        guard isRunning, evolution.showsExecutionTrace else { return nil }  // 没在跑或不露轨迹就不用标签
        if let last = streamingToolSteps.last {  // 最后一步代表当前
            let name = EvolutionToolLabels.localizedToolName(last.name)  // 桥接英文名转中文
            if last.status == .running {  // 进行中
                return BookL10n.format("vm.tool.running", name)  // 「正在 name」
            }
            return BookL10n.format("vm.tool.done", name)  // 刚结束也显示一下
        }
        if !streamingToolStatus.isEmpty { return streamingToolStatus }  // 短状态
        if !streamingThinking.isEmpty { return BookL10n.string("vm.thinking") }  // 只有思考
        return nil  // 还没输出
    }

    /// 进化上下文占用。
    var evolutionContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(  // 按设置的百分比截
            fileContent: document.fileContent,  // 左页全文
            selectedText: document.selectedText,  // 选区优先进上下文
            history: evolution.evolutionPromptMessages,  // 进化历史
            input: evolution.evolutionChatInput,  // 进化输入框
            contextPercent: AppSettings.shared.cursorContextPercent,
            limitCharacters: CursorContextLimits.maxCharacters  // Cursor 硬顶
        )
    }

    /// 进化 token 预算，超限不能跑。
    var evolutionTokenBudget: ModelTokenBudget {
        evolution.evolutionTokenBudget(additionalPrompt: nil)  // 当前输入框已算进 usage
    }

    /// 预算没超才能开跑。
    var canRunEvolution: Bool { !evolutionTokenBudget.isOverLimit }

    /// Cursor 可跑才显示过程卡。
    var showsEvolutionExecutionTrace: Bool { AppSettings.shared.isCursorRunnable }

    /// 正在跑且是分析轮，不是执行轮。
    var isAnalyzing: Bool { isRunning && evolution.evolutionRunKind == .analysis }

    /// 队列非空才能导出。
    var canSaveEvolutionCommands: Bool { !evolution.optimizationQueue.items.isEmpty }
    /// 没在跑才能打开命令文件。
    var canOpenEvolutionCommands: Bool { !isRunning }

    /// 讲解或翻译有内容才能清空阅读上下文。
    var canClearReadingContext: Bool {
        assistant.hasExplanationContent  // 有讲解就能清
            || !assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 输入框有字也能清
    }

    /// 进化对话有内容才能清空进化上下文。
    var canClearAIContext: Bool {
        evolution.hasEvolutionConversation  // 有对话
            || !evolution.evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 或输入框
            || evolution.evolutionSessionTokensConsumed > 0  // 或已耗 token
            || evolution.evolutionAgentContextTokens > 0  // 或 Agent 上下文
    }



    /// 转给编排器。
    func resetStreamingState() { messageOrchestrator.resetStreamingState() }
    /// 转给编排器。
    func beginRun(showsExecutionTrace: Bool) { messageOrchestrator.beginRun(showsExecutionTrace: showsExecutionTrace) }
    /// 转给编排器。
    func handleLLMStreamEvent(_ event: LLMStreamEvent) { messageOrchestrator.handleLLMStreamEvent(event) }
    /// 转给编排器。
    func handleCursorStreamEvent(_ event: CursorStreamEvent) { messageOrchestrator.handleCursorStreamEvent(event) }
    /// 转给编排器。
    func applyToolStepUpdate(name: String, status: String, callId: String?, detail: String?, result: String?, error: String?) {
        messageOrchestrator.applyToolStepUpdate(name: name, status: status, callId: callId, detail: detail, result: result, error: error)  // 转发
    }
    /// 转给编排器。
    func resolvedToolStepsForMessage() -> [ExecutionStep]? { messageOrchestrator.resolvedToolStepsForMessage() }
    /// 转给编排器。
    func sendMessage(_ prompt: String, displayText: String, isEvolution: Bool = false, evolutionCommandNumber: Int? = nil, speakReplyWhenDone: Bool = false, triggerEvolutionRebuild: Bool = false, evolutionRunKind: ReadingEvolutionRunKind = .none) {
        messageOrchestrator.sendMessage(prompt, displayText: displayText, isEvolution: isEvolution, evolutionCommandNumber: evolutionCommandNumber, speakReplyWhenDone: speakReplyWhenDone, triggerEvolutionRebuild: triggerEvolutionRebuild, evolutionRunKind: evolutionRunKind)  // 转发，参数原样
    }
    /// 转给编排器。
    func fetchAssistantReply(prompt: String, history: [ChatMessage], settings: AppSettings, evolutionRunKind: ReadingEvolutionRunKind = .none, llmMode: AIBookLLMPrompt.Mode? = nil) async throws -> AssistantReplyOutcome {
        try await messageOrchestrator.fetchAssistantReply(prompt: prompt, history: history, settings: settings, evolutionRunKind: evolutionRunKind, llmMode: llmMode) // 等待异步完成
    }
    /// 转给编排器。
    func fetchCursorReply(prompt: String, history: [ChatMessage], settings: AppSettings, systemInstruction: String, evolutionRunKind: ReadingEvolutionRunKind) async throws -> AssistantReplyOutcome {
        try await messageOrchestrator.fetchCursorReply(prompt: prompt, history: history, settings: settings, systemInstruction: systemInstruction, evolutionRunKind: evolutionRunKind) // 等待异步完成
    }
    /// 转给编排器。
    func fetchLLMReply(prompt: String, history: [ChatMessage], configuration: LLMConfiguration, systemPrompt: String) async throws -> String {
        try await messageOrchestrator.fetchLLMReply(prompt: prompt, history: history, configuration: configuration, systemPrompt: systemPrompt) // 等待异步完成
    }


    /// 首次出现：恢复目录、Key、说明书。
    func onAppear() {
        evolution.scheduleAutoEvolutionIfNeeded()  // 自动进化开着且有 pending 才串
    }


    /// 切右页 Tab 并记住。
    func selectRightPageTab(_ tab: RightPageTab) {
        guard rightPageTab != tab else { return }  // 同 Tab 不重入
        if tab == .aiEvolution {  // 切到进化时补欢迎并强制 Cursor
            evolution.ensureEvolutionWelcome()  // 补欢迎
            evolution.ensureEvolutionUsesCursor()  // 读书模型不能跑进化
        }
        rightPageTab = tab  // 恢复期间 didSet 被抑制
    }


    /// 打开通用设置。
    func openSettings() {
        selectRightPageTab(.aiEvolution)  // 设置从进化页进
        showSettings = true  // sheet
    }


    /// 打开本书设置。
    func openBookSettings() {
        selectRightPageTab(.readingAssistant)  // 本书设置从助手进
        showBookSettings = true  // sheet
    }


    /// 打开说明书。
    func openUserManual() {
        showUserManual = true  // sheet，不切 Tab
    }


    /// 用户点停止：取消网络/任务、清流式状态，必要时回滚进化命令并插入「已停止」气泡。
    func stopCurrentRun() {
        let wasRunning = isRunning || activeTask != nil // 是否在跑 AI/进化
        let wasTranslationProgress = translation.showsTranslationProgressSheet  // 翻译弹出层
        let wasExplanationProgress = assistant.showsExplanationProgressSheet  // 全文讲解弹出层
        let stoppedEvolutionNumber = evolution.executingEvolutionCommandNumber // 便于回滚队列项
        suppressReplySpeech = true // 停止后不再自动朗读收尾
        activeTask?.cancel()  // 取消网络 Task
        activeTask = nil  // 允许立刻再发
        cursorService.cancel()  // 掐 Cursor 桥
        llmService.cancel()  // 掐读书请求
        assistant.stopExplanationSpeech()  // 清上下文先停朗读
        isLoading = false  // 转圈关
        isRunning = false  // 按钮恢复
        streamingThinking = ""  // 清残字
        streamingResponse = ""  // 清残字
        streamingToolStatus = ""  // 清顶栏
        streamingToolSteps = []  // 清步骤
        evolution.executingEvolutionCommandNumber = nil  // 不再指向那条命令
        evolution.showsExecutionTrace = false  // 轨迹区收起
        translation.endTranslationProgress()  // 关翻译弹出层
        assistant.endExplanationProgress()  // 关讲解弹出层
        if wasRunning, let number = stoppedEvolutionNumber {  // 进化中途停
            evolution.revertRunningOptimization(number: number) // 进化中途停止则恢复 pending
        }
        if wasRunning, !wasTranslationProgress, !wasExplanationProgress {  // 翻译/全文讲解停止不插「已停止」
            appendDisplayedMessage(  // 「已停止」
                ChatMessage(role: .assistant, content: BookL10n.string("vm.stopped")),  // 本地化
                to: activePromptContext  // 写进当前 Tab 的历史
            )
        }
    }

    /// 界面语言立刻生效。
    func applyLanguageChange() {
        if evolution.evolutionPromptMessages.count == 1,  // 只有欢迎语才替换，避免冲掉对话
           evolution.evolutionPromptMessages[0].role == .assistant,  // 确认是助手气泡
           BookL10nMarkers.isEvolutionWelcome(evolution.evolutionPromptMessages[0].content) {  // 各语言欢迎都能认
            let existing = evolution.evolutionPromptMessages[0]  // 保住 id，避免列表闪
            evolution.evolutionPromptMessages = [  // 换成当前语言
                ChatMessage(id: existing.id, role: .assistant, content: EvolutionAssistant.welcomeMessage),  // id 不变
            ]
        }
        syncDisplayedChatMessages()  // 按恢复的 Tab 填
        document.activateBundledLanguagesForCurrentSettings()
    }


    /// 清阅读上下文，不关文件。
    func clearReadingContext() {
        guard !isRunning else { return }  // 跑着不清，避免历史被拆
        assistant.stopExplanationSpeech()  // 清上下文先停朗读
        assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 讲解欢迎
        assistant.readingChatInput = ""  // 输入框
        assistant.explanationSelectionText = ""  // 朗读/追问用的选区
        assistant.explanationPanelSelectedText = ""  // 面板选区
        document.lastCommittedExplanationPanelSelectedText = ""  // 提交过的也清
        errorMessage = nil  // 顺带清错
        if isDisplaying(.reading) {  // 当前就在助手页才同步气泡
            assistant.chatMessages = assistant.readingPromptMessages  // 立刻上屏欢迎
        }
        persistChatSession()  // 落盘，刷新后还是空对话
    }


    /// 清 AI 历史。
    func clearAIContext() {
        guard !isRunning else { return }  // 跑着不清，避免历史被拆
        evolution.evolutionPromptMessages = [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]  // 进化欢迎
        evolution.evolutionChatInput = ""  // 输入框
        evolution.evolutionSessionTokensConsumed = 0  // 本会话计数归零
        evolution.evolutionAgentContextTokens = 0  // Agent 上下文归零
        evolution.evolutionLastRequestId = nil  // 上次请求号
        EvolutionCursorSession.clear()  // 丢掉 agentId，下次新开
        errorMessage = nil  // 顺带清错
        if isDisplaying(.evolution) {  // 在进化页才刷气泡
            assistant.chatMessages = evolution.evolutionPromptMessages  // 上屏欢迎
        }
        persistChatSession()  // 落盘，刷新后还是空对话
    }

    /// 顶栏或输入区展示的「正在执行」文案。
    func runningStatusText(for mode: RightPageTab) -> String {
        guard isRunning else { return "" }  // 没在跑不占位
        if translation.showsTranslationProgressSheet {
            return BookL10n.string("translation.generating")
        }
        if assistant.showsExplanationProgressSheet {
            return BookL10n.string("explanation.generating")
        }
        if mode == .aiEvolution, evolution.showsExecutionTrace {  // 进化轨迹优先工具文案
            if !streamingToolStatus.isEmpty { return streamingToolStatus }  // 短状态
            if let label = evolutionLiveToolLabel { return label }  // 步骤标签
            return BookL10n.string("vm.evolutionRunning")  // 还没步骤
        }
        return BookL10n.string("vm.processing")  // 讲解统一「处理中」
    }



    /// 真正发给模型的消息。
    func apiHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        contextHistory(for: context).filter { message in  // 显示历史再滤欢迎/译文
            switch context {  // 按上下文删
            case .reading:  // 讲解
                if BookL10nMarkers.isClassicSupplementIntro(message.content) { return false }  // 名著补全引导不上模型
                if BookL10nMarkers.isReadingAssistantWelcome(message.content) { return false }  // 欢迎不上模型
                if assistant.isTranslationHistoryMessage(message) { return false }  // 译文相关不当讲解历史
                return true  // chatMessages 跟这套走
            case .evolution:  // 进化
                guard message.role == .assistant else { return true }  // 用户句不过滤
                return !BookL10nMarkers.isEvolutionWelcome(message.content)  // 欢迎不上模型
            }
        }
    }


    /// 带显示用消息的完整历史。
    func contextHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        switch context {  // 按上下文删
        case .reading:  // 讲解
            return assistant.readingPromptMessages  // 含欢迎和显示用
        case .evolution:  // 进化
            return evolution.evolutionPromptMessages  // 含欢迎
        }
    }


    /// 追加一条提示。
    func appendPromptMessage(_ message: ChatMessage, to context: ReadingPromptContext) {
        switch context {  // 按上下文删
        case .reading:  // 讲解
            assistant.readingPromptMessages.append(message)  // 讲解历史
            assistant.syncExplanationSelectionText()  // 朗读选区
        case .evolution:  // 进化
            evolution.evolutionPromptMessages.append(message)  // 进化历史
        }
    }


    /// 改已有提示。
    func updatePromptMessage(id: UUID, content: String) {
        if let index = assistant.readingPromptMessages.firstIndex(where: { $0.id == id }) {  // 先改讲解
            assistant.readingPromptMessages[index].content = content  // 只改正文
            assistant.syncExplanationSelectionText()  // 朗读选区
        }
        if let index = evolution.evolutionPromptMessages.firstIndex(where: { $0.id == id }) {  // 再改进化；id 不会跨上下文撞
            evolution.evolutionPromptMessages[index].content = content  // 只改正文
        }
    }


    /// 删一条提示。
    func removePromptMessage(id: UUID, from context: ReadingPromptContext) {
        switch context {  // 按上下文删
        case .reading:  // 讲解
            assistant.readingPromptMessages.removeAll { $0.id == id }  // 讲解
            assistant.syncExplanationSelectionText()  // 朗读选区
        case .evolution:  // 进化
            evolution.evolutionPromptMessages.removeAll { $0.id == id }  // 进化
        }
    }

    /// 当前右页对应的提示词上下文。
    var activePromptContext: ReadingPromptContext {
        rightPageTab == .readingAssistant ? .reading : .evolution  // 右页 Tab 决定当前上下文
    }


    /// 这条只上屏不进 API。
    func isDisplaying(_ context: ReadingPromptContext) -> Bool {
        switch (rightPageTab, context) {  // 只有匹配的那对才上屏
        case (.readingAssistant, .reading), (.aiEvolution, .evolution):  // 当前 Tab 对应的上下文
            return true  // chatMessages 跟这套走
        default:  // 另一套只写历史不上屏
            return false  // 避免串台
        }
    }


    /// 写入 prompt 历史；若当前 Tab 正在展示该上下文，同步追加到界面消息列表。
    func appendDisplayedMessage(_ message: ChatMessage, to context: ReadingPromptContext) {
        appendPromptMessage(message, to: context)  // 先写源历史
        if isDisplaying(context) {  // 正在看才追加气泡
            assistant.chatMessages.append(message)  // 界面列表
        }
    }

    /// 按当前右页 Tab 刷新界面上的 `chatMessages`（与 prompt 历史源一致）。
    func syncDisplayedChatMessages() {
        assistant.chatMessages = contextHistory(for: activePromptContext)  // 整表替换，避免两套交错
    }


    /// 从磁盘恢复对话、译文、对齐与上次打开的文件路径。
    func restoreChatSession() {
        isRestoringSession = true // 抑制 didSet 里的持久化
        defer { isRestoringSession = false }  // 方法结束一定解开

        let session: PersistedChatSession?  // 读盘失败当没有
        do {  // 写失败只报错，不回滚内存
            session = try chatSessionStore.load()  // 可能抛
        } catch {  // 磁盘满/权限
            errorMessage = BookL10n.format("vm.error.restoreChat", error.localizedDescription)  // 顶栏
            session = nil  // 走下面空会话分支
        }

        guard let session, !session.messages.isEmpty else {  // 没存过或空
            assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 讲解欢迎
            evolution.ensureEvolutionWelcome()  // 补欢迎
            syncDisplayedChatMessages()  // 按恢复的 Tab 填
            return  // 不读文件路径
        }

        assistant.readingPromptMessages = session.readingMessages ?? session.messages  // 旧版只有一份 messages
        evolution.evolutionPromptMessages = session.evolutionMessages ?? [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]  // 旧版没有进化历史
        if evolution.evolutionPromptMessages.isEmpty {  // 存了空数组
            evolution.ensureEvolutionWelcome()  // 补欢迎
        }
        assistant.readingChatInput = session.readingChatInput ?? session.chatInput  // 旧字段 chatInput
        evolution.evolutionChatInput = session.evolutionChatInput ?? ""  // 旧版没有
        if let tabName = session.rightPageTab,  // 记住上次 Tab
           let tab = RightPageTab(rawValue: tabName) {  // 枚举改名则忽略
            rightPageTab = tab  // 恢复期间 didSet 被抑制
        }
        translation.lessonPlanContent = session.lessonPlanContent ?? ""  // 译文
        translation.translationAlignment = session.translationAlignment  // 对齐；可能 nil
        if translation.translationAlignment == nil,  // 有译文没对齐就重建
           !translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 空译文不建
            if var rebuilt = translation.rebuildTranslationAlignment(from: translation.lessonPlanContent) {
                rebuilt.provenance = .realignedHeuristic
                rebuilt.strictParagraphValidated = false
                translation.translationAlignment = rebuilt
            }
        }
        translation.refreshTranslationAlignmentStaleState()  // 原文和哈希对不上标 stale
        translation.repairCollapsedParagraphAlignmentIfNeeded()  // 左页加载后再修一次，原文可能变了
        if let tableViewEnabled = session.translationTableViewEnabled, tableViewEnabled {  // 只恢复「开」，关是默认
            translation.translationTableViewEnabled = translation.canUseTranslationTableView  // 对齐不可用则仍关
        }
        assistant.explanationAlignment = session.explanationAlignment
        if assistant.explanationAlignment == nil,
           assistant.hasExplanationContent {
            _ = assistant.alignExplanationWithSource(showFeedback: false)
        }
        assistant.refreshExplanationAlignmentStaleState()
        if let explanationTable = session.explanationTableViewEnabled, explanationTable {
            assistant.explanationTableViewEnabled = assistant.canUseExplanationTableView
        }
        translation.syncTranslationScrollPresentation()  // 代理和锚点
        if let panelName = session.readingAssistantPanel,  // 讲解/译文子面板
           let panel = ReadingAssistantPanel.fromPersisted(panelName) {  // 旧名兼容
            assistant.readingAssistantPanel = panel  // 恢复
        }
        syncDisplayedChatMessages()  // 按恢复的 Tab 填
        assistant.syncExplanationSelectionText()  // 朗读选区

        if let path = session.lastOpenedFilePath {  // 上次左页
            let url = URL(fileURLWithPath: path)  // 本地路径
            if FileManager.default.fileExists(atPath: url.path) {  // 文件没了就保持未命名
                document.loadFile(at: url, resetChat: false) // 只恢复左页，不重置对话
            }
        }
        translation.repairCollapsedParagraphAlignmentIfNeeded()  // 左页加载后再修一次，原文可能变了
    }


    /// 将当前读书/进化会话写入本地存储（恢复过程中跳过以免覆盖）。
    func persistChatSession() {
        guard !isRestoringSession else { return }  // 恢复中不覆盖磁盘
        do {  // 写失败只报错，不回滚内存
            try chatSessionStore.save( // 调用可能失败的方法
                readingMessages: assistant.readingPromptMessages,  // 讲解
                evolutionMessages: evolution.evolutionPromptMessages,  // 进化
                readingChatInput: assistant.readingChatInput,  // 讲解输入
                evolutionChatInput: evolution.evolutionChatInput,  // 进化输入
                rightPageTab: rightPageTab,  // Tab
                readingAssistantPanel: assistant.readingAssistantPanel,  // 子面板
                lastOpenedFilePath: document.currentFileURL?.path,  // 未命名则 nil
                lessonPlanContent: translation.lessonPlanContent,  // 译文全文
                translationAlignment: translation.translationAlignment,  // 对齐快照
                translationTableViewEnabled: translation.translationTableViewEnabled,  // 对照表开关
                explanationAlignment: assistant.explanationAlignment,
                explanationTableViewEnabled: assistant.explanationTableViewEnabled
            )
        } catch {  // 磁盘满/权限
            errorMessage = BookL10n.format("vm.error.saveChat", error.localizedDescription)  // 顶栏，内存仍在
        }
    }
}

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
    @Published var showBookSettings = false
    @Published var showUserManual = false
    @Published var showPrivacyPolicy = false

    let llmService = LLMService()  // 读书助手通道
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
        wireSessionChangeForwarding()  // 子 @Published 冒泡到 VM
        translation.translationScrollSync.sourceView = translation.sourceTextScrollProxy  // 左页滚动代理
        translation.translationScrollSync.translationView = translation.translationTextScrollProxy  // 右页滚动代理
        translation.syncTranslationScrollPresentation()  // 代理和锚点
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in  // 合成器状态回按钮
            self?.assistant.syncExplanationSpeechState()  // 弱引用，VM 释放不留回调
        }
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

    /// 讲解或翻译有内容才能清空阅读上下文。
    var canClearReadingContext: Bool {
        assistant.hasExplanationContent  // 有讲解就能清
            || !assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 输入框有字也能清
    }



    /// 转给编排器。
    func resetStreamingState() { messageOrchestrator.resetStreamingState() }
    /// 转给编排器。
    func beginRun(showsExecutionTrace: Bool) { messageOrchestrator.beginRun(showsExecutionTrace: showsExecutionTrace) }
    /// 转给编排器。
    func handleLLMStreamEvent(_ event: LLMStreamEvent) { messageOrchestrator.handleLLMStreamEvent(event) }
    /// 转给编排器。
    func fetchAssistantReply(prompt: String, history: [ChatMessage], settings: AppSettings, llmMode: AIBookLLMPrompt.Mode? = nil) async throws -> AssistantReplyOutcome {
        try await messageOrchestrator.fetchAssistantReply(prompt: prompt, history: history, settings: settings, llmMode: llmMode)
    }
    /// 转给编排器。
    func fetchLLMReply(prompt: String, history: [ChatMessage], configuration: LLMConfiguration, systemPrompt: String) async throws -> String {
        try await messageOrchestrator.fetchLLMReply(prompt: prompt, history: history, configuration: configuration, systemPrompt: systemPrompt) // 等待异步完成
    }


    /// 首次出现：恢复目录、Key、说明书。
    func onAppear() {}


    /// 切右页 Tab 并记住。
    func selectRightPageTab(_ tab: RightPageTab) {
        guard rightPageTab != tab else { return }
        rightPageTab = tab
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

    /// 打开隐私说明。
    func openPrivacyPolicy() {
        showPrivacyPolicy = true
    }


    /// 用户点停止：取消网络/任务、清流式状态，必要时回滚进化命令并插入「已停止」气泡。
    func stopCurrentRun() {
        let wasRunning = isRunning || activeTask != nil
        let wasTranslationProgress = translation.showsTranslationProgressSheet
        let wasExplanationProgress = assistant.showsExplanationProgressSheet
        suppressReplySpeech = true
        activeTask?.cancel()
        activeTask = nil
        llmService.cancel()
        assistant.stopExplanationSpeech()
        isLoading = false
        isRunning = false
        streamingThinking = ""
        streamingResponse = ""
        streamingToolStatus = ""
        streamingToolSteps = []
        translation.endTranslationProgress()
        assistant.endExplanationProgress()
        if wasRunning, !wasTranslationProgress, !wasExplanationProgress {
            appendDisplayedMessage(  // 「已停止」
                ChatMessage(role: .assistant, content: BookL10n.string("vm.stopped")),  // 本地化
                to: activePromptContext  // 写进当前 Tab 的历史
            )
        }
    }

    /// 界面语言立刻生效。
    func applyLanguageChange() {
        syncDisplayedChatMessages()
        document.activateBundledLanguagesForCurrentSettings()
    }


    /// 原文新建时，翻译和讲解的正文、对照表、选区和追问上下文一起清掉。不切页，不动进化。
    func clearReadingCompanionsForNewDocument() {
        translation.clearLessonPlan()  // 译文和对齐，和「清空翻译」同一套
        translation.translationTableViewEnabled = false  // 对照开关回到关
        translation.translationTableScrollTargetID = nil  // 不留旧行
        translation.translationTableHighlightedBlockID = nil  // 不留高亮
        translation.translationTableFocusTranslationBlockID = nil  // 不留焦点
        translation.lessonPlanSelectedText = ""  // 译文选区
        translation.translationStreamPreview = ""  // 弹出层残字
        translation.showsTranslationProgressSheet = false  // 弹出层
        document.lastCommittedLessonPlanSelectedText = ""  // 提交过的译文选区

        assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 讲解追问上下文
        assistant.readingChatInput = ""  // 输入框里的追问
        assistant.explanationSelectionText = ""  // 讲解全文选区
        assistant.explanationPanelSelectedText = ""  // 讲解即时选区
        document.lastCommittedExplanationPanelSelectedText = ""  // 提交过的讲解选区
        assistant.clearExplanationTableState()  // 讲解对照表，和「清空讲解」同一套
        assistant.endExplanationProgress()  // 讲解弹出层
        assistant.readingAssistantActiveTask = nil  // 不再标翻译中/讲解中
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

    /// 顶栏或输入区展示的「正在执行」文案。
    func runningStatusText(for mode: RightPageTab) -> String {
        _ = mode
        guard isRunning else { return "" }
        if translation.showsTranslationProgressSheet {
            return BookL10n.string("translation.generating")
        }
        if assistant.showsExplanationProgressSheet {
            return BookL10n.string("explanation.generating")
        }
        return BookL10n.string("vm.processing")
    }



    /// 真正发给模型的消息。
    func apiHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        contextHistory(for: context).filter { message in
            switch context {
            case .reading:
                if BookL10nMarkers.isClassicSupplementIntro(message.content) { return false }
                if BookL10nMarkers.isReadingAssistantWelcome(message.content) { return false }
                if assistant.isTranslationHistoryMessage(message) { return false }
                return true
            }
        }
    }


    func contextHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        switch context {
        case .reading:
            return assistant.readingPromptMessages
        }
    }


    func appendPromptMessage(_ message: ChatMessage, to context: ReadingPromptContext) {
        switch context {
        case .reading:
            assistant.readingPromptMessages.append(message)
            assistant.syncExplanationSelectionText()
        }
    }


    func updatePromptMessage(id: UUID, content: String) {
        if let index = assistant.readingPromptMessages.firstIndex(where: { $0.id == id }) {
            assistant.readingPromptMessages[index].content = content
            assistant.syncExplanationSelectionText()
        }
    }


    func removePromptMessage(id: UUID, from context: ReadingPromptContext) {
        switch context {
        case .reading:
            assistant.readingPromptMessages.removeAll { $0.id == id }
            assistant.syncExplanationSelectionText()
        }
    }

    var activePromptContext: ReadingPromptContext {
        .reading
    }


    func isDisplaying(_ context: ReadingPromptContext) -> Bool {
        switch (rightPageTab, context) {
        case (.readingAssistant, .reading):
            return true
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
            assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
            syncDisplayedChatMessages()
            return
        }

        assistant.readingPromptMessages = session.readingMessages ?? session.messages
        assistant.readingChatInput = session.readingChatInput ?? session.chatInput
        if let tabName = session.rightPageTab,
           let tab = RightPageTab(rawValue: tabName) {
            rightPageTab = tab
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

        if let bookmark = session.lastOpenedFileBookmark {  // 上次用面板打开的文件
            document.reopenGrantedFile(bookmark)  // 书签无效就不按路径去读
        }
        translation.repairCollapsedParagraphAlignmentIfNeeded()  // 左页加载后再修一次，原文可能变了
    }


    /// 将当前读书/进化会话写入本地存储（恢复过程中跳过以免覆盖）。
    func persistChatSession() {
        guard !isRestoringSession else { return }  // 恢复中不覆盖磁盘
        do {  // 写失败只报错，不回滚内存
            try chatSessionStore.save( // 调用可能失败的方法
                readingMessages: assistant.readingPromptMessages,
                evolutionMessages: [],
                readingChatInput: assistant.readingChatInput,
                evolutionChatInput: "",
                rightPageTab: rightPageTab,
                readingAssistantPanel: assistant.readingAssistantPanel,  // 子面板
                lastOpenedFilePath: document.currentFileURL?.path,  // 未命名则 nil
                lastOpenedFileBookmark: document.folderGrants.bookmarkData(for: document.documentGrantID),  // 下次靠书签打开
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

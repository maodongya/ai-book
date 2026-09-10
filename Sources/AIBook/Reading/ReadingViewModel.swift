import AIBookEvolution
import AppKit
import Foundation

enum SpeechSource: Equatable {
    case originalFull
    case originalSelection
    case translationFull
    case translationSelection
    case explanationFull
    case explanationSelection
    case aiReply

    var label: String {
        switch self {
        case .originalFull: return "原文全文"
        case .originalSelection: return "原文选中"
        case .translationFull: return "翻译全文"
        case .translationSelection: return "翻译选中"
        case .explanationFull: return "讲解全文"
        case .explanationSelection: return "讲解选中"
        case .aiReply: return "AI 回复"
        }
    }

    var icon: String {
        switch self {
        case .originalFull, .originalSelection: return "text.book.closed"
        case .translationFull, .translationSelection: return "character.book.closed"
        case .explanationFull, .explanationSelection: return "sparkles.text.clipboard"
        case .aiReply: return "bubble.left.and.text.bubble.right"
        }
    }
}

@MainActor
final class ReadingViewModel: ObservableObject {
    private enum PromptContext {
        case reading
        case evolution
    }

    enum EvolutionRunKind {
        case none
        case analysis
        case evolution
        case followUp
    }

    @Published var fileContent = "" {
        didSet {
            isDirty = fileContent != savedContent
            scheduleAutoSaveIfNotes()
            if !isRestoringSession, !isApplyingAlignment {
                refreshTranslationAlignmentStaleState()
            }
        }
    }
    @Published var fileName = "未命名"
    @Published private(set) var isDocumentOpen = false
    @Published var selectedText = ""
    /// 最近一次非空选区；点击顶栏时系统常会清空高亮，朗读/讲解仍用此缓存。
    private var lastCommittedSelectionText = ""
    private var lastCommittedSelectionRange: NSRange?
    @Published private(set) var leftSelectAllSignal = UUID()
    @Published private(set) var rightSelectAllSignal = UUID()
    @Published private(set) var explanationSelectAllSignal = UUID()
    @Published var explanationSelectionText = ""
    @Published var lessonPlanSelectedText = ""
    @Published var explanationPanelSelectedText = ""
    private var lastCommittedLessonPlanSelectedText = ""
    private var lastCommittedExplanationPanelSelectedText = ""
    @Published private(set) var isDirty = false
    @Published var chatMessages: [ChatMessage] = [] {
        didSet { persistChatSession() }
    }
    @Published var readingChatInput = "" {
        didSet { persistChatSession() }
    }
    @Published var evolutionChatInput = "" {
        didSet { persistChatSession() }
    }
    @Published var rightPageTab: RightPageTab = .readingAssistant {
        didSet {
            guard !isRestoringSession else { return }
            syncDisplayedChatMessages()
            persistChatSession()
        }
    }
    @Published var readingAssistantPanel: ReadingAssistantPanel = .explanation {
        didSet {
            guard !isRestoringSession else { return }
            persistChatSession()
        }
    }
    @Published private(set) var readingAssistantActiveTask: ReadingAssistantPanel?
    @Published var lessonPlanContent = "" {
        didSet {
            if !isApplyingAlignment {
                refreshTranslationAlignmentStaleState(fromManualEdit: true)
            }
            persistChatSession()
        }
    }
    @Published var translationAlignment: TranslationAlignment? {
        didSet {
            translationScrollSync.resetAnchors()
            if isApplyingAlignment { return }
            syncTranslationScrollPresentation()
            persistChatSession()
        }
    }
    @Published var translationTableViewEnabled = false {
        didSet {
            syncTranslationScrollPresentation()
            persistChatSession()
        }
    }
    @Published var translationTableScrollTargetID: UUID?
    @Published var translationTableHighlightedBlockID: UUID?
    @Published var translationTableFocusTranslationBlockID: UUID?

    let sourceTextScrollProxy = SelectableTextViewProxy()
    let translationTextScrollProxy = SelectableTextViewProxy()
    let translationScrollSync = TranslationScrollSync()
    @Published var isLoading = false
    @Published var isRunning = false
    @Published var streamingThinking = ""
    @Published var streamingResponse = ""
    @Published var streamingToolStatus = ""
    @Published var streamingToolSteps: [ExecutionStep] = []
    /// 仅 AI 进化任务为 true；读书助手与名著补充不展示思考/工具等中间过程。
    @Published private(set) var showsExecutionTrace = false
    @Published var executingEvolutionCommandNumber: Int?
    @Published var isEvolutionRebuilding = false
    @Published var evolutionRebuildStatus = ""
    @Published private(set) var evolutionSessionTokensConsumed = 0
    @Published private(set) var evolutionAgentContextTokens = 0
    @Published var optimizationQueue = OptimizationQueue.empty
    @Published private(set) var evolutionRunKind: EvolutionRunKind = .none
    @Published private(set) var evolutionLastRequestId: String?
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var showBookSettings = false
    @Published private(set) var isSpeakingExplanation = false
    @Published private(set) var isExplanationSpeechPaused = false
    @Published private(set) var currentSpeechSource: SpeechSource?
    @Published private(set) var lastSaveMessage: String?

    @Published var experienceMode: ReadingExperienceMode = .learning
    @Published private(set) var readingPageTexts: [String] = []
    @Published private(set) var readingSourcePageRanges: [NSRange] = []
    @Published var readingSpreadIndex: Int = 0 {
        didSet {
            guard readingSpreadIndex != oldValue else { return }
            persistReadingSpreadIndex()
        }
    }

    private var pendingReadingSourcePage: Int?
    private var lastReadingPageContentSize: CGSize?
    private let readingPositionKeyPrefix = "aiBook.reading.spread."
    private let readingSourcePageKeyPrefix = "aiBook.reading.sourcePage."
    private let llmService = LLMService()
    private let cursorService = CursorService()
    private let chatSessionStore = ChatSessionStore.shared
    private let readmeNotesStore = ReadmeNotesStore.shared
    private let optimizationQueueStore = OptimizationQueueStore(
        fileURL: OptimizationQueueStore.defaultFileURL
    )
    private var currentFileURL: URL?
    private var savedContent = ""
    private var selectedTextRange: NSRange?
    private var isRestoringSession = false
    private var isApplyingAlignment = false
    private var activeTask: Task<Void, Never>?
    private var autoSaveTask: Task<Void, Never>?
    private var saveMessageTask: Task<Void, Never>?

    private var autoEvolutionTask: Task<Void, Never>?
    private var didScheduleAutoEvolution = false
    private var readingPromptMessages: [ChatMessage] = [ReadingViewModel.defaultWelcomeMessage]
    private var evolutionPromptMessages: [ChatMessage] = []

    private static let defaultWelcomeMessage = ChatMessage(
        role: .assistant,
        content: ReadingAssistant.welcomeMessage
    )

    private static let defaultEvolutionWelcomeMessage = ChatMessage(
        role: .assistant,
        content: EvolutionAssistant.welcomeMessage
    )

    init() {
        translationScrollSync.sourceView = sourceTextScrollProxy
        translationScrollSync.translationView = translationTextScrollProxy
        syncTranslationScrollPresentation()
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in
            self?.syncExplanationSpeechState()
        }
        loadReadmeNotes()
        loadOptimizationQueue()
        ensureEvolutionWelcome()
        restoreChatSession()
        syncDisplayedChatMessages()
        refreshTranslationAlignmentStaleState()
        persistChatSession()
    }

    func onAppear() {
        scheduleAutoEvolutionIfNeeded()
    }

    private func loadOptimizationQueue() {
        do {
            optimizationQueue = try optimizationQueueStore.migrateFromReadmeNotesIfNeeded(
                readmeNotesStore.loadInitialContent()
            )
        } catch {
            errorMessage = "无法加载优化队列：\(error.localizedDescription)"
            optimizationQueue = .empty
        }
    }

    func persistOptimizationQueue() {
        do {
            try optimizationQueueStore.save(optimizationQueue)
        } catch {
            errorMessage = "无法保存优化队列：\(error.localizedDescription)"
        }
    }

    var displayFileName: String {
        guard isDocumentOpen || currentFileURL != nil || !fileContent.isEmpty else {
            return "未打开文件"
        }
        let name = currentFileURL?.lastPathComponent ?? fileName
        return isDirty ? "\(name) •" : name
    }

    var isEditingNotes: Bool {
        currentFileURL == nil
    }

    var canEnterReadingMode: Bool {
        !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var readingSpreadCount: Int {
        max(1, (readingPageTexts.count + 1) / 2)
    }

    var readingPageCount: Int {
        readingPageTexts.count
    }

    func readingPageText(at index: Int) -> String {
        guard readingPageTexts.indices.contains(index) else { return "" }
        return readingPageTexts[index]
    }

    func leftPageIndex(forSpread spreadIndex: Int) -> Int {
        spreadIndex * 2
    }

    func rightPageIndex(forSpread spreadIndex: Int) -> Int? {
        let index = spreadIndex * 2 + 1
        return readingPageTexts.indices.contains(index) ? index : nil
    }

    func currentVisibleSourcePageIndex() -> Int {
        leftPageIndex(forSpread: readingSpreadIndex)
    }

    func readingProgressLabel(spreadIndex: Int) -> String {
        let left = leftPageIndex(forSpread: spreadIndex) + 1
        let total = max(readingPageCount, 1)
        if let rightIndex = rightPageIndex(forSpread: spreadIndex) {
            return "第 \(left)–\(rightIndex + 1) 页 / 共 \(total) 页"
        }
        return "第 \(left) 页 / 共 \(total) 页"
    }

    var canAlignTranslationWithSource: Bool {
        !isRunning
            && translationAlignment?.isLocked != true
            && !lessonPlanSourceText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isTranslationAlignmentLocked: Bool {
        translationAlignment?.isLocked == true
    }

    var translationAlignmentStatusText: String? {
        guard let alignment = translationAlignment else { return nil }
        if alignment.isStale {
            return "对齐失效"
        }
        var parts = ["\(alignment.anchoredBlockCount)/\(alignment.blocks.count) 已锚定"]
        if alignment.isLocked {
            parts.append("已锁定")
        }
        return parts.joined(separator: " · ")
    }

    func repaginateForReading(pageContentSize: CGSize) {
        let keepSourcePage = pendingReadingSourcePage ?? currentVisibleSourcePageIndex()
        pendingReadingSourcePage = nil
        lastReadingPageContentSize = pageContentSize
        let pages = BookPaginator.paginateWithRanges(text: fileContent, pageSize: pageContentSize)
        readingPageTexts = pages.map(\.text)
        readingSourcePageRanges = pages.map(\.range)
        applyReadingSpread(forSourcePage: keepSourcePage)
    }

    private func applyReadingSpread(forSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, readingPageTexts.count - 1))
        let target = clampedSource / 2
        let maxSpread = max(0, readingSpreadCount - 1)
        readingSpreadIndex = min(max(0, target), maxSpread)
    }

    private func restoreLearningScrollPositionFromReadingSpread() {
        let sourcePage = currentVisibleSourcePageIndex()
        guard readingSourcePageRanges.indices.contains(sourcePage) else { return }
        let trimmedRange = readingSourcePageRanges[sourcePage]
        guard trimmedRange.length > 0,
              let range = fileContentRange(fromTrimmedRange: trimmedRange) else { return }
        guard experienceMode == .learning else { return }
        if sourceTextScrollProxy.scrollToCharacterRange(range, anchor: .top) { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.experienceMode == .learning else { return }
            _ = self.sourceTextScrollProxy.scrollToCharacterRange(range, anchor: .top)
        }
    }

    private func fileContentRange(fromTrimmedRange range: NSRange) -> NSRange? {
        let ns = fileContent as NSString
        let trimmed = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let found = ns.range(of: trimmed)
        guard found.location != NSNotFound else { return nil }
        let location = found.location + range.location
        guard location < ns.length else { return nil }
        let length = min(range.length, ns.length - location)
        return NSRange(location: location, length: max(0, length))
    }

    func enterReadingMode(pageContentSize: CGSize) {
        guard canEnterReadingMode else { return }
        restoreReadingSpreadIndex()
        repaginateForReading(pageContentSize: pageContentSize)
        experienceMode = .reading
    }

    func exitReadingMode() {
        guard experienceMode == .reading else { return }
        experienceMode = .learning
        persistReadingSpreadIndex()
        DispatchQueue.main.async { [weak self] in
            self?.restoreLearningScrollPositionFromReadingSpread()
        }
    }

    func toggleReadingMode(pageContentSize: CGSize) {
        if experienceMode == .reading {
            exitReadingMode()
        } else {
            enterReadingMode(pageContentSize: pageContentSize)
        }
    }

    func canTurnReadingSpreadForward(from spreadIndex: Int) -> Bool {
        spreadIndex < readingSpreadCount - 1
    }

    func canTurnReadingSpreadBackward(from spreadIndex: Int) -> Bool {
        spreadIndex > 0
    }

    func turnReadingSpreadForward() {
        guard canTurnReadingSpreadForward(from: readingSpreadIndex) else { return }
        readingSpreadIndex += 1
    }

    func turnReadingSpreadBackward() {
        guard canTurnReadingSpreadBackward(from: readingSpreadIndex) else { return }
        readingSpreadIndex -= 1
    }

    private func readingPositionStorageKey() -> String? {
        if let path = currentFileURL?.path {
            return readingPositionKeyPrefix + path
        }
        if isDocumentOpen, fileName != "未命名" {
            return readingPositionKeyPrefix + "draft:" + fileName
        }
        return nil
    }

    private func readingSourcePageStorageKey() -> String? {
        if let path = currentFileURL?.path {
            return readingSourcePageKeyPrefix + path
        }
        if isDocumentOpen, fileName != "未命名" {
            return readingSourcePageKeyPrefix + "draft:" + fileName
        }
        return nil
    }

    private func restoreReadingSpreadIndex() {
        if let sourceKey = readingSourcePageStorageKey(),
           UserDefaults.standard.object(forKey: sourceKey) != nil {
            pendingReadingSourcePage = max(0, UserDefaults.standard.integer(forKey: sourceKey))
        } else if let spreadKey = readingPositionStorageKey() {
            let saved = UserDefaults.standard.integer(forKey: spreadKey)
            pendingReadingSourcePage = max(0, saved) * 2
        }
        if let sourcePage = pendingReadingSourcePage {
            readingSpreadIndex = sourcePage / 2
        }
    }

    private func persistReadingSpreadIndex() {
        let sourcePage = currentVisibleSourcePageIndex()
        if let sourceKey = readingSourcePageStorageKey() {
            UserDefaults.standard.set(sourcePage, forKey: sourceKey)
        }
        if let spreadKey = readingPositionStorageKey() {
            UserDefaults.standard.set(sourcePage / 2, forKey: spreadKey)
        }
    }

    var cursorContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: fileContent,
            selectedText: selectedText,
            history: readingPromptMessages,
            input: readingChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent
        )
    }

    var llmContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: fileContent,
            selectedText: selectedText,
            history: readingPromptMessages,
            input: readingChatInput,
            contextPercent: AppSettings.shared.bookContextPercent,
            limitCharacters: LLMContextLimits.maxCharacters
        )
    }

    var evolutionLiveToolLabel: String? {
        guard isRunning, showsExecutionTrace else { return nil }
        if let last = streamingToolSteps.last {
            let name = EvolutionToolLabels.localizedToolName(last.name)
            if last.status == .running {
                return "正在 \(name)…"
            }
            return "已完成 \(name)"
        }
        if !streamingToolStatus.isEmpty {
            return streamingToolStatus
        }
        if !streamingThinking.isEmpty {
            return "思考中…"
        }
        return nil
    }

    var evolutionContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: fileContent,
            selectedText: selectedText,
            history: evolutionPromptMessages,
            input: evolutionChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent,
            limitCharacters: CursorContextLimits.maxCharacters
        )
    }

    /// Real-time token budget for AI 进化（当前模型上下文窗口 vs 已消耗 + 预估占用）。
    var evolutionTokenBudget: ModelTokenBudget {
        evolutionTokenBudget(additionalPrompt: nil)
    }

    var canRunEvolution: Bool {
        !evolutionTokenBudget.isOverLimit
    }

    func evolutionTokenBudget(additionalPrompt: String?) -> ModelTokenBudget {
        let settings = AppSettings.shared
        return EvolutionTokenCalculator.budget(
            sessionConsumedTokens: evolutionSessionTokensConsumed,
            agentLiveContextTokens: evolutionAgentContextTokens,
            messages: evolutionPromptMessages,
            input: evolutionChatInput,
            streamingThinking: streamingThinking,
            streamingResponse: streamingResponse,
            toolSteps: streamingToolSteps,
            additionalPrompt: additionalPrompt,
            usesCursor: true,
            cursorModel: settings.resolvedCursorModel,
            llmModel: settings.model,
            llmProvider: settings.provider
        )
    }

    private func ensureEvolutionUsesCursor() {
        let settings = AppSettings.shared
        settings.reloadCursorAPIKey()
        if settings.explanationSource != .cursor {
            settings.explanationSource = .cursor
        }
    }

    private func guardEvolutionTokenLimit(for prompt: String, action: String) -> Bool {
        let budget = evolutionTokenBudget(additionalPrompt: prompt)
        if let message = budget.blockMessage(for: action) {
            errorMessage = message
            return false
        }
        return true
    }

    private func recordEvolutionTokenUsage(_ usage: LLMTokenUsage) {
        guard usage.totalTokens > 0 else { return }
        evolutionSessionTokensConsumed += usage.totalTokens
    }

    private func updateEvolutionAgentContextTokens(_ tokens: Int) {
        evolutionAgentContextTokens = max(0, tokens)
    }

    private func recordEvolutionCursorEstimate(
        prompt: String,
        history: [ChatMessage],
        reply: String,
        thinking: String?
    ) {
        var promptTokens = TokenEstimator.estimate(prompt)
        for message in history {
            promptTokens += TokenEstimator.estimate(message.content)
            if let messageThinking = message.thinking {
                promptTokens += TokenEstimator.estimate(messageThinking)
            }
        }
        let completionTokens = TokenEstimator.estimate(reply)
            + TokenEstimator.estimate(thinking ?? "")
        recordEvolutionTokenUsage(
            LLMTokenUsage(promptTokens: promptTokens, completionTokens: completionTokens)
        )
    }

    func selectRightPageTab(_ tab: RightPageTab) {
        guard rightPageTab != tab else { return }
        if tab == .aiEvolution {
            ensureEvolutionWelcome()
            ensureEvolutionUsesCursor()
        }
        rightPageTab = tab
    }

    func selectReadingAssistantPanel(_ panel: ReadingAssistantPanel) {
        guard readingAssistantPanel != panel else { return }
        readingAssistantPanel = panel
    }

    func openSettings() {
        selectRightPageTab(.aiEvolution)
        showSettings = true
    }

    func openBookSettings() {
        selectRightPageTab(.readingAssistant)
        showBookSettings = true
    }

    private func resetStreamingState() {
        streamingThinking = ""
        streamingResponse = ""
        streamingToolStatus = ""
        streamingToolSteps = []
        evolutionAgentContextTokens = 0
        showsExecutionTrace = false
        readingAssistantActiveTask = nil
    }

    private func beginRun(showsExecutionTrace: Bool) {
        isLoading = true
        isRunning = true
        suppressReplySpeech = false
        resetStreamingState()
        self.showsExecutionTrace = showsExecutionTrace
    }

    private func clearEvolutionExecutionState() {
        executingEvolutionCommandNumber = nil
        evolutionRunKind = .none
    }

    private func handleLLMStreamEvent(_ event: LLMStreamEvent) {
        switch event {
        case .textDelta(let delta):
            streamingResponse += delta
        case .done, .error:
            break
        }
    }

    private func handleCursorStreamEvent(_ event: CursorStreamEvent) {
        switch event {
        case .thinkingDelta(let delta):
            guard showsExecutionTrace else { return }
            streamingThinking += delta
        case .textDelta(let delta):
            streamingResponse += delta
        case .toolUpdate(let name, let status, let callId, let detail, let result, let error):
            guard showsExecutionTrace else { return }
            applyToolStepUpdate(
                name: name,
                status: status,
                callId: callId,
                detail: detail,
                result: result,
                error: error
            )
        case .statusUpdate(let status):
            guard showsExecutionTrace else { return }
            streamingToolStatus = status
        case .error(let message):
            errorMessage = message
        case .done(let text, let thinking):
            if streamingResponse.isEmpty, !text.isEmpty {
                streamingResponse = text
            }
            guard showsExecutionTrace else { return }
            if streamingThinking.isEmpty, let thinking, !thinking.isEmpty {
                streamingThinking = thinking
            }
        }
    }

    private func applyToolStepUpdate(
        name: String,
        status: String,
        callId: String?,
        detail: String?,
        result: String?,
        error: String?
    ) {
        let stepStatus: ExecutionStep.Status
        switch status {
        case "completed":
            stepStatus = .completed
        case "failed", "error":
            stepStatus = .failed
        default:
            stepStatus = .running
        }

        let completionTime = stepStatus == .running ? nil : Date()

        if stepStatus == .running {
            if let callId,
               let index = streamingToolSteps.lastIndex(where: { $0.callId == callId }) {
                let existing = streamingToolSteps[index]
                if existing.status == .running {
                    if let detail, !detail.isEmpty {
                        streamingToolSteps[index] = ExecutionStep(
                            id: existing.id,
                            callId: existing.callId,
                            name: name,
                            detail: detail,
                            status: .running,
                            startedAt: existing.startedAt
                        )
                    }
                    return
                }
            }
            streamingToolSteps.append(
                ExecutionStep(callId: callId, name: name, detail: detail, status: .running)
            )
        } else if let callId,
                  let index = streamingToolSteps.lastIndex(where: { $0.callId == callId }) {
            let existing = streamingToolSteps[index]
            streamingToolSteps[index] = ExecutionStep(
                id: existing.id,
                callId: existing.callId,
                name: existing.name,
                detail: detail ?? existing.detail,
                status: stepStatus,
                startedAt: existing.startedAt,
                completedAt: completionTime ?? existing.completedAt,
                resultSummary: result ?? existing.resultSummary,
                errorMessage: error ?? existing.errorMessage
            )
        } else if let index = streamingToolSteps.lastIndex(where: { $0.name == name && $0.status == .running }) {
            let existing = streamingToolSteps[index]
            streamingToolSteps[index] = ExecutionStep(
                id: existing.id,
                callId: existing.callId,
                name: existing.name,
                detail: detail ?? existing.detail,
                status: stepStatus,
                startedAt: existing.startedAt,
                completedAt: completionTime ?? existing.completedAt,
                resultSummary: result ?? existing.resultSummary,
                errorMessage: error ?? existing.errorMessage
            )
        } else {
            streamingToolSteps.append(
                ExecutionStep(
                    callId: callId,
                    name: name,
                    detail: detail,
                    status: stepStatus,
                    completedAt: completionTime,
                    resultSummary: result,
                    errorMessage: error
                )
            )
        }

        streamingToolStatus = stepStatus == .running
            ? "正在调用 \(EvolutionToolLabels.localizedToolName(name))…"
            : "已完成 \(EvolutionToolLabels.localizedToolName(name))"
    }

    private func resolvedToolStepsForMessage() -> [ExecutionStep]? {
        streamingToolSteps.isEmpty ? nil : streamingToolSteps
    }

    func stopCurrentRun() {
        let wasRunning = isRunning || activeTask != nil
        let stoppedEvolutionNumber = executingEvolutionCommandNumber
        suppressReplySpeech = true
        activeTask?.cancel()
        activeTask = nil
        cursorService.cancel()
        llmService.cancel()
        stopExplanationSpeech()
        isLoading = false
        isRunning = false
        streamingThinking = ""
        streamingResponse = ""
        streamingToolStatus = ""
        streamingToolSteps = []
        executingEvolutionCommandNumber = nil
        showsExecutionTrace = false
        if wasRunning, let number = stoppedEvolutionNumber {
            revertRunningOptimization(number: number)
        }
        if wasRunning {
            appendDisplayedMessage(
                ChatMessage(role: .assistant, content: "已停止执行。"),
                to: activePromptContext
            )
        }
    }

    private func revertRunningOptimization(number: Int) {
        guard let item = optimizationQueue.items.first(where: { $0.number == number }) else { return }
        if optimizationQueue.revertRunningToPending(id: item.id) {
            persistOptimizationQueue()
        }
    }

    func clearReadingContext() {
        guard !isRunning else { return }
        stopExplanationSpeech()
        readingPromptMessages = [Self.defaultWelcomeMessage]
        readingChatInput = ""
        explanationSelectionText = ""
        explanationPanelSelectedText = ""
        lastCommittedExplanationPanelSelectedText = ""
        errorMessage = nil
        if isDisplaying(.reading) {
            chatMessages = readingPromptMessages
        }
        persistChatSession()
    }

    func clearAIContext() {
        guard !isRunning else { return }
        evolutionPromptMessages = [Self.defaultEvolutionWelcomeMessage]
        evolutionChatInput = ""
        evolutionSessionTokensConsumed = 0
        evolutionAgentContextTokens = 0
        evolutionLastRequestId = nil
        EvolutionCursorSession.clear()
        errorMessage = nil
        if isDisplaying(.evolution) {
            chatMessages = evolutionPromptMessages
        }
        persistChatSession()
    }

    /// 将优化队列导出为本地编号命令文本文件。
    func saveEvolutionCommands() {
        guard !optimizationQueue.items.isEmpty else {
            errorMessage = "优化队列为空，无可保存的进化命令。"
            return
        }
        let formatted = NumberedNoteFormatter.format(optimizationQueue)
        exportEvolutionCommands(
            formatted,
            panelTitle: "保存进化命令",
            panelMessage: "将优化队列导出为编号命令文本（UTF-8）",
            successPrefix: "已保存进化命令"
        )
    }

    /// 从本地编号命令文本文件加载优化队列。
    func openEvolutionCommands() {
        guard !isRunning else { return }

        let panel = NSOpenPanel()
        panel.title = "打开进化命令"
        panel.message = "选择包含编号命令行的 UTF-8 文本文件"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let imported = OptimizationQueue.importFromNotes(text)
            guard !imported.items.isEmpty else {
                errorMessage = "文件中未找到有效的编号命令行（如「1、…」）。"
                return
            }
            if optimizationQueue.items.contains(where: { $0.status == .running }) {
                errorMessage = "当前有进化任务正在执行，请先停止后再打开。"
                return
            }
            if !optimizationQueue.items.isEmpty,
               !confirmReplaceOptimizationQueue() {
                return
            }

            optimizationQueue = imported
            persistOptimizationQueue()
            syncLeftPageWithEvolutionCommands(from: url, formatted: NumberedNoteFormatter.format(imported))
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            errorMessage = nil
            let count = imported.items.count
            showTransientSaveMessage("已打开 \(count) 条进化命令：\(url.lastPathComponent)")
        } catch {
            errorMessage = "无法打开进化命令：\(error.localizedDescription)"
        }
    }

    var canSaveEvolutionCommands: Bool {
        !optimizationQueue.items.isEmpty
    }

    var canOpenEvolutionCommands: Bool {
        !isRunning
    }

    var canClearReadingContext: Bool {
        hasExplanationContent
            || !readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canClearAIContext: Bool {
        hasEvolutionConversation
            || !evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || evolutionSessionTokensConsumed > 0
            || evolutionAgentContextTokens > 0
    }

    private var hasEvolutionConversation: Bool {
        evolutionPromptMessages.contains { !isEvolutionWelcomeMessage($0) }
    }

    func newDocument() {
        guard !isRunning else { return }
        guard confirmDiscardUnsavedIfNeeded() else { return }

        stopExplanationSpeech()
        fileContent = ""
        savedContent = ""
        fileName = "未命名"
        currentFileURL = nil
        isDocumentOpen = true
        isDirty = false
        readingPageTexts = []
        readingSourcePageRanges = []
        readingSpreadIndex = 0
        experienceMode = .learning
        selectedText = ""
        lastCommittedSelectionText = ""
        lastCommittedSelectionRange = nil
        selectedTextRange = nil
        readingPromptMessages = [Self.defaultWelcomeMessage]
        syncDisplayedChatMessages()
        readingChatInput = ""
        errorMessage = nil
        persistChatSession()
    }

    func openFile() {
        guard confirmDiscardUnsavedIfNeeded() else { return }

        let panel = NSOpenPanel()
        panel.title = "打开文本文件"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(at: url)
    }

    func openDroppedFile(at url: URL) {
        guard url.pathExtension.lowercased() == "txt" || url.pathExtension.isEmpty else {
            errorMessage = "仅支持打开 .txt 文本文件。"
            return
        }
        guard confirmDiscardUnsavedIfNeeded() else { return }
        loadFile(at: url)
    }

    @discardableResult
    func confirmDiscardUnsavedIfNeeded() -> Bool {
        guard isDirty else { return true }
        return AppGuard.confirmDiscardUnsavedChanges()
    }

    func loadFile(at url: URL, resetChat: Bool = true) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            fileContent = text
            savedContent = text
            isDirty = false
            fileName = url.lastPathComponent
            currentFileURL = url
            isDocumentOpen = true
            selectedText = ""
            lastCommittedSelectionText = ""
            lastCommittedSelectionRange = nil
            selectedTextRange = nil
            if resetChat {
                readingPromptMessages = [
                    ChatMessage(
                        role: .assistant,
                        content: "已打开「\(fileName)」。请在左页选中文字后使用「选择讲解」或「全文讲解」，或在下方输入问题让读书助手帮你解析。"
                    ),
                ]
                evolutionPromptMessages = []
                syncDisplayedChatMessages()
            }
            errorMessage = nil
            persistChatSession()
            refreshTranslationAlignmentAfterSourceChange()
        } catch {
            errorMessage = "无法读取文件：\(error.localizedDescription)"
        }
    }

    func save() {
        if let url = currentFileURL {
            writeContent(to: url)
            syncReadmeNotesIfNeeded()
        } else {
            saveReadmeNotes()
        }
    }

    func saveAs() {
        exportContent(
            fileContent,
            panelTitle: "另存为文本文件",
            panelMessage: "选择保存位置与文件名（UTF-8 文本）",
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName
            ),
            successPrefix: "已另存为"
        )
    }

    func saveSelectionAs() {
        let selection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            errorMessage = "请先在左页选中要导出的文字。"
            return
        }

        exportContent(
            selection,
            panelTitle: "导出选中文字",
            panelMessage: "将左页选中内容保存为新 .txt 文件",
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName,
                selectionSuffix: true
            ),
            successPrefix: "已导出选中"
        )
    }

    func updateAssistantMessage(id: UUID, content: String) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        guard chatMessages[index].content != content else { return }

        updatePromptMessage(id: id, content: content)
        var updated = chatMessages
        updated[index].content = content
        chatMessages = updated
    }

    func canEditExplanationMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && !isReadingWelcomeMessage(message)
    }

    func deleteChatMessage(id: UUID) {
        guard !isRunning else { return }
        let context = activePromptContext
        let messages = contextHistory(for: context)
        guard let message = messages.first(where: { $0.id == id }) else { return }
        let welcomeID = context == .reading
            ? Self.defaultWelcomeMessage.id
            : Self.defaultEvolutionWelcomeMessage.id
        guard messages.count > 1 || message.id != welcomeID else { return }

        if message.role == .assistant, isSpeakingExplanation {
            stopExplanationSpeech()
        }

        removePromptMessage(id: id, from: context)
        if isDisplaying(context) {
            chatMessages.removeAll { $0.id == id }
        }
    }

    func saveAssistantMessage(id: UUID) {
        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "当前 AI 输出为空，无法保存。"
            return
        }

        exportContent(
            content,
            panelTitle: "保存 AI 输出",
            panelMessage: "将右侧 AI 查询内容保存为 UTF-8 文本",
            suggestedName: assistantOutputFileName(for: message),
            successPrefix: "已保存 AI 输出"
        )
    }

    func readAssistantMessage(id: UUID) {
        if isSpeakingExplanation {
            stopExplanationSpeech()
            return
        }

        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "当前 AI 输出为空，无法朗读。"
            return
        }

        speakExplanation(content, source: .aiReply)
    }

    func openAssistantMessageFile() {
        let panel = NSOpenPanel()
        panel.title = "打开 AI 输出文本"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                errorMessage = "打开的 AI 输出文本为空。"
                return
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            let message = ChatMessage(role: .assistant, content: text)
            appendDisplayedMessage(message, to: .reading)
            errorMessage = nil
            showTransientSaveMessage("已打开 AI 输出 \(url.lastPathComponent)")
        } catch {
            errorMessage = "无法打开 AI 输出：\(error.localizedDescription)"
        }
    }

    private func exportContent(
        _ content: String,
        panelTitle: String,
        panelMessage: String,
        suggestedName: String,
        successPrefix: String
    ) {
        guard !content.isEmpty else { return }

        let directory = DocumentExporter.defaultDirectory(currentFileURL: currentFileURL)
        guard let destination = DocumentExporter.runSavePanel(
            title: panelTitle,
            message: panelMessage,
            suggestedName: suggestedName,
            directory: directory
        ) else { return }

        if FileManager.default.fileExists(atPath: destination.path),
           !AppGuard.confirmOverwriteExistingFile(at: destination) {
            return
        }

        do {
            try DocumentExporter.write(content, to: destination)
            if content == fileContent {
                currentFileURL = destination
                fileName = destination.lastPathComponent
                savedContent = fileContent
                isDirty = false
            }
            errorMessage = nil
            showTransientSaveMessage("\(successPrefix) \(destination.lastPathComponent)")
        } catch {
            errorMessage = "无法保存文件：\(error.localizedDescription)"
        }
    }

    private func exportEvolutionCommands(
        _ content: String,
        panelTitle: String,
        panelMessage: String,
        successPrefix: String
    ) {
        guard !content.isEmpty else { return }

        let directory = DocumentExporter.defaultDirectory(currentFileURL: currentFileURL)
        guard let destination = DocumentExporter.runSavePanel(
            title: panelTitle,
            message: panelMessage,
            suggestedName: DocumentExporter.evolutionCommandsSuggestedName,
            directory: directory
        ) else { return }

        if FileManager.default.fileExists(atPath: destination.path),
           !AppGuard.confirmOverwriteExistingFile(at: destination) {
            return
        }

        do {
            try DocumentExporter.write(content, to: destination)
            syncLeftPageWithEvolutionCommands(from: destination, formatted: content)
            errorMessage = nil
            let count = optimizationQueue.items.count
            showTransientSaveMessage("\(successPrefix) \(count) 条 → \(destination.lastPathComponent)")
        } catch {
            errorMessage = "无法保存进化命令：\(error.localizedDescription)"
        }
    }

    private func syncLeftPageWithEvolutionCommands(from url: URL, formatted: String) {
        fileContent = formatted
        savedContent = formatted
        fileName = url.lastPathComponent
        currentFileURL = url
        isDocumentOpen = true
        isDirty = false
        do {
            try readmeNotesStore.save(formatted)
        } catch {
            errorMessage = "无法同步命令笔记：\(error.localizedDescription)"
        }
    }

    /// 将优化队列格式化为左页编号命令（N、…）并同步展示与持久化。
    private func syncLeftPageFromOptimizationQueue() {
        guard !optimizationQueue.items.isEmpty else { return }
        let formatted = NumberedNoteFormatter.format(optimizationQueue)
        fileContent = formatted
        savedContent = formatted
        isDirty = false
        if !isDocumentOpen {
            isDocumentOpen = true
        }
        do {
            try readmeNotesStore.save(formatted)
        } catch {
            errorMessage = "无法同步命令笔记：\(error.localizedDescription)"
        }
        if let url = currentFileURL {
            try? DocumentExporter.write(formatted, to: url)
        }
    }

    /// 左页含编号命令行时回写优化队列，使手动编辑与进化队列保持一致。
    private func syncOptimizationQueueFromLeftPageIfNeeded() {
        guard !isRunning else { return }
        guard !optimizationQueue.items.contains(where: { $0.status == .running }) else { return }
        let imported = OptimizationQueue.importFromNotes(fileContent)
        guard !imported.items.isEmpty else { return }
        optimizationQueue = imported
        persistOptimizationQueue()
    }

    private func confirmReplaceOptimizationQueue() -> Bool {
        let alert = NSAlert()
        alert.messageText = "替换当前优化队列？"
        alert.informativeText = "打开文件将覆盖现有 \(optimizationQueue.items.count) 条进化命令。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func assistantOutputFileName(for message: ChatMessage) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "AI查询内容-\(formatter.string(from: message.timestamp)).txt"
    }

    private func showTransientSaveMessage(_ message: String) {
        lastSaveMessage = message
        saveMessageTask?.cancel()
        saveMessageTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lastSaveMessage = nil
        }
    }

    private func loadReadmeNotes() {
        let content = readmeNotesStore.loadInitialContent()
        guard !content.isEmpty else { return }

        fileContent = content
        savedContent = content
        fileName = "readme-notes.txt"
        currentFileURL = nil
        isDocumentOpen = true
        isDirty = false
    }

    private func saveReadmeNotes() {
        do {
            try readmeNotesStore.save(fileContent)
            savedContent = fileContent
            fileName = "readme-notes.txt"
            currentFileURL = nil
            isDirty = false
            errorMessage = nil
            syncOptimizationQueueFromLeftPageIfNeeded()
        } catch {
            errorMessage = "无法保存命令笔记：\(error.localizedDescription)"
        }
    }

    private func syncReadmeNotesIfNeeded() {
        guard fileName == "readme-notes.txt" || currentFileURL == nil else { return }
        do {
            try readmeNotesStore.save(fileContent)
        } catch {
            errorMessage = "无法同步命令笔记：\(error.localizedDescription)"
        }
    }

    private func writeContent(to url: URL) {
        do {
            try DocumentExporter.write(fileContent, to: url)
            currentFileURL = url
            fileName = url.lastPathComponent
            savedContent = fileContent
            isDirty = false
            errorMessage = nil
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            showTransientSaveMessage("已保存 \(url.lastPathComponent)")
        } catch {
            errorMessage = "无法保存文件：\(error.localizedDescription)"
        }
    }

    func updateSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            selectedText = trimmed
            selectedTextRange = range
            lastCommittedSelectionText = trimmed
            lastCommittedSelectionRange = range
        } else {
            selectedText = ""
            selectedTextRange = nil
        }
    }

    func updateLessonPlanSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            lessonPlanSelectedText = trimmed
            lastCommittedLessonPlanSelectedText = trimmed
        } else {
            lessonPlanSelectedText = ""
        }
    }

    func updateExplanationPanelSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            explanationPanelSelectedText = trimmed
            lastCommittedExplanationPanelSelectedText = trimmed
        } else {
            explanationPanelSelectedText = ""
        }
    }

    /// 当前可用于朗读/讲解的选区：实时选区优先，否则用最近一次有效选区。
    var effectiveSelectedText: String {
        let live = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveLessonPlanSelectedText: String {
        let live = lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveExplanationPanelSelectedText: String {
        let live = explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty
            || !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isSpeakingExplanation
    }

    func selectAllLeftPage() {
        guard !fileContent.isEmpty else {
            errorMessage = "当前没有可选中的文本。"
            return
        }
        leftSelectAllSignal = UUID()
    }

    func selectAllRightPage() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.translation)
        guard !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "当前翻译为空，无法全选。"
            return
        }
        rightSelectAllSignal = UUID()
    }

    var hasExplanationContent: Bool {
        !explanationTranscriptText().isEmpty
    }

    func explanationTranscriptText() -> String {
        readingPromptMessages
            .filter { !isReadingWelcomeMessage($0) }
            .map { message in
                let role = message.role == .user ? "用户" : "助手"
                return "【\(role)】\n\(message.content)"
            }
            .joined(separator: "\n\n")
    }

    func explanationSpeakableText() -> String {
        readingPromptMessages
            .filter { $0.role == .assistant && !isReadingWelcomeMessage($0) }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func newExplanationDocument() {
        guard !isRunning else { return }
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        stopExplanationSpeech()
        readingPromptMessages = [Self.defaultWelcomeMessage]
        chatMessages = readingPromptMessages
        readingChatInput = ""
        explanationSelectionText = ""
        explanationPanelSelectedText = ""
        lastCommittedExplanationPanelSelectedText = ""
        errorMessage = nil
        persistChatSession()
    }

    func clearExplanation() {
        guard !isRunning else { return }
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        guard hasExplanationContent else { return }
        stopExplanationSpeech()
        readingPromptMessages = [Self.defaultWelcomeMessage]
        chatMessages = readingPromptMessages
        readingChatInput = ""
        explanationSelectionText = ""
        explanationPanelSelectedText = ""
        lastCommittedExplanationPanelSelectedText = ""
        errorMessage = nil
        persistChatSession()
    }

    func saveExplanationDocument() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        persistChatSession()
        let content = explanationTranscriptText()
        guard !content.isEmpty else {
            errorMessage = "当前没有可保存的讲解内容。"
            return
        }
        exportContent(
            content,
            panelTitle: "保存讲解",
            panelMessage: "将讲解对话保存为 UTF-8 文本",
            suggestedName: explanationFileName(),
            successPrefix: "已保存讲解"
        )
    }

    func openExplanationDocument() {
        guard !isRunning else { return }
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let panel = NSOpenPanel()
        panel.title = "打开讲解内容"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                errorMessage = "打开的讲解文本为空。"
                return
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            applyImportedExplanationText(text)
            errorMessage = nil
            showTransientSaveMessage("已打开讲解 \(url.lastPathComponent)")
        } catch {
            errorMessage = "无法打开讲解内容：\(error.localizedDescription)"
        }
    }

    func selectAllExplanation() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        let text = explanationTranscriptText()
        guard !text.isEmpty else {
            errorMessage = "当前没有可选中的讲解内容。"
            return
        }
        explanationSelectionText = text
        explanationSelectAllSignal = UUID()
    }

    func readExplanationAloud() {
        readExplanationFullTextAloud()
    }

    func readOriginalFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        let text = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "当前没有可朗读的原文内容，请先输入或打开文本。"
            return
        }

        speakExplanation(text, source: .originalFull)
    }

    func readOriginalSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        let text = effectiveSelectedText
        guard !text.isEmpty else {
            errorMessage = "请先在左页选中要朗读的文字。"
            return
        }

        speakExplanation(text, source: .originalSelection)
    }

    func readTranslationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.translation)

        let text = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "当前翻译为空，请先生成或打开翻译内容。"
            return
        }

        speakExplanation(text, source: .translationFull)
    }

    func readTranslationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.translation)

        let text = effectiveLessonPlanSelectedText
        guard !text.isEmpty else {
            errorMessage = "请先在翻译区选中要朗读的文字。"
            return
        }

        speakExplanation(text, source: .translationSelection)
    }

    func readExplanationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let text = explanationSpeakableText()
        guard !text.isEmpty else {
            errorMessage = "当前没有可朗读的讲解内容。"
            return
        }

        speakExplanation(text, source: .explanationFull)
    }

    func readExplanationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        syncExplanationSelectionText()

        let text = effectiveExplanationPanelSelectedText
        guard !text.isEmpty else {
            errorMessage = "请先在讲解区选中要朗读的文字（可先点全选）。"
            return
        }

        speakExplanation(text, source: .explanationSelection)
    }

    @discardableResult
    private func toggleReadAloudIfSpeaking() -> Bool {
        if isSpeakingExplanation {
            stopExplanationSpeech()
            return true
        }
        return false
    }

    private func isReadingWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && message.content == ReadingAssistant.welcomeMessage
    }

    private func isEvolutionWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && message.content == EvolutionAssistant.welcomeMessage
    }

    private func explanationFileName() -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let base = stem.isEmpty || stem == "未命名" ? "文章" : stem
        return "\(base)-讲解.txt"
    }

    private func syncExplanationSelectionText() {
        explanationSelectionText = explanationTranscriptText()
    }

    private func applyImportedExplanationText(_ text: String) {
        let parsed = parseImportedExplanationMessages(text)
        readingPromptMessages = [Self.defaultWelcomeMessage] + parsed
        chatMessages = readingPromptMessages
        explanationSelectionText = explanationTranscriptText()
        persistChatSession()
    }

    private func parseImportedExplanationMessages(_ text: String) -> [ChatMessage] {
        let marker = #"【(用户|助手)】"#
        guard let regex = try? NSRegularExpression(pattern: marker) else {
            return defaultImportedExplanationMessages(for: text)
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return defaultImportedExplanationMessages(for: text)
        }

        var messages: [ChatMessage] = []
        for index in matches.indices {
            let match = matches[index]
            guard match.numberOfRanges > 1,
                  let roleRange = Range(match.range(at: 1), in: text) else { continue }

            let roleLabel = String(text[roleRange])
            let role: ChatMessage.Role = roleLabel == "用户" ? .user : .assistant
            let contentStart = match.range.upperBound
            let contentEnd = index + 1 < matches.count ? matches[index + 1].range.lowerBound : nsText.length
            guard contentEnd > contentStart else { continue }

            let raw = nsText.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
            let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            messages.append(ChatMessage(role: role, content: content))
        }

        return messages.isEmpty ? defaultImportedExplanationMessages(for: text) : messages
    }

    private func defaultImportedExplanationMessages(for text: String) -> [ChatMessage] {
        [
            ChatMessage(role: .user, content: "已导入讲解文稿"),
            ChatMessage(role: .assistant, content: text),
        ]
    }

    var evolutionStatusLabel: String? {
        SelfEvolution.statusLabel(from: optimizationQueue)
    }

    var evolutionItems: [OptimizationItem] {
        optimizationQueue.items.sorted { $0.number < $1.number }
    }

    var hasPendingOptimization: Bool {
        optimizationQueue.nextPending() != nil
    }

    var isAnalyzing: Bool {
        isRunning && evolutionRunKind == .analysis
    }

    /// 输入栏旁的运行状态：进化展示工具步骤，读书/名著补充仅展示简单进度。
    func runningStatusText(for mode: RightPageTab) -> String {
        guard isRunning else { return "" }
        if mode == .aiEvolution, showsExecutionTrace {
            if !streamingToolStatus.isEmpty { return streamingToolStatus }
            if let label = evolutionLiveToolLabel { return label }
            return "AI 进化执行中…"
        }
        return "处理中…"
    }

    /// AI 进化页是否展示 Agent 执行轨迹（Cursor）。
    var showsEvolutionExecutionTrace: Bool {
        AppSettings.shared.isCursorRunnable
    }

    func startEvolution() {
        selectRightPageTab(.aiEvolution)
        ensureEvolutionWelcome()
        ensureEvolutionUsesCursor()

        if let running = optimizationQueue.items.first(where: { $0.status == .running }) {
            _ = optimizationQueue.revertRunningToPending(id: running.id)
            persistOptimizationQueue()
        }

        guard let pending = optimizationQueue.nextPending() else {
            errorMessage = "请先点「分析优化」，或在队列中手写一条。"
            AutoEvolutionCoordinator.clearChain()
            return
        }

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        guard SelfEvolution.sourceProjectReady else {
            errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。请确认 \(SelfEvolution.sourceProjectPath()) 存在。"
            return
        }

        let projectPath = SelfEvolution.sourceProjectPath()
        let prompt = EvolutionPlanner.buildEvolutionPrompt(
            queue: optimizationQueue,
            pending: pending,
            projectPath: projectPath
        )
        guard guardEvolutionTokenLimit(for: prompt, action: "执行进化") else { return }

        guard optimizationQueue.markRunning(id: pending.id) else { return }
        persistOptimizationQueue()
        AutoEvolutionCoordinator.markChainActive()

        sendMessage(
            prompt,
            displayText: "自我进化 · 第 \(pending.number) 条",
            isEvolution: true,
            evolutionCommandNumber: pending.number,
            triggerEvolutionRebuild: true,
            evolutionRunKind: .evolution
        )
    }

    func analyzeOptimizations() {
        selectRightPageTab(.aiEvolution)
        ensureEvolutionWelcome()
        ensureEvolutionUsesCursor()
        guard !isRunning, !isEvolutionRebuilding else { return }

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }
        guard SelfEvolution.sourceProjectReady else {
            errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。请确认 \(SelfEvolution.sourceProjectPath()) 存在。"
            return
        }

        let direction = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !direction.isEmpty {
            evolutionChatInput = ""
        }

        let prompt = EvolutionAnalyzer.buildAnalysisPrompt(
            queue: optimizationQueue,
            projectPath: SelfEvolution.sourceProjectPath(),
            direction: direction.isEmpty ? nil : direction
        )
        guard guardEvolutionTokenLimit(for: prompt, action: "分析优化") else { return }

        evolutionRunKind = .analysis
        sendMessage(
            prompt,
            displayText: direction.isEmpty ? "分析优化" : "分析优化：\(direction)",
            isEvolution: true,
            evolutionCommandNumber: nil,
            triggerEvolutionRebuild: false,
            evolutionRunKind: .analysis
        )
    }

    func skipOptimization(id: UUID) {
        guard !isRunning else { return }
        if optimizationQueue.skip(id: id) {
            persistOptimizationQueue()
        }
    }

    func restoreOptimization(id: UUID) {
        guard !isRunning else { return }
        if optimizationQueue.restore(id: id) {
            persistOptimizationQueue()
        }
    }

    func deleteOptimization(id: UUID) {
        guard !isRunning else { return }
        optimizationQueue.remove(id: id)
        persistOptimizationQueue()
    }

    func pinOptimization(id: UUID) {
        guard !isRunning else { return }
        optimizationQueue.pin(id: id)
        persistOptimizationQueue()
    }

    func addUserOptimization(title: String) {
        guard !isRunning else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = optimizationQueue.addUserItem(title: trimmed)
        persistOptimizationQueue()
    }

    func explainSelection() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let selection = effectiveSelectedText
        guard !selection.isEmpty else {
            errorMessage = "请先在左页选中一段文字。"
            return
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        let context = surroundingContext(for: selection, in: fileContent)
        let prompt = """
        请讲解下面这段文字：

        【选中内容】
        \(selection)

        【上下文】
        \(context)
        """

        sendMessage(
            prompt,
            displayText: "选择讲解（\(selection.count) 字）",
            speakReplyWhenDone: true
        )
    }

    func explainFullText() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let fullText = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else {
            errorMessage = "请先在左页输入或打开文章内容。"
            return
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        let prompt = """
        请讲解下面这篇全文：

        【全文】
        \(fullText)
        """

        sendMessage(
            prompt,
            displayText: "全文讲解（\(fullText.count) 字）",
            speakReplyWhenDone: true
        )
    }

    func readSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        selectRightPageTab(.readingAssistant)

        let selected = effectiveSelectedText
        let fullText = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = selected.isEmpty ? fullText : selected
        guard !text.isEmpty else {
            errorMessage = "当前没有可朗读内容，请先输入或打开文本。"
            return
        }

        let source: SpeechSource = selected.isEmpty ? .originalFull : .originalSelection
        speakExplanation(text, source: source)
    }

    func readLessonPlanAloud() {
        readTranslationFullTextAloud()
    }

    func supplementClassicLiterature() {
        let trimmed = fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请先在左页粘贴或打开名著节选文本。"
            return
        }

        guard AppSettings.shared.isBookLLMConfigured else {
            errorMessage = "名著补充需配置读书大模型，请在 book 设置中选择本地模型。"
            return
        }

        let source = selectedText.isEmpty ? fileContent : selectedText
        let replacingSelection = !selectedText.isEmpty
        let displayText = replacingSelection
            ? "名著补充 · 选中 \(selectedText.count) 字"
            : "名著补充 · 全文 \(fileContent.count) 字"

        let userMessage = ChatMessage(role: .user, content: displayText)
        appendDisplayOnlyMessage(userMessage)
        beginRun(showsExecutionTrace: false)
        errorMessage = nil

        let prompt = ClassicLiteratureSupplement.buildPrompt(source: source, isSelection: replacingSelection)
        let llmMode = AIBookLLMPrompt.Mode.classicLiteratureSupplement
        let settings = AppSettings.shared
        let selectionRange = replacingSelection ? currentSelectionRange(matching: source) : nil

        activeTask?.cancel()
        activeTask = Task {
            do {
                var streamed = ""
                let reply = try await llmService.chat(
                    prompt: prompt,
                    history: llmMode.apiHistory,
                    configuration: settings.bookLLMConfiguration,
                    systemPrompt: llmMode.systemPrompt,
                    maxTokens: 8192,
                    onEvent: { [weak self] event in
                        Task { @MainActor in
                            guard let self else { return }
                            if case .textDelta(let delta) = event {
                                streamed += delta
                                self.streamingResponse = streamed
                                guard !replacingSelection else { return }
                                let preview = ClassicLiteratureSupplement.extractContent(from: streamed)
                                    ?? ClassicLiteratureSupplement.stripMarkers(from: streamed)
                                if !preview.isEmpty {
                                    self.fileContent = preview
                                }
                            }
                        }
                    }
                )

                guard !Task.isCancelled else { return }

                let finalText = ClassicLiteratureSupplement.extractContent(from: reply)
                    ?? ClassicLiteratureSupplement.stripMarkers(from: reply)
                applySupplementToLeftPage(finalText, selectionRange: selectionRange)
                persistLeftPage()

                appendDisplayOnlyMessage(
                    ChatMessage(
                        role: .assistant,
                        content: "名著补充完成，已写入左页（\(finalText.count) 字）并保存。"
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    let message = LLMServiceErrorPresenter.message(for: error, provider: settings.bookProvider)
                    errorMessage = message
                    appendDisplayOnlyMessage(
                        ChatMessage(role: .assistant, content: "名著补充失败：\(message)")
                    )
                }
            }
            isLoading = false
            isRunning = false
            streamingToolStatus = ""
            resetStreamingState()
        }
    }

    private func applySupplementToLeftPage(_ supplemented: String, selectionRange: Range<String.Index>?) {
        let trimmed = supplemented.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let range = selectionRange, isValidRange(range, in: fileContent) {
            fileContent.replaceSubrange(range, with: trimmed)
            selectedText = trimmed
            selectedTextRange = nil
        } else {
            fileContent = trimmed
            selectedText = ""
            selectedTextRange = nil
        }
    }

    private func currentSelectionRange(matching source: String) -> Range<String.Index>? {
        if let selectedTextRange,
           let range = Range(selectedTextRange, in: fileContent),
           String(fileContent[range]) == source {
            return range
        }

        let matches = ranges(of: source, in: fileContent)
        return matches.count == 1 ? matches[0] : nil
    }

    private func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<haystack.endIndex
        }
        return ranges
    }

    private func isValidRange(_ range: Range<String.Index>, in text: String) -> Bool {
        range.lowerBound >= text.startIndex && range.upperBound <= text.endIndex
    }

    private func persistLeftPage() {
        if let url = currentFileURL {
            writeContent(to: url)
        } else {
            saveReadmeNotes()
        }
    }

    func sendChatInput() {
        let text = readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        readingChatInput = ""
        refineLessonPlan(instruction: text)
    }

    func sendEvolutionChatInput() {
        let text = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        ensureEvolutionUsesCursor()
        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        evolutionChatInput = ""
        let prompt = buildEvolutionChatPrompt(for: text)
        guard guardEvolutionTokenLimit(for: prompt, action: "发送追问") else { return }
        sendMessage(
            prompt,
            displayText: text,
            isEvolution: true,
            triggerEvolutionRebuild: false,
            evolutionRunKind: .followUp
        )
    }

    func generateLessonPlan() {
        let source = lessonPlanSourceText()
        guard !source.isEmpty else {
            errorMessage = "请先在左页输入、打开或选中要翻译的文章内容。"
            return
        }
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.translation)
        runLessonPlanTask(
            displayText: "生成逐字翻译",
            mode: .wordByWord,
            prompt: buildLessonPlanPrompt(
                source: source,
                existingPlan: nil,
                instruction: nil,
                mode: .wordByWord
            )
        )
    }

    func refineLessonPlan(instruction: String? = nil) {
        let source = lessonPlanSourceText()
        guard !source.isEmpty else {
            errorMessage = "请先在左页输入、打开或选中要翻译的文章内容。"
            return
        }
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.translation)
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        runLessonPlanTask(
            displayText: "生成整段翻译",
            mode: .paragraph,
            prompt: buildLessonPlanPrompt(
                source: source,
                existingPlan: existingTranslationForPrompt(),
                instruction: trimmedInstruction?.isEmpty == false ? trimmedInstruction : nil,
                mode: .paragraph
            )
        )
    }

    func clearLessonPlan() {
        guard !isRunning else { return }
        isApplyingAlignment = true
        translationAlignment = nil
        lessonPlanContent = ""
        isApplyingAlignment = false
    }

    func saveLessonPlan() {
        let content = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            errorMessage = "当前翻译为空，无法保存。"
            return
        }
        exportContent(
            content,
            panelTitle: "保存翻译内容",
            panelMessage: "将右侧翻译内容保存为 UTF-8 文本",
            suggestedName: lessonPlanFileName(),
            successPrefix: "已保存翻译"
        )
    }

    func openLessonPlanFile() {
        let panel = NSOpenPanel()
        panel.title = "打开翻译内容"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            isApplyingAlignment = true
            lessonPlanContent = text
            isApplyingAlignment = false
            _ = alignTranslationWithSource(showFeedback: false)
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            errorMessage = nil
            showTransientSaveMessage("已打开翻译 \(url.lastPathComponent)")
        } catch {
            errorMessage = "无法打开翻译内容：\(error.localizedDescription)"
        }
    }

    func scheduleAutoEvolutionIfNeeded() {
        guard !didScheduleAutoEvolution else { return }
        didScheduleAutoEvolution = true

        let settings = AppSettings.shared
        let pending = optimizationQueue.items.filter { $0.status == .pending }.count
        guard AutoEvolutionCoordinator.shouldAutoStart(
            autoEvolutionEnabled: settings.autoEvolutionEnabled,
            isChainActive: AutoEvolutionCoordinator.isChainActive,
            pendingCount: pending
        ) else {
            if pending == 0 {
                AutoEvolutionCoordinator.clearChain()
            }
            return
        }

        autoEvolutionTask?.cancel()
        autoEvolutionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            guard let self, !self.isRunning else { return }
            guard self.optimizationQueue.nextPending() != nil else {
                AutoEvolutionCoordinator.clearChain()
                return
            }
            if AppGuard.evolutionSourceErrorMessage(for: settings) != nil { return }
            guard self.canRunEvolution else {
                AutoEvolutionCoordinator.clearChain()
                self.errorMessage = self.evolutionTokenBudget.blockMessage(for: "自动进化")
                return
            }
            self.startEvolution()
        }
    }

    private func sendMessage(
        _ prompt: String,
        displayText: String,
        isEvolution: Bool = false,
        evolutionCommandNumber: Int? = nil,
        speakReplyWhenDone: Bool = false,
        triggerEvolutionRebuild: Bool = false,
        evolutionRunKind: EvolutionRunKind = .none
    ) {
        let runKind = evolutionRunKind == .none
            ? (isEvolution ? EvolutionRunKind.evolution : .none)
            : evolutionRunKind
        let settings = AppSettings.shared
        let promptContext: PromptContext = runKind == .none ? .reading : .evolution
        let userMessage = ChatMessage(role: .user, content: displayText)
        appendDisplayedMessage(userMessage, to: promptContext)
        if runKind == .none {
            selectRightPageTab(.readingAssistant)
            selectReadingAssistantPanel(.explanation)
            readingAssistantActiveTask = .explanation
        }
        self.evolutionRunKind = runKind
        beginRun(showsExecutionTrace: runKind != .none)
        if runKind == .evolution {
            executingEvolutionCommandNumber = evolutionCommandNumber
        } else {
            executingEvolutionCommandNumber = nil
        }
        errorMessage = nil

        let history: [ChatMessage]
        let readingLLMMode: AIBookLLMPrompt.Mode?
        if runKind != .none {
            history = Array(apiHistory(for: promptContext).dropLast())
            readingLLMMode = nil
        } else {
            history = AIBookLLMPrompt.Mode.readingAssistant.apiHistory
            readingLLMMode = .readingAssistant
        }

        activeTask?.cancel()
        activeTask = Task {
            do {
                let outcome = try await fetchAssistantReply(
                    prompt: prompt,
                    history: history,
                    settings: settings,
                    evolutionRunKind: runKind,
                    llmMode: readingLLMMode
                )

                guard !Task.isCancelled else { return }
                let resolvedThinking = runKind != .none
                    ? (outcome.thinking ?? (streamingThinking.isEmpty ? nil : streamingThinking))
                    : nil
                let resolvedReply = outcome.text.isEmpty ? streamingResponse : outcome.text

                if let notice = outcome.fallbackNotice {
                    let noticeMessage = ChatMessage(role: .assistant, content: notice)
                    appendDisplayedMessage(noticeMessage, to: promptContext)
                }

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: resolvedReply,
                    thinking: resolvedThinking,
                    toolSteps: runKind != .none ? resolvedToolStepsForMessage() : nil
                )
                appendDisplayedMessage(assistantMessage, to: promptContext)

                if speakReplyWhenDone,
                   !suppressReplySpeech,
                   !Task.isCancelled,
                   !resolvedReply.isEmpty {
                    speakExplanation(resolvedReply, source: .aiReply)
                }

                if runKind == .analysis {
                    handleAnalysisCompletion(reply: resolvedReply)
                }

                if runKind == .evolution || runKind == .followUp {
                    recordEvolutionCursorEstimate(
                        prompt: prompt,
                        history: Array(history),
                        reply: resolvedReply,
                        thinking: resolvedThinking
                    )
                }

                if runKind == .evolution, triggerEvolutionRebuild {
                    let commandNumber = evolutionCommandNumber
                        ?? extractEvolutionCommandNumber(from: displayText)
                    applyEvolutionQueueUpdate(reply: resolvedReply, commandNumber: commandNumber)

                    guard let projectURL = SelfEvolution.sourceProjectDirectory() else {
                        errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。"
                        AutoEvolutionCoordinator.clearChain()
                        return
                    }

                    let projectPath = projectURL.path
                    let stillPending = optimizationQueue.nextPending() != nil
                    let continueChain = AppSettings.shared.autoEvolutionEnabled && stillPending

                    appendDisplayedMessage(
                        ChatMessage(
                            role: .assistant,
                            content: stillPending
                                ? "第 \(commandNumber ?? 0) 条进化已完成。正在自动升级并继续下一条…"
                                : "全部优化项已完成。正在自动升级并重启 AIBook…"
                        ),
                        to: .evolution
                    )
                    Task {
                        await self.handleEvolutionRebuild(
                            projectPath: projectPath,
                            continueChain: continueChain
                        )
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                if runKind == .evolution, let number = evolutionCommandNumber {
                    revertRunningOptimization(number: number)
                }
                if !(error is CancellationError) {
                    let message = message(for: error, isEvolution: runKind != .none)
                    errorMessage = message
                    let failureMessage = ChatMessage(role: .assistant, content: "解析失败：\(message)")
                    appendDisplayedMessage(failureMessage, to: promptContext)
                }
            }
            isLoading = false
            isRunning = false
            activeTask = nil
            resetStreamingState()
            clearEvolutionExecutionState()
        }
    }

    private func runLessonPlanTask(
        displayText: String,
        mode: TranslationAlignmentMode,
        prompt: String
    ) {
        let settings = AppSettings.shared
        if let configError = AppGuard.bookLLMErrorMessage(for: settings) {
            errorMessage = configError
            return
        }

        readingAssistantActiveTask = .translation
        beginRun(showsExecutionTrace: false)
        errorMessage = nil

        let llmMode = AIBookLLMPrompt.Mode.translation
        activeTask?.cancel()
        activeTask = Task {
            do {
                let outcome = try await fetchAssistantReply(
                    prompt: prompt,
                    history: llmMode.apiHistory,
                    settings: settings,
                    llmMode: llmMode
                )

                guard !Task.isCancelled else { return }
                let resolvedPlan = outcome.text.isEmpty ? streamingResponse : outcome.text
                applyTranslationResult(resolvedPlan, title: displayText, mode: mode)
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    let message = LLMServiceErrorPresenter.message(for: error, provider: AppSettings.shared.provider)
                    errorMessage = message
                }
            }
            isLoading = false
            isRunning = false
            activeTask = nil
            resetStreamingState()
        }
    }

    private func applyTranslationResult(
        _ result: String,
        title: String,
        mode: TranslationAlignmentMode
    ) {
        let source = lessonPlanSourceText()
        var alignment = TranslationAlignmentBuilder.build(from: result, source: source, mode: mode)
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)
        alignment.blocks = rendered.blocks
        alignment.isStale = false

        isApplyingAlignment = true
        translationAlignment = alignment
        lessonPlanContent = rendered.content
        isApplyingAlignment = false
        syncTranslationScrollPresentation()
        persistChatSession()
    }

    @discardableResult
    func alignTranslationWithSource(showFeedback: Bool = true) -> Bool {
        if translationAlignment?.isLocked == true {
            if showFeedback {
                errorMessage = "对照关系已锁定。请先解锁后再整体对齐。"
            }
            return false
        }

        let source = lessonPlanSourceText()
        let content = lessonPlanContent
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if showFeedback {
                errorMessage = "请先在左页打开或输入原文，并在右页加载或输入译文。"
            }
            return false
        }

        guard let outcome = TranslationAligner.align(source: source, translation: content) else {
            if showFeedback {
                errorMessage = "无法从当前译文建立对齐。请确认译文为整段/逐字格式，或与原文段落数相近。"
            }
            return false
        }

        translationScrollSync.resetAnchors()
        isApplyingAlignment = true
        if let rendered = outcome.renderedContent {
            lessonPlanContent = rendered
        }
        translationAlignment = outcome.alignment
        isApplyingAlignment = false
        syncTranslationScrollPresentation()
        persistChatSession()
        errorMessage = nil

        if showFeedback {
            let alignment = outcome.alignment
            let resegmented = outcome.renderedContent != nil ? "，译文已按原文段落重新分割" : ""
            showTransientSaveMessage(
                "已对齐 \(alignment.anchoredBlockCount)/\(alignment.blocks.count) 段\(resegmented)"
            )
        }
        return true
    }

    private func rebuildTranslationAlignment(from content: String) -> TranslationAlignment? {
        let source = lessonPlanSourceText()
        guard !source.isEmpty else { return nil }
        return TranslationAligner.align(source: source, translation: content)?.alignment
    }

    private func refreshTranslationAlignmentAfterSourceChange() {
        if !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = alignTranslationWithSource(showFeedback: false)
        }
    }

    private func repairCollapsedParagraphAlignmentIfNeeded() {
        _ = alignTranslationWithSource(showFeedback: false)
    }

    func handleSourceTextScroll(visibleRange: NSRange) {
        guard shouldSyncTranslationScroll,
              let alignment = alignmentForScrollSync() else { return }
        translationScrollSync.sourceDidScroll(visibleRange: visibleRange, alignment: alignment)
    }

    func handleTranslationTextScroll(visibleRange: NSRange) {
        guard shouldSyncTranslationScroll,
              !showsTranslationTableView,
              let alignment = alignmentForScrollSync() else { return }
        translationScrollSync.translationDidScroll(visibleRange: visibleRange, alignment: alignment)
    }

    func handleTranslationTableVisibleBlock(_ block: TranslationBlock) {
        guard canUseTranslationTableView,
              let alignment = alignmentForScrollSync() else { return }
        translationTableHighlightedBlockID = block.id
        let mappedBlock = alignment.blocks.first(where: { $0.id == block.id }) ?? block
        guard mappedBlock.isAnchored else { return }
        let sourceRange = mappedBlock.sourceRange
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.sourceTextScrollProxy.scrollToCharacterRange(sourceRange, anchor: .top) {
                self.sourceTextScrollProxy.highlightRange(sourceRange)
            }
        }
    }

    func lockTranslationAlignment() {
        guard var alignment = translationAlignment, !alignment.isStale else { return }
        alignment.isLocked = true
        translationAlignment = alignment
        persistChatSession()
        showTransientSaveMessage("对照关系已锁定并保存")
    }

    func unlockTranslationAlignment() {
        guard var alignment = translationAlignment, alignment.isLocked else { return }
        alignment.isLocked = false
        translationAlignment = alignment
        persistChatSession()
        showTransientSaveMessage("已解锁，可继续整体调整")
    }

    func updateTranslationTableBlock(
        id: UUID,
        sourceText: String? = nil,
        translationText: String? = nil,
        note: String? = nil
    ) {
        guard !isRunning, var alignment = translationAlignment, !alignment.isStale else { return }
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }

        let source = lessonPlanSourceText()
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isApplyingAlignment = true
        defer { isApplyingAlignment = false }

        var blocks = alignment.blocks
        var block = blocks[index]

        if let sourceText {
            let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            block.sourceText = trimmed
            if block.level != .summary {
                let searchStart = sourceSearchStart(forBlockAt: index, in: blocks)
                let range = TranslationAlignmentBuilder.reanchorSourceText(
                    trimmed,
                    in: source,
                    searchStart: searchStart
                )
                block.sourceLocation = range.location
                block.sourceLength = range.length
            }
        }

        if let translationText {
            block.translationText = translationText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let note {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            block.note = trimmed.isEmpty ? nil : trimmed
        }

        blocks[index] = block
        alignment.blocks = blocks

        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: translationDisplayTitle())
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        translationAlignment = alignment
        lessonPlanContent = rendered.content
        syncTranslationScrollPresentation()
        persistChatSession()
    }

    func splitTranslationTableBlock(
        id: UUID,
        translationBefore: String,
        translationAfter: String
    ) {
        guard !isRunning, var alignment = translationAlignment, !alignment.isStale else { return }
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }

        let block = alignment.blocks[index]
        guard block.level != .summary else { return }

        let before = translationBefore.trimmingCharacters(in: .newlines)
        let after = translationAfter.trimmingCharacters(in: .newlines)
        guard !before.isEmpty || !after.isEmpty else { return }

        guard let nextIndex = nextTranslationTableEntryIndex(after: index, in: alignment.blocks) else {
            showTransientSaveMessage("已是最后一行，无法向下合并")
            return
        }

        isApplyingAlignment = true
        defer { isApplyingAlignment = false }

        var blocks = alignment.blocks
        var current = blocks[index]
        current.translationText = before
        blocks[index] = current

        var next = blocks[nextIndex]
        if after.isEmpty {
            next.translationText = next.translationText.trimmingCharacters(in: .newlines)
        } else if next.translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.translationText = after
        } else {
            next.translationText = after + next.translationText
        }
        blocks[nextIndex] = next

        alignment.blocks = blocks
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: translationDisplayTitle())
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        translationAlignment = alignment
        lessonPlanContent = rendered.content
        translationTableFocusTranslationBlockID = next.id
        syncTranslationScrollPresentation()
        persistChatSession()
    }

    private func nextTranslationTableEntryIndex(after index: Int, in blocks: [TranslationBlock]) -> Int? {
        let current = blocks[index]
        guard current.level != .summary else { return nil }

        let entries = blocks
            .enumerated()
            .filter { $0.element.level != .summary }
            .sorted { $0.element.order < $1.element.order }

        guard let currentEntryIndex = entries.firstIndex(where: { $0.element.id == current.id }) else {
            return nil
        }
        let nextEntryIndex = entries.index(after: currentEntryIndex)
        guard nextEntryIndex < entries.endIndex else { return nil }
        return entries[nextEntryIndex].offset
    }

    private func sourceSearchStart(forBlockAt index: Int, in blocks: [TranslationBlock]) -> Int {
        let currentOrder = blocks[index].order
        let previous = blocks
            .filter { $0.level != .summary && $0.order < currentOrder && $0.isAnchored }
            .sorted { $0.order < $1.order }
            .last
        guard let previous else { return 0 }
        return previous.sourceRange.location + previous.sourceRange.length
    }

    private func translationDisplayTitle() -> String? {
        let first = lessonPlanContent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard first.hasPrefix("【"), first.hasSuffix("】"), first.count > 2 else { return nil }
        return String(first.dropFirst().dropLast())
    }

    var showsTranslationTableView: Bool {
        translationTableViewEnabled && canUseTranslationTableView
    }

    var canUseTranslationTableView: Bool {
        guard let alignment = translationAlignment, !alignment.isStale else {
            return false
        }
        return alignment.blocks.contains {
            $0.level == .word || $0.level == .phrase || $0.level == .paragraph
        }
    }

    private func syncTranslationScrollPresentation() {
        translationScrollSync.isEnabled = showsTranslationTableView
        translationScrollSync.usesTableView = showsTranslationTableView
        translationScrollSync.onScrollTranslationToBlock = showsTranslationTableView
            ? { [weak self] blockID in
                self?.translationTableScrollTargetID = blockID
                self?.translationTableHighlightedBlockID = blockID
            }
            : nil
        if !showsTranslationTableView {
            translationTableScrollTargetID = nil
            translationTableHighlightedBlockID = nil
        }
    }

    private func alignmentForScrollSync() -> TranslationAlignment? {
        guard var alignment = translationAlignment, !alignment.isStale else { return nil }
        let offset = sourceRangeOffsetInFileContent()
        if offset != 0 {
            for index in alignment.blocks.indices where alignment.blocks[index].sourceLength > 0 {
                alignment.blocks[index].sourceLocation += offset
            }
        }
        alignment.blocks = TranslationContentFormatter.indexTranslationRanges(
            in: lessonPlanContent,
            blocks: alignment.blocks,
            mode: alignment.mode
        )
        return alignment
    }

    private func sourceRangeOffsetInFileContent() -> Int {
        guard let hash = translationAlignment?.sourceContentHash else { return 0 }
        let fileNS = fileContent as NSString

        func offset(of source: String, preferring range: NSRange?) -> Int {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return 0 }
            if let range,
               range.location != NSNotFound,
               range.length > 0,
               NSMaxRange(range) <= fileNS.length {
                let slice = fileNS.substring(with: range) as NSString
                let local = slice.range(of: trimmed)
                if local.location != NSNotFound {
                    return range.location + local.location
                }
            }
            let found = fileNS.range(of: trimmed)
            return found.location == NSNotFound ? 0 : found.location
        }

        if TranslationSourceHasher.hash(selectedText) == hash {
            return offset(of: selectedText, preferring: selectedTextRange ?? lastCommittedSelectionRange)
        }
        if TranslationSourceHasher.hash(lastCommittedSelectionText) == hash {
            return offset(of: lastCommittedSelectionText, preferring: lastCommittedSelectionRange)
        }
        if TranslationSourceHasher.hash(fileContent) == hash {
            return offset(of: fileContent, preferring: nil)
        }
        return offset(of: lessonPlanSourceText(), preferring: lastCommittedSelectionRange)
    }

    private var shouldSyncTranslationScroll: Bool {
        experienceMode == .learning
            && rightPageTab == .readingAssistant
            && readingAssistantPanel == .translation
            && showsTranslationTableView
            && translationAlignment != nil
            && translationAlignment?.isStale == false
    }

    private func refreshTranslationAlignmentStaleState(fromManualEdit: Bool = false) {
        guard var alignment = translationAlignment else { return }

        if sourceHashMatches(alignment) {
            if alignment.isStale, !fromManualEdit {
                alignment.isStale = false
                translationAlignment = alignment
            } else if fromManualEdit,
                      !TranslationContentFormatter.matchesRenderedContent(alignment, content: lessonPlanContent) {
                guard !alignment.isStale else { return }
                alignment.isStale = true
                translationAlignment = alignment
                translationScrollSync.resetAnchors()
            }
            return
        }

        guard !alignment.isStale else { return }
        alignment.isStale = true
        translationAlignment = alignment
        translationScrollSync.resetAnchors()
    }

    private func sourceHashMatches(_ alignment: TranslationAlignment) -> Bool {
        let candidates = [fileContent, selectedText, lastCommittedSelectionText]
        return candidates.contains { TranslationSourceHasher.hash($0) == alignment.sourceContentHash }
    }

    private func lessonPlanSourceText() -> String {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty { return selected }
        return fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func existingTranslationForPrompt() -> String? {
        if let alignment = translationAlignment, !alignment.blocks.isEmpty {
            let texts = alignment.blocks
                .filter { $0.level != .summary }
                .sorted { $0.order < $1.order }
                .map { $0.translationText.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !texts.isEmpty {
                return texts.joined(separator: "\n\n")
            }
        }

        let content = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        if content.contains("\"translationText\"") || content.contains("```json") {
            return nil
        }
        return content
    }

    private func buildLessonPlanPrompt(
        source: String,
        existingPlan: String?,
        instruction: String?,
        mode: TranslationAlignmentMode
    ) -> String {
        TranslationPromptBuilder.build(
            source: source,
            existingPlan: existingPlan,
            instruction: instruction,
            mode: mode
        )
    }

    private func lessonPlanFileName() -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let base = stem.isEmpty || stem == "未命名" ? "文章" : stem
        return "\(base)-翻译.txt"
    }

    private func handleEvolutionRebuild(projectPath: String, continueChain: Bool = true) async {
        await MainActor.run {
            isEvolutionRebuilding = true
            evolutionRebuildStatus = "正在执行 scripts/build-and-install.sh …"
        }

        let result = await AppRelauncher.rebuildAndRelaunch(
            projectPath: projectPath,
            continueChain: continueChain
        )

        await MainActor.run {
            isEvolutionRebuilding = false
            evolutionRebuildStatus = ""
        }

        guard !result.succeeded else { return }

        await MainActor.run {
            let message = result.message ?? "自动升级构建失败，请查看构建脚本输出。"
            errorMessage = message
            appendDisplayedMessage(
                ChatMessage(
                    role: .assistant,
                    content: "自动升级构建失败，已停止重启链路：\(message)"
                ),
                to: .evolution
            )
        }
    }

    private struct AssistantReplyOutcome {
        let text: String
        let thinking: String?
        let fallbackNotice: String?
    }

    private func message(for error: Error, isEvolution: Bool) -> String {
        if isEvolution {
            if let llmError = error as? LLMServiceError,
               let description = llmError.errorDescription {
                return description
            }
            if case CursorServiceError.needsAuthentication = error {
                return """
                Cursor 需要有效的 API Key（AuthenticationError）。
                请在「进化设置」填写 Cursor API Key，或创建 ai-book/cursor.local.env。
                进化功能仅使用 Cursor 本地 Agent，不使用读书助手的大模型 API。
                """
            }
            if let localized = error as? LocalizedError,
               let description = localized.errorDescription,
               !description.isEmpty {
                let lower = description.lowercased()
                if lower.contains("api key") || lower.contains("authentication") {
                    return """
                    \(description)

                    提示：进化功能使用 Cursor 本地 Agent。请在「进化设置」配置 Cursor API Key，勿使用 book 设置中的 DeepSeek 等 API Key。
                    """
                }
                return description
            }
            return error.localizedDescription
        }
        return LLMServiceErrorPresenter.message(
            for: error,
            provider: AppSettings.shared.bookProvider
        )
    }

    private func fetchAssistantReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        evolutionRunKind: EvolutionRunKind = .none,
        llmMode: AIBookLLMPrompt.Mode? = nil
    ) async throws -> AssistantReplyOutcome {
        let resolvedSystemPrompt: String
        switch evolutionRunKind {
        case .analysis:
            resolvedSystemPrompt = EvolutionAnalyzer.analysisSystemPrompt
        case .evolution, .followUp:
            resolvedSystemPrompt = EvolutionAssistant.systemPrompt
        case .none:
            resolvedSystemPrompt = llmMode?.systemPrompt ?? ReadingAssistant.systemPrompt
        }
        let isEvolutionTask = evolutionRunKind != .none
        let readingConfiguration = settings.bookLLMConfiguration

        if isEvolutionTask {
            if let configError = AppGuard.evolutionSourceErrorMessage(for: settings) {
                throw EvolutionServiceError.notConfigured(configError)
            }
            return try await fetchCursorReply(
                prompt: prompt,
                history: history,
                settings: settings,
                systemInstruction: resolvedSystemPrompt,
                evolutionRunKind: evolutionRunKind
            )
        }

        guard settings.isBookLLMConfigured else {
            throw LLMServiceError.missingAPIKey(provider: settings.bookProvider)
        }

        let llmText = try await fetchLLMReply(
            prompt: prompt,
            history: history,
            configuration: readingConfiguration,
            systemPrompt: resolvedSystemPrompt
        )
        return AssistantReplyOutcome(text: llmText, thinking: nil, fallbackNotice: nil)
    }

    private func fetchCursorReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        systemInstruction: String,
        evolutionRunKind: EvolutionRunKind
    ) async throws -> AssistantReplyOutcome {
        guard let cursorConfig = settings.cursorConfiguration else {
            throw CursorServiceError.bridgeNotFound
        }

        let sessionMode: CursorSessionMode = evolutionRunKind == .analysis ? .analysis : .evolution
        let freshAgent: Bool
        let agentId: String?
        let closeAgentAfterRun: Bool
        let autoAuthorize: Bool

        switch evolutionRunKind {
        case .analysis:
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = true
            autoAuthorize = false
        case .evolution:
            EvolutionCursorSession.clear()
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = false
            autoAuthorize = true
        case .followUp:
            freshAgent = false
            agentId = EvolutionCursorSession.agentId
            closeAgentAfterRun = false
            autoAuthorize = true
        case .none:
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = false
            autoAuthorize = false
        }

        let result = try await cursorService.chat(
            message: prompt,
            history: history,
            configuration: cursorConfig,
            systemInstruction: systemInstruction,
            autoAuthorize: autoAuthorize,
            sessionMode: sessionMode,
            freshAgent: freshAgent,
            agentId: agentId,
            closeAgentAfterRun: closeAgentAfterRun,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleCursorStreamEvent(event)
                }
            }
        )

        if let usage = result.usage {
            recordEvolutionTokenUsage(usage)
        }
        if let agentId = result.agentId, !agentId.isEmpty, !closeAgentAfterRun {
            EvolutionCursorSession.save(agentId: agentId, requestId: result.requestId)
        }
        if closeAgentAfterRun {
            EvolutionCursorSession.clear()
        }
        if let requestId = result.requestId {
            evolutionLastRequestId = requestId
        }

        return AssistantReplyOutcome(text: result.text, thinking: result.thinking, fallbackNotice: nil)
    }

    private func fetchLLMReply(
        prompt: String,
        history: [ChatMessage],
        configuration: LLMConfiguration,
        systemPrompt: String
    ) async throws -> String {
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: configuration.provider)
        }

        return try await llmService.chat(
            prompt: prompt,
            history: history,
            configuration: configuration,
            systemPrompt: systemPrompt,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleLLMStreamEvent(event)
                }
            }
        )
    }

    private func buildChatPrompt(for question: String) -> String {
        let contextPercent = AppSettings.shared.bookContextPercent
        var sections: [String] = []

        if !fileContent.isEmpty {
            let focus = selectedText.isEmpty ? nil : selectedText
            let excerpt = CursorContextCalculator.excerpt(
                from: fileContent,
                percent: contextPercent,
                focus: focus
            )
            let anchorHint = focus != nil ? "，围绕选中内容" : ""
            sections.append("【当前阅读文本节选（\(Int(contextPercent))%\(anchorHint)）】\n\(excerpt)")
        }

        if !selectedText.isEmpty {
            sections.append("【当前选中内容】\n\(selectedText)")
        }

        sections.append("【用户问题】\n\(question)")
        return sections.joined(separator: "\n\n")
    }

    private func surroundingContext(for selection: String, in content: String) -> String {
        let percent = AppSettings.shared.bookContextPercent
        let radius = max(Int(Double(content.count) * percent / 100.0 / 2.0), 300)
        guard let range = content.range(of: selection) else {
            return CursorContextCalculator.excerpt(from: content, percent: percent)
        }

        let start = content.index(range.lowerBound, offsetBy: -radius, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: radius, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[start ..< end])
    }

    private func buildEvolutionChatPrompt(for question: String) -> String {
        let queueSummary = optimizationQueue.items
            .sorted { $0.number < $1.number }
            .map { item in
                let mark: String
                switch item.status {
                case .completed: mark = "✓"
                case .running: mark = "▶"
                case .skipped: mark = "—"
                case .pending: mark = "○"
                }
                return "\(mark) #\(item.number) \(item.title)"
            }
            .joined(separator: "\n")

        let definition = SelfEvolution.productDefinition
            .map { "- \($0)" }
            .joined(separator: "\n")

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

        return body
    }

    private func apiHistory(for context: PromptContext) -> [ChatMessage] {
        contextHistory(for: context).filter { message in
            switch context {
            case .reading:
                if message.content.hasPrefix("名著补充") { return false }
                if message.content.hasPrefix("右页是你的读书助手") { return false }
                if isTranslationHistoryMessage(message) { return false }
                return true
            case .evolution:
                guard message.role == .assistant else { return true }
                return !message.content.hasPrefix("这是 AI 进化选项卡")
            }
        }
    }

    private func isTranslationHistoryMessage(_ message: ChatMessage) -> Bool {
        let content = message.content
        return content.hasPrefix("生成逐字翻译")
            || content.hasPrefix("生成整段翻译")
            || content.contains("【生成逐字翻译】")
            || content.contains("【生成整段翻译】")
    }

    private func contextHistory(for context: PromptContext) -> [ChatMessage] {
        switch context {
        case .reading:
            return readingPromptMessages
        case .evolution:
            return evolutionPromptMessages
        }
    }

    private func appendPromptMessage(_ message: ChatMessage, to context: PromptContext) {
        switch context {
        case .reading:
            readingPromptMessages.append(message)
            syncExplanationSelectionText()
        case .evolution:
            evolutionPromptMessages.append(message)
        }
    }

    private func updatePromptMessage(id: UUID, content: String) {
        if let index = readingPromptMessages.firstIndex(where: { $0.id == id }) {
            readingPromptMessages[index].content = content
            syncExplanationSelectionText()
        }
        if let index = evolutionPromptMessages.firstIndex(where: { $0.id == id }) {
            evolutionPromptMessages[index].content = content
        }
    }

    private func removePromptMessage(id: UUID, from context: PromptContext) {
        switch context {
        case .reading:
            readingPromptMessages.removeAll { $0.id == id }
            syncExplanationSelectionText()
        case .evolution:
            evolutionPromptMessages.removeAll { $0.id == id }
        }
    }

    private var activePromptContext: PromptContext {
        rightPageTab == .readingAssistant ? .reading : .evolution
    }

    private func isDisplaying(_ context: PromptContext) -> Bool {
        switch (rightPageTab, context) {
        case (.readingAssistant, .reading), (.aiEvolution, .evolution):
            return true
        default:
            return false
        }
    }

    private func appendDisplayedMessage(_ message: ChatMessage, to context: PromptContext) {
        appendPromptMessage(message, to: context)
        if isDisplaying(context) {
            chatMessages.append(message)
        }
    }

    /// 仅更新当前界面，不写入对话历史（避免跨模式污染 API 上下文）。
    private func appendDisplayOnlyMessage(_ message: ChatMessage) {
        if isDisplaying(.reading) {
            chatMessages.append(message)
        }
    }

    private func ensureEvolutionWelcome() {
        if evolutionPromptMessages.isEmpty {
            evolutionPromptMessages = [Self.defaultEvolutionWelcomeMessage]
        }
    }

    private func syncDisplayedChatMessages() {
        chatMessages = contextHistory(for: activePromptContext)
    }

    private func restoreChatSession() {
        isRestoringSession = true
        defer { isRestoringSession = false }

        let session: PersistedChatSession?
        do {
            session = try chatSessionStore.load()
        } catch {
            errorMessage = "无法恢复上次对话：\(error.localizedDescription)"
            session = nil
        }

        guard let session, !session.messages.isEmpty else {
            readingPromptMessages = [Self.defaultWelcomeMessage]
            ensureEvolutionWelcome()
            syncDisplayedChatMessages()
            return
        }

        readingPromptMessages = session.readingMessages ?? session.messages
        evolutionPromptMessages = session.evolutionMessages ?? [Self.defaultEvolutionWelcomeMessage]
        if evolutionPromptMessages.isEmpty {
            ensureEvolutionWelcome()
        }
        readingChatInput = session.readingChatInput ?? session.chatInput
        evolutionChatInput = session.evolutionChatInput ?? ""
        if let tabName = session.rightPageTab,
           let tab = RightPageTab(rawValue: tabName) {
            rightPageTab = tab
        }
        lessonPlanContent = session.lessonPlanContent ?? ""
        translationAlignment = session.translationAlignment
        if translationAlignment == nil,
           !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translationAlignment = rebuildTranslationAlignment(from: lessonPlanContent)
        }
        repairCollapsedParagraphAlignmentIfNeeded()
        if let tableViewEnabled = session.translationTableViewEnabled, tableViewEnabled {
            translationTableViewEnabled = canUseTranslationTableView
        }
        syncTranslationScrollPresentation()
        if let panelName = session.readingAssistantPanel,
           let panel = ReadingAssistantPanel(rawValue: panelName) {
            readingAssistantPanel = panel
        }
        syncDisplayedChatMessages()
        syncExplanationSelectionText()

        if let path = session.lastOpenedFilePath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                loadFile(at: url, resetChat: false)
            }
        }
        repairCollapsedParagraphAlignmentIfNeeded()
    }

    private func persistChatSession() {
        guard !isRestoringSession else { return }
        do {
            try chatSessionStore.save(
                readingMessages: readingPromptMessages,
                evolutionMessages: evolutionPromptMessages,
                readingChatInput: readingChatInput,
                evolutionChatInput: evolutionChatInput,
                rightPageTab: rightPageTab,
                readingAssistantPanel: readingAssistantPanel,
                lastOpenedFilePath: currentFileURL?.path,
                lessonPlanContent: lessonPlanContent,
                translationAlignment: translationAlignment,
                translationTableViewEnabled: translationTableViewEnabled
            )
        } catch {
            errorMessage = "无法保存对话会话：\(error.localizedDescription)"
        }
    }

    private func applyEvolutionQueueUpdate(reply: String, commandNumber: Int?) {
        guard let number = commandNumber,
              let item = optimizationQueue.items.first(where: { $0.number == number })
        else { return }

        let summary = EvolutionPlanner.parseCompletionSummary(from: reply, number: number)
            ?? "第 \(number) 条自我进化已执行。"

        if item.status == .running {
            _ = optimizationQueue.markCompleted(id: item.id, summary: summary)
        } else if let index = optimizationQueue.items.firstIndex(where: { $0.id == item.id }) {
            optimizationQueue.items[index].status = .completed
            optimizationQueue.items[index].completionSummary = summary
            optimizationQueue.updatedAt = Date()
        }
        persistOptimizationQueue()
        syncLeftPageFromOptimizationQueue()
    }

    private func handleAnalysisCompletion(reply: String) {
        if let projectPath = SelfEvolution.sourceProjectDirectory()?.path,
           !gitWorkingTreeIsClean(at: projectPath) {
            appendDisplayedMessage(
                ChatMessage(
                    role: .assistant,
                    content: "分析过程修改了源码，已放弃入队。请用 git 恢复后重试。"
                ),
                to: .evolution
            )
            return
        }

        let drafts = EvolutionAnalyzer.parseItems(from: reply)
        if drafts.isEmpty {
            appendDisplayedMessage(
                ChatMessage(role: .assistant, content: "未发现新的优化项。"),
                to: .evolution
            )
            return
        }

        let report = optimizationQueue.merge(drafts: drafts)
        persistOptimizationQueue()
        syncLeftPageFromOptimizationQueue()
        appendDisplayedMessage(
            ChatMessage(role: .assistant, content: report.summaryChinese),
            to: .evolution
        )
        UserDefaults.standard.removeObject(forKey: "evolutionUtilityTab")
    }

    private func gitWorkingTreeIsClean(at projectPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", projectPath, "status", "--porcelain"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return true }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return true
        }
    }

    private func extractEvolutionCommandNumber(from displayText: String) -> Int? {
        let pattern = #"第\s*(\d+)\s*条"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: displayText,
                range: NSRange(displayText.startIndex..., in: displayText)
              ),
              let range = Range(match.range(at: 1), in: displayText)
        else { return nil }
        return Int(displayText[range])
    }

    private var speakingRefreshTask: Task<Void, Never>?
    private var suppressReplySpeech = false

    private func speakExplanation(_ text: String, source: SpeechSource, preferLowLatency: Bool = false) {
        let settings = AppSettings.shared
        let units = SpeechTextSanitizer.speechUnits(
            for: text,
            mode: settings.speechLanguageMode
        )
        guard !units.isEmpty else {
            errorMessage = "无法朗读：当前文本处理后没有可合成的内容。"
            return
        }

        ExplanationSpeechReader.shared.speak(text, preferLowLatency: preferLowLatency)
        isSpeakingExplanation = true
        isExplanationSpeechPaused = false
        currentSpeechSource = source
        scheduleSpeakingStatusRefresh()
    }

    func toggleExplanationSpeechPause() {
        let reader = ExplanationSpeechReader.shared
        if reader.isPaused {
            reader.resume()
        } else if reader.isBusy {
            reader.pause()
        }
        syncExplanationSpeechState()
    }

    func stopExplanationSpeech() {
        speakingRefreshTask?.cancel()
        ExplanationSpeechReader.shared.stop()
        isSpeakingExplanation = false
        isExplanationSpeechPaused = false
        currentSpeechSource = nil
    }

    private func syncExplanationSpeechState() {
        let reader = ExplanationSpeechReader.shared
        isExplanationSpeechPaused = reader.isPaused
        isSpeakingExplanation = reader.isBusy
    }

    private func scheduleSpeakingStatusRefresh() {
        speakingRefreshTask?.cancel()
        speakingRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.syncExplanationSpeechState()
                guard ExplanationSpeechReader.shared.isBusy else { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func scheduleAutoSaveIfNotes() {
        guard isEditingNotes, isDirty, !isRestoringSession else { return }

        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveReadmeNotes()
        }
    }
}

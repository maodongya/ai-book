import AIBookEvolution
import AppKit
import Combine
import Foundation

// Note: ReadingViewModel orchestrates child sessions.

@MainActor
/// 双页读书编排：左页原文、右页讲解/翻译/进化，以及 AI 与朗读请求的状态机。
final class ReadingViewModel: ObservableObject {
    static let untitledMarker = "未命名"

    struct AssistantReplyOutcome {
        let text: String
        let thinking: String?
        let fallbackNotice: String?
    }

    let document = ReadingDocumentSession()
    let mode = ReadingModeSession()
    let translation = ReadingTranslationSession()
    let assistant = ReadingAssistantSession()
    let evolution = ReadingEvolutionSession()

    @Published var rightPageTab: RightPageTab = .readingAssistant {
        didSet {
            guard !isRestoringSession else { return }
            syncDisplayedChatMessages()
            persistChatSession()
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

    let llmService = LLMService()
    let cursorService = CursorService()
    private let chatSessionStore = ChatSessionStore.shared
    var isRestoringSession = false
    var activeTask: Task<Void, Never>?
    var suppressReplySpeech = false
    private var cancellables = Set<AnyCancellable>()


    private var messageOrchestrator: ReadingMessageOrchestrator!

    init() {
        document.host = self
        mode.host = self
        translation.host = self
        assistant.host = self
        evolution.host = self
        wireSessionChangeForwarding()
        translation.translationScrollSync.sourceView = translation.sourceTextScrollProxy
        translation.translationScrollSync.translationView = translation.translationTextScrollProxy
        translation.syncTranslationScrollPresentation()
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in
            self?.assistant.syncExplanationSpeechState()
        }
        document.loadReadmeNotes()
        evolution.loadOptimizationQueue()
        evolution.ensureEvolutionWelcome()
        restoreChatSession()
        syncDisplayedChatMessages()
        translation.refreshTranslationAlignmentStaleState()
        persistChatSession()
        document.restoreDirectoryBrowserSessions()
        messageOrchestrator = ReadingMessageOrchestrator()
        messageOrchestrator.host = self
    }

    private func wireSessionChangeForwarding() {
        document.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        mode.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        translation.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        assistant.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        evolution.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }


    var cursorContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: assistant.readingPromptMessages,
            input: assistant.readingChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent
        )
    }

    var llmContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: assistant.readingPromptMessages,
            input: assistant.readingChatInput,
            contextPercent: AppSettings.shared.bookContextPercent,
            limitCharacters: LLMContextLimits.maxCharacters
        )
    }

    var evolutionLiveToolLabel: String? {
        guard isRunning, evolution.showsExecutionTrace else { return nil }
        if let last = streamingToolSteps.last {
            let name = EvolutionToolLabels.localizedToolName(last.name)
            if last.status == .running {
                return BookL10n.format("vm.tool.running", name)
            }
            return BookL10n.format("vm.tool.done", name)
        }
        if !streamingToolStatus.isEmpty { return streamingToolStatus }
        if !streamingThinking.isEmpty { return BookL10n.string("vm.thinking") }
        return nil
    }

    var evolutionContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: evolution.evolutionPromptMessages,
            input: evolution.evolutionChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent,
            limitCharacters: CursorContextLimits.maxCharacters
        )
    }

    var evolutionTokenBudget: ModelTokenBudget {
        evolution.evolutionTokenBudget(additionalPrompt: nil)
    }

    var canRunEvolution: Bool { !evolutionTokenBudget.isOverLimit }

    var showsEvolutionExecutionTrace: Bool { AppSettings.shared.isCursorRunnable }

    var isAnalyzing: Bool { isRunning && evolution.evolutionRunKind == .analysis }

    var canSaveEvolutionCommands: Bool { !evolution.optimizationQueue.items.isEmpty }
    var canOpenEvolutionCommands: Bool { !isRunning }

    var canClearReadingContext: Bool {
        assistant.hasExplanationContent
            || !assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canClearAIContext: Bool {
        evolution.hasEvolutionConversation
            || !evolution.evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || evolution.evolutionSessionTokensConsumed > 0
            || evolution.evolutionAgentContextTokens > 0
    }



    func resetStreamingState() { messageOrchestrator.resetStreamingState() }
    func beginRun(showsExecutionTrace: Bool) { messageOrchestrator.beginRun(showsExecutionTrace: showsExecutionTrace) }
    func handleLLMStreamEvent(_ event: LLMStreamEvent) { messageOrchestrator.handleLLMStreamEvent(event) }
    func handleCursorStreamEvent(_ event: CursorStreamEvent) { messageOrchestrator.handleCursorStreamEvent(event) }
    func applyToolStepUpdate(name: String, status: String, callId: String?, detail: String?, result: String?, error: String?) {
        messageOrchestrator.applyToolStepUpdate(name: name, status: status, callId: callId, detail: detail, result: result, error: error)
    }
    func resolvedToolStepsForMessage() -> [ExecutionStep]? { messageOrchestrator.resolvedToolStepsForMessage() }
    func sendMessage(_ prompt: String, displayText: String, isEvolution: Bool = false, evolutionCommandNumber: Int? = nil, speakReplyWhenDone: Bool = false, triggerEvolutionRebuild: Bool = false, evolutionRunKind: ReadingEvolutionRunKind = .none) {
        messageOrchestrator.sendMessage(prompt, displayText: displayText, isEvolution: isEvolution, evolutionCommandNumber: evolutionCommandNumber, speakReplyWhenDone: speakReplyWhenDone, triggerEvolutionRebuild: triggerEvolutionRebuild, evolutionRunKind: evolutionRunKind)
    }
    func fetchAssistantReply(prompt: String, history: [ChatMessage], settings: AppSettings, evolutionRunKind: ReadingEvolutionRunKind = .none, llmMode: AIBookLLMPrompt.Mode? = nil) async throws -> AssistantReplyOutcome {
        try await messageOrchestrator.fetchAssistantReply(prompt: prompt, history: history, settings: settings, evolutionRunKind: evolutionRunKind, llmMode: llmMode)
    }
    func fetchCursorReply(prompt: String, history: [ChatMessage], settings: AppSettings, systemInstruction: String, evolutionRunKind: ReadingEvolutionRunKind) async throws -> AssistantReplyOutcome {
        try await messageOrchestrator.fetchCursorReply(prompt: prompt, history: history, settings: settings, systemInstruction: systemInstruction, evolutionRunKind: evolutionRunKind)
    }
    func fetchLLMReply(prompt: String, history: [ChatMessage], configuration: LLMConfiguration, systemPrompt: String) async throws -> String {
        try await messageOrchestrator.fetchLLMReply(prompt: prompt, history: history, configuration: configuration, systemPrompt: systemPrompt)
    }


    func onAppear() {
        evolution.scheduleAutoEvolutionIfNeeded()
    }


    func selectRightPageTab(_ tab: RightPageTab) {
        guard rightPageTab != tab else { return }
        if tab == .aiEvolution {
            evolution.ensureEvolutionWelcome()
            evolution.ensureEvolutionUsesCursor()
        }
        rightPageTab = tab
    }


    func openSettings() {
        selectRightPageTab(.aiEvolution)
        showSettings = true
    }


    func openBookSettings() {
        selectRightPageTab(.readingAssistant)
        showBookSettings = true
    }


    func openUserManual() {
        showUserManual = true
    }


    func stopCurrentRun() {
        let wasRunning = isRunning || activeTask != nil
        let stoppedEvolutionNumber = evolution.executingEvolutionCommandNumber
        suppressReplySpeech = true
        activeTask?.cancel()
        activeTask = nil
        cursorService.cancel()
        llmService.cancel()
        assistant.stopExplanationSpeech()
        isLoading = false
        isRunning = false
        streamingThinking = ""
        streamingResponse = ""
        streamingToolStatus = ""
        streamingToolSteps = []
        evolution.executingEvolutionCommandNumber = nil
        evolution.showsExecutionTrace = false
        if wasRunning, let number = stoppedEvolutionNumber {
            evolution.revertRunningOptimization(number: number)
        }
        if wasRunning {
            appendDisplayedMessage(
                ChatMessage(role: .assistant, content: BookL10n.string("vm.stopped")),
                to: activePromptContext
            )
        }
    }

    func applyLanguageChange() {
        if evolution.evolutionPromptMessages.count == 1,
           evolution.evolutionPromptMessages[0].role == .assistant,
           BookL10nMarkers.isEvolutionWelcome(evolution.evolutionPromptMessages[0].content) {
            let existing = evolution.evolutionPromptMessages[0]
            evolution.evolutionPromptMessages = [
                ChatMessage(id: existing.id, role: .assistant, content: EvolutionAssistant.welcomeMessage),
            ]
        }
        syncDisplayedChatMessages()
    }


    func clearReadingContext() {
        guard !isRunning else { return }
        assistant.stopExplanationSpeech()
        assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
        assistant.readingChatInput = ""
        assistant.explanationSelectionText = ""
        assistant.explanationPanelSelectedText = ""
        document.lastCommittedExplanationPanelSelectedText = ""
        errorMessage = nil
        if isDisplaying(.reading) {
            assistant.chatMessages = assistant.readingPromptMessages
        }
        persistChatSession()
    }


    func clearAIContext() {
        guard !isRunning else { return }
        evolution.evolutionPromptMessages = [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]
        evolution.evolutionChatInput = ""
        evolution.evolutionSessionTokensConsumed = 0
        evolution.evolutionAgentContextTokens = 0
        evolution.evolutionLastRequestId = nil
        EvolutionCursorSession.clear()
        errorMessage = nil
        if isDisplaying(.evolution) {
            assistant.chatMessages = evolution.evolutionPromptMessages
        }
        persistChatSession()
    }

    /// 将优化队列导出为本地编号命令文本文件。

    func runningStatusText(for mode: RightPageTab) -> String {
        guard isRunning else { return "" }
        if mode == .aiEvolution, evolution.showsExecutionTrace {
            if !streamingToolStatus.isEmpty { return streamingToolStatus }
            if let label = evolutionLiveToolLabel { return label }
            return BookL10n.string("vm.evolutionRunning")
        }
        return BookL10n.string("vm.processing")
    }



    func apiHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        contextHistory(for: context).filter { message in
            switch context {
            case .reading:
                if BookL10nMarkers.isClassicSupplementIntro(message.content) { return false }
                if BookL10nMarkers.isReadingAssistantWelcome(message.content) { return false }
                if assistant.isTranslationHistoryMessage(message) { return false }
                return true
            case .evolution:
                guard message.role == .assistant else { return true }
                return !BookL10nMarkers.isEvolutionWelcome(message.content)
            }
        }
    }


    func contextHistory(for context: ReadingPromptContext) -> [ChatMessage] {
        switch context {
        case .reading:
            return assistant.readingPromptMessages
        case .evolution:
            return evolution.evolutionPromptMessages
        }
    }


    func appendPromptMessage(_ message: ChatMessage, to context: ReadingPromptContext) {
        switch context {
        case .reading:
            assistant.readingPromptMessages.append(message)
            assistant.syncExplanationSelectionText()
        case .evolution:
            evolution.evolutionPromptMessages.append(message)
        }
    }


    func updatePromptMessage(id: UUID, content: String) {
        if let index = assistant.readingPromptMessages.firstIndex(where: { $0.id == id }) {
            assistant.readingPromptMessages[index].content = content
            assistant.syncExplanationSelectionText()
        }
        if let index = evolution.evolutionPromptMessages.firstIndex(where: { $0.id == id }) {
            evolution.evolutionPromptMessages[index].content = content
        }
    }


    func removePromptMessage(id: UUID, from context: ReadingPromptContext) {
        switch context {
        case .reading:
            assistant.readingPromptMessages.removeAll { $0.id == id }
            assistant.syncExplanationSelectionText()
        case .evolution:
            evolution.evolutionPromptMessages.removeAll { $0.id == id }
        }
    }

    var activePromptContext: ReadingPromptContext {
        rightPageTab == .readingAssistant ? .reading : .evolution
    }


    func isDisplaying(_ context: ReadingPromptContext) -> Bool {
        switch (rightPageTab, context) {
        case (.readingAssistant, .reading), (.aiEvolution, .evolution):
            return true
        default:
            return false
        }
    }


    func appendDisplayedMessage(_ message: ChatMessage, to context: ReadingPromptContext) {
        appendPromptMessage(message, to: context)
        if isDisplaying(context) {
            assistant.chatMessages.append(message)
        }
    }

    /// 仅更新当前界面，不写入对话历史（避免跨模式污染 API 上下文）。


    func syncDisplayedChatMessages() {
        assistant.chatMessages = contextHistory(for: activePromptContext)
    }


    func restoreChatSession() {
        isRestoringSession = true
        defer { isRestoringSession = false }

        let session: PersistedChatSession?
        do {
            session = try chatSessionStore.load()
        } catch {
            errorMessage = BookL10n.format("vm.error.restoreChat", error.localizedDescription)
            session = nil
        }

        guard let session, !session.messages.isEmpty else {
            assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
            evolution.ensureEvolutionWelcome()
            syncDisplayedChatMessages()
            return
        }

        assistant.readingPromptMessages = session.readingMessages ?? session.messages
        evolution.evolutionPromptMessages = session.evolutionMessages ?? [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]
        if evolution.evolutionPromptMessages.isEmpty {
            evolution.ensureEvolutionWelcome()
        }
        assistant.readingChatInput = session.readingChatInput ?? session.chatInput
        evolution.evolutionChatInput = session.evolutionChatInput ?? ""
        if let tabName = session.rightPageTab,
           let tab = RightPageTab(rawValue: tabName) {
            rightPageTab = tab
        }
        translation.lessonPlanContent = session.lessonPlanContent ?? ""
        translation.translationAlignment = session.translationAlignment
        if translation.translationAlignment == nil,
           !translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translation.translationAlignment = translation.rebuildTranslationAlignment(from: translation.lessonPlanContent)
        }
        translation.repairCollapsedParagraphAlignmentIfNeeded()
        if let tableViewEnabled = session.translationTableViewEnabled, tableViewEnabled {
            translation.translationTableViewEnabled = translation.canUseTranslationTableView
        }
        translation.syncTranslationScrollPresentation()
        if let panelName = session.readingAssistantPanel,
           let panel = ReadingAssistantPanel.fromPersisted(panelName) {
            assistant.readingAssistantPanel = panel
        }
        syncDisplayedChatMessages()
        assistant.syncExplanationSelectionText()

        if let path = session.lastOpenedFilePath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                document.loadFile(at: url, resetChat: false)
            }
        }
        translation.repairCollapsedParagraphAlignmentIfNeeded()
    }


    func persistChatSession() {
        guard !isRestoringSession else { return }
        do {
            try chatSessionStore.save(
                readingMessages: assistant.readingPromptMessages,
                evolutionMessages: evolution.evolutionPromptMessages,
                readingChatInput: assistant.readingChatInput,
                evolutionChatInput: evolution.evolutionChatInput,
                rightPageTab: rightPageTab,
                readingAssistantPanel: assistant.readingAssistantPanel,
                lastOpenedFilePath: document.currentFileURL?.path,
                lessonPlanContent: translation.lessonPlanContent,
                translationAlignment: translation.translationAlignment,
                translationTableViewEnabled: translation.translationTableViewEnabled
            )
        } catch {
            errorMessage = BookL10n.format("vm.error.saveChat", error.localizedDescription)
        }
    }
}

import AppKit
import Foundation

@MainActor
final class ReadingViewModel: ObservableObject {
    private enum PromptContext {
        case reading
        case evolution
    }

    @Published var fileContent = "" {
        didSet {
            isDirty = fileContent != savedContent
            scheduleAutoSaveIfNotes()
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
        didSet { persistChatSession() }
    }
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
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published private(set) var isSpeakingExplanation = false
    @Published private(set) var isExplanationSpeechPaused = false
    @Published private(set) var lastSaveMessage: String?

    private let llmService = LLMService()
    private let llmEvolutionAgent = LLMEvolutionAgent()
    private let cursorService = CursorService()
    private let chatSessionStore = ChatSessionStore.shared
    private let readmeNotesStore = ReadmeNotesStore.shared
    private var currentFileURL: URL?
    private var savedContent = ""
    private var selectedTextRange: NSRange?
    private var isRestoringSession = false
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
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in
            self?.syncExplanationSpeechState()
        }
        loadReadmeNotes()
        ensureEvolutionWelcome()
        restoreChatSession()
        syncDisplayedChatMessages()
    }

    func onAppear() {
        scheduleAutoEvolutionIfNeeded()
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
            contextPercent: AppSettings.shared.llmContextPercent,
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
        let settings = AppSettings.shared
        let usesLLM = settings.explanationSource == .llm
            || (settings.explanationSource == .cursor && !settings.isCursorRunnable && settings.isLLMConfigured)
        return CursorContextCalculator.usage(
            fileContent: fileContent,
            selectedText: selectedText,
            history: evolutionPromptMessages,
            input: evolutionChatInput,
            contextPercent: usesLLM ? settings.llmContextPercent : settings.cursorContextPercent,
            limitCharacters: usesLLM ? LLMContextLimits.maxCharacters : CursorContextLimits.maxCharacters
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
        let usesCursor = settings.explanationSource == .cursor && settings.isCursorRunnable
        return EvolutionTokenCalculator.budget(
            sessionConsumedTokens: evolutionSessionTokensConsumed,
            agentLiveContextTokens: evolutionAgentContextTokens,
            messages: evolutionPromptMessages,
            input: evolutionChatInput,
            streamingThinking: streamingThinking,
            streamingResponse: streamingResponse,
            toolSteps: streamingToolSteps,
            additionalPrompt: additionalPrompt,
            usesCursor: usesCursor,
            cursorModel: settings.resolvedCursorModel,
            llmModel: settings.model,
            llmProvider: settings.provider
        )
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
        suppressReplySpeech = true
        activeTask?.cancel()
        activeTask = nil
        cursorService.cancel()
        llmService.cancel()
        llmEvolutionAgent.cancel()
        stopExplanationSpeech()
        isLoading = false
        isRunning = false
        streamingThinking = ""
        streamingResponse = ""
        streamingToolStatus = ""
        streamingToolSteps = []
        executingEvolutionCommandNumber = nil
        showsExecutionTrace = false
        if wasRunning {
            appendDisplayedMessage(
                ChatMessage(role: .assistant, content: "已停止执行。"),
                to: activePromptContext
            )
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
        errorMessage = nil
        if isDisplaying(.evolution) {
            chatMessages = evolutionPromptMessages
        }
        persistChatSession()
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
                        content: "已打开「\(fileName)」。请在左页选中文字后使用「选择讲解」或「全文讲解」，或在下方输入问题让 \(AppSettings.shared.explanationSource.rawValue) 帮你解析。"
                    ),
                ]
                evolutionPromptMessages = []
                syncDisplayedChatMessages()
            }
            errorMessage = nil
            persistChatSession()
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

        var updated = chatMessages
        updated[index].content = content
        chatMessages = updated
        updatePromptMessage(id: id, content: content)
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

        speakExplanation(content)
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

        speakExplanation(text)
    }

    func readOriginalSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        let text = effectiveSelectedText
        guard !text.isEmpty else {
            errorMessage = "请先在左页选中要朗读的文字。"
            return
        }

        speakExplanation(text)
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

        speakExplanation(text)
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

        speakExplanation(text)
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

        speakExplanation(text)
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

        speakExplanation(text)
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
        SelfEvolution.statusLabel(from: fileContent)
    }

    var evolutionCommands: [EvolutionPlanner.Command] {
        EvolutionPlanner.parseCommands(from: fileContent)
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

    /// AI 进化页是否展示 Agent 执行轨迹（Cursor 或 LLM 本地工具模式）。
    var showsEvolutionExecutionTrace: Bool {
        let settings = AppSettings.shared
        switch settings.explanationSource {
        case .cursor:
            return settings.isCursorRunnable
        case .llm:
            return settings.isLLMConfigured
        }
    }

    func startEvolution() {
        selectRightPageTab(.aiEvolution)
        ensureEvolutionWelcome()

        let commands = EvolutionPlanner.parseCommands(from: fileContent)
        guard let pending = EvolutionPlanner.nextPending(from: fileContent) else {
            guard !commands.isEmpty else {
                errorMessage = "左页没有找到编号命令（格式如「16、…」）。"
                return
            }
            AutoEvolutionCoordinator.clearChain()
            restartWhenEvolutionQueueEmpty()
            return
        }

        if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        guard SelfEvolution.sourceProjectReady else {
            errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。请确认 \(SelfEvolution.sourceProjectPath()) 存在。"
            return
        }

        let projectPath = SelfEvolution.sourceProjectPath()
        let prompt = EvolutionPlanner.buildEvolutionPrompt(
            allCommands: commands,
            pending: pending,
            projectPath: projectPath
        )
        guard guardEvolutionTokenLimit(for: prompt, action: "执行进化") else { return }
        sendMessage(
            prompt,
            displayText: "自我进化 · 第 \(pending.number) 条",
            isEvolution: true,
            evolutionCommandNumber: pending.number,
            triggerEvolutionRebuild: true
        )
    }

    private func restartWhenEvolutionQueueEmpty() {
        guard let projectURL = SelfEvolution.sourceProjectDirectory() else {
            errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。"
            return
        }

        errorMessage = nil
        appendDisplayedMessage(
            ChatMessage(
                role: .assistant,
                content: "左页命令均已标记完成，没有待进化项。正在重新打包并重启 AIBook…"
            ),
            to: .evolution
        )
        let projectPath = projectURL.path
        Task {
            await handleEvolutionRebuild(projectPath: projectPath)
        }
    }

    func explainSelection() {
        selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let selection = effectiveSelectedText
        guard !selection.isEmpty else {
            errorMessage = "请先在左页选中一段文字。"
            return
        }

        if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
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

        if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
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

        speakExplanation(text)
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

        guard AppSettings.shared.isLLMConfigured else {
            errorMessage = "名著补充需配置大模型 API，请在设置中填写 API Key。"
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
                    configuration: settings.llmConfiguration,
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
                    let message = LLMServiceErrorPresenter.message(for: error, provider: settings.provider)
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

        if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
            errorMessage = configError
            return
        }

        readingChatInput = ""
        refineLessonPlan(instruction: text)
    }

    func sendEvolutionChatInput() {
        let text = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
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
            triggerEvolutionRebuild: false
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
            prompt: buildLessonPlanPrompt(source: source, existingPlan: nil, instruction: nil, mode: .wordByWord)
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
        let existing = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        runLessonPlanTask(
            displayText: "生成整段翻译",
            prompt: buildLessonPlanPrompt(
                source: source,
                existingPlan: existing.isEmpty ? nil : existing,
                instruction: trimmedInstruction?.isEmpty == false ? trimmedInstruction : nil,
                mode: .paragraph
            )
        )
    }

    func clearLessonPlan() {
        guard !isRunning else { return }
        lessonPlanContent = ""
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
            lessonPlanContent = text
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
        let pending = SelfEvolution.status(from: fileContent).pendingCount
        guard AutoEvolutionCoordinator.shouldAutoStart(
            autoEvolutionEnabled: settings.autoEvolutionEnabled,
            pendingCount: pending
        ) else {
            if pending == 0 {
                AutoEvolutionCoordinator.clearChain()
            }
            return
        }

        AutoEvolutionCoordinator.markChainActive()

        autoEvolutionTask?.cancel()
        autoEvolutionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            guard let self, !self.isRunning else { return }
            guard EvolutionPlanner.nextPending(from: self.fileContent) != nil else {
                AutoEvolutionCoordinator.clearChain()
                return
            }
            if AppGuard.explanationSourceErrorMessage(for: settings) != nil { return }
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
        triggerEvolutionRebuild: Bool = false
    ) {
        let settings = AppSettings.shared
        let promptContext: PromptContext = isEvolution ? .evolution : .reading
        let userMessage = ChatMessage(role: .user, content: displayText)
        appendDisplayedMessage(userMessage, to: promptContext)
        if !isEvolution {
            selectRightPageTab(.readingAssistant)
            selectReadingAssistantPanel(.explanation)
            readingAssistantActiveTask = .explanation
        }
        beginRun(showsExecutionTrace: isEvolution)
        if isEvolution {
            executingEvolutionCommandNumber = evolutionCommandNumber
        } else {
            executingEvolutionCommandNumber = nil
        }
        errorMessage = nil

        let history: [ChatMessage]
        let readingLLMMode: AIBookLLMPrompt.Mode?
        if isEvolution {
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
                    isEvolution: isEvolution,
                    llmMode: readingLLMMode
                )

                guard !Task.isCancelled else { return }
                let resolvedThinking = isEvolution
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
                    toolSteps: isEvolution ? resolvedToolStepsForMessage() : nil
                )
                appendDisplayedMessage(assistantMessage, to: promptContext)

                if speakReplyWhenDone,
                   !suppressReplySpeech,
                   !Task.isCancelled,
                   !resolvedReply.isEmpty {
                    speakExplanation(resolvedReply)
                }

                if isEvolution, shouldUseCursorBridge(settings: settings) {
                    recordEvolutionCursorEstimate(
                        prompt: prompt,
                        history: Array(history),
                        reply: resolvedReply,
                        thinking: resolvedThinking
                    )
                }

                if isEvolution, triggerEvolutionRebuild {
                    let commandNumber = evolutionCommandNumber
                        ?? extractEvolutionCommandNumber(from: displayText)
                    applyEvolutionReadmeUpdate(reply: resolvedReply, commandNumber: commandNumber)

                    guard let projectURL = SelfEvolution.sourceProjectDirectory() else {
                        errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。"
                        AutoEvolutionCoordinator.clearChain()
                        return
                    }

                    let projectPath = projectURL.path
                    let stillPending = SelfEvolution.status(from: fileContent).pendingCount > 0
                    AutoEvolutionCoordinator.markChainActive()

                    appendDisplayedMessage(
                        ChatMessage(
                            role: .assistant,
                            content: stillPending
                                ? "第 \(commandNumber ?? 0) 条进化已完成。正在自动升级并继续下一条…"
                                : "全部命令已完成。正在自动升级并重启 AIBook…"
                        ),
                        to: .evolution
                    )
                    Task {
                        await self.handleEvolutionRebuild(projectPath: projectPath)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    let message = LLMServiceErrorPresenter.message(for: error, provider: AppSettings.shared.provider)
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

    private func runLessonPlanTask(displayText: String, prompt: String) {
        let settings = AppSettings.shared
        if let configError = AppGuard.explanationSourceErrorMessage(for: settings) {
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
                    isEvolution: false,
                    llmMode: llmMode
                )

                guard !Task.isCancelled else { return }
                let resolvedPlan = outcome.text.isEmpty ? streamingResponse : outcome.text
                let appendedPlan = appendTranslationResult(
                    resolvedPlan,
                    title: displayText,
                    to: lessonPlanContent
                )
                lessonPlanContent = appendedPlan
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

    private func appendTranslationResult(_ result: String, title: String, to existing: String) -> String {
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResult.isEmpty else { return existing }

        let header = "【\(title)】"
        let block = "\(header)\n\(trimmedResult)"
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExisting.isEmpty else { return block }
        return "\(trimmedExisting)\n\n\(block)"
    }

    private func lessonPlanSourceText() -> String {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty { return selected }
        return fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum TranslationMode {
        case wordByWord
        case paragraph
    }

    private func buildLessonPlanPrompt(
        source: String,
        existingPlan: String?,
        instruction: String?,
        mode: TranslationMode
    ) -> String {
        let taskIntro: String
        let outputFormat: String
        switch mode {
        case .wordByWord:
            taskIntro = """
            请对左侧文章做逐字翻译。
            要求：按原文顺序逐字、逐词、短语拆解；每项给出原文、译文和必要的极简说明；不扩写成教案，不啰嗦，不重复。
            """
            outputFormat = """
            输出格式：
            1. 逐字/逐词翻译表（原文 → 译文 → 必要说明）
            2. 难点词语（只列真正需要解释的）
            3. 一句话总译
            """
        case .paragraph:
            taskIntro = """
            请对左侧文章做整段翻译。
            要求：保留段落层次，译文通顺准确；可参考现有翻译内容进行改写；只输出翻译与少量必要注释，不写教案，不冗余。
            """
            outputFormat = """
            输出格式：
            1. 整段翻译（按原文段落）
            2. 必要注释（少量，避免重复）
            """
        }

        var sections = [
            taskIntro,
            outputFormat,
            "【左侧文章】\n\(source)",
        ]

        if let existingPlan, !existingPlan.isEmpty {
            sections.append("【现有翻译内容】\n\(existingPlan)")
        }
        if let instruction, !instruction.isEmpty {
            sections.append("【本次翻译要求】\n\(instruction)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func lessonPlanFileName() -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let base = stem.isEmpty || stem == "未命名" ? "文章" : stem
        return "\(base)-翻译.txt"
    }

    private func handleEvolutionRebuild(projectPath: String) async {
        await MainActor.run {
            isEvolutionRebuilding = true
            evolutionRebuildStatus = "正在执行 scripts/build-and-install.sh …"
        }

        let result = await AppRelauncher.rebuildAndRelaunch(projectPath: projectPath)

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

    private func shouldUseCursorBridge(settings: AppSettings) -> Bool {
        settings.isCursorRunnable && settings.explanationSource == .cursor
    }

    private func fetchAssistantReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        isEvolution: Bool,
        llmMode: AIBookLLMPrompt.Mode? = nil
    ) async throws -> AssistantReplyOutcome {
        let resolvedSystemPrompt: String
        if isEvolution {
            resolvedSystemPrompt = EvolutionAssistant.systemPrompt
        } else if let llmMode {
            resolvedSystemPrompt = llmMode.systemPrompt
        } else {
            resolvedSystemPrompt = ReadingAssistant.systemPrompt
        }
        let wantsCursor = shouldUseCursorBridge(settings: settings)

        if wantsCursor {
            do {
                return try await fetchCursorReply(
                    prompt: prompt,
                    history: history,
                    settings: settings,
                    systemInstruction: resolvedSystemPrompt,
                    autoAuthorize: isEvolution
                )
            } catch {
                guard settings.isLLMConfigured, isCursorAuthenticationFailure(error) else {
                    throw error
                }
                resetStreamingState()
                if isEvolution {
                    return try await fetchLLMEvolutionReply(
                        prompt: prompt,
                        history: history,
                        settings: settings
                    )
                }
                let llmText = try await fetchLLMReply(
                    prompt: prompt,
                    history: history,
                    settings: settings,
                    systemPrompt: resolvedSystemPrompt
                )
                return AssistantReplyOutcome(
                    text: llmText,
                    thinking: nil,
                    fallbackNotice: "Cursor 需要 API Key 才能连接，已自动改用「\(settings.provider.rawValue)」大模型回复。"
                )
            }
        }

        if isEvolution {
            guard settings.isLLMConfigured else {
                throw LLMServiceError.missingAPIKey(provider: settings.provider)
            }
            return try await fetchLLMEvolutionReply(
                prompt: prompt,
                history: history,
                settings: settings
            )
        }

        guard settings.isLLMConfigured else {
            throw LLMServiceError.missingAPIKey(provider: settings.provider)
        }

        let llmText = try await fetchLLMReply(
            prompt: prompt,
            history: history,
            settings: settings,
            systemPrompt: resolvedSystemPrompt
        )
        return AssistantReplyOutcome(text: llmText, thinking: nil, fallbackNotice: nil)
    }

    private func fetchLLMEvolutionReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings
    ) async throws -> AssistantReplyOutcome {
        guard let projectURL = SelfEvolution.sourceProjectDirectory() else {
            throw LLMServiceError.apiError(
                "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。",
                provider: settings.provider
            )
        }

        let result = try await llmEvolutionAgent.run(
            prompt: prompt,
            history: history,
            configuration: settings.llmConfiguration,
            projectRoot: projectURL,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleCursorStreamEvent(event)
                }
            },
            onUsage: { [weak self] usage in
                Task { @MainActor in
                    self?.recordEvolutionTokenUsage(usage)
                }
            },
            onContextTokens: { [weak self] tokens in
                Task { @MainActor in
                    self?.updateEvolutionAgentContextTokens(tokens)
                }
            }
        )
        return AssistantReplyOutcome(text: result.text, thinking: result.thinking, fallbackNotice: nil)
    }

    private func fetchCursorReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        systemInstruction: String,
        autoAuthorize: Bool
    ) async throws -> AssistantReplyOutcome {
        guard let cursorConfig = settings.cursorConfiguration else {
            throw CursorServiceError.bridgeNotFound
        }
        let result = try await cursorService.chat(
            message: prompt,
            history: history,
            configuration: cursorConfig,
            systemInstruction: systemInstruction,
            autoAuthorize: autoAuthorize,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleCursorStreamEvent(event)
                }
            }
        )
        return AssistantReplyOutcome(text: result.text, thinking: result.thinking, fallbackNotice: nil)
    }

    private func fetchLLMReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        systemPrompt: String
    ) async throws -> String {
        let configuration = settings.llmConfiguration
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: settings.provider)
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

    private func isCursorAuthenticationFailure(_ error: Error) -> Bool {
        if case CursorServiceError.needsAuthentication = error {
            return true
        }
        let message = (
            (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        ).lowercased()
        return message.contains("authentication")
            || message.contains("unauthenticated")
            || message.contains("connecterror")
            || message.contains("needs_auth")
            || message.contains("cursor api key")
            || message.contains("curson_api_key")
    }

    private func buildChatPrompt(for question: String) -> String {
        let settings = AppSettings.shared
        let contextPercent = settings.explanationSource == .llm
            ? settings.llmContextPercent
            : settings.cursorContextPercent
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
        let percent = AppSettings.shared.explanationSource == .llm
            ? AppSettings.shared.llmContextPercent
            : AppSettings.shared.cursorContextPercent
        let radius = max(Int(Double(content.count) * percent / 100.0 / 2.0), 300)
        guard let range = content.range(of: selection) else {
            return CursorContextCalculator.excerpt(from: content, percent: percent)
        }

        let start = content.index(range.lowerBound, offsetBy: -radius, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: radius, limitedBy: content.endIndex) ?? content.endIndex
        return String(content[start ..< end])
    }

    private func buildEvolutionChatPrompt(for question: String) -> String {
        let commands = EvolutionPlanner.parseCommands(from: fileContent)
        let commandList = commands
            .map { entry in
                let mark = entry.isCompleted ? "✓" : "○"
                return "\(mark) \(entry.text)"
            }
            .joined(separator: "\n")

        let definition = SelfEvolution.productDefinition
            .map { "- \($0)" }
            .joined(separator: "\n")

        let body = """
        【AIBook 产品定义】
        \(definition)

        【左页全部命令】
        \(commandList.isEmpty ? "（暂无编号命令）" : commandList)

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
                lessonPlanContent: lessonPlanContent
            )
        } catch {
            errorMessage = "无法保存对话会话：\(error.localizedDescription)"
        }
    }

    private func applyEvolutionReadmeUpdate(reply: String, commandNumber: Int?) {
        guard let number = commandNumber else { return }

        let fallback = SelfEvolution.markCompleted(
            in: fileContent,
            number: number,
            summary: "第 \(number) 条自我进化已执行（SelfEvolution 模块、自动授权与 readme 自动标记）。"
        )

        if let updated = SelfEvolution.applyCompletionFromReply(reply, to: fileContent, expectedNumber: number) {
            fileContent = updated
        } else {
            fileContent = fallback
        }

        savedContent = fileContent
        isDirty = false
        do {
            try readmeNotesStore.save(fileContent)
        } catch {
            errorMessage = "自我进化结果已写入左页，但保存命令笔记失败：\(error.localizedDescription)"
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

    private func speakExplanation(_ text: String, preferLowLatency: Bool = false) {
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

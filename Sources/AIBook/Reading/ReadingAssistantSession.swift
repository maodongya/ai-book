import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 读书助手会话：讲解/名著补充、对话消息、朗读与输入框。
final class ReadingAssistantSession: ObservableObject {
    unowned var host: ReadingViewModel!


    static var defaultWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: ReadingAssistant.welcomeMessage)
    }

    @Published var chatMessages: [ChatMessage] = [] {
        didSet { host.persistChatSession() }
    }
    @Published var readingChatInput = "" {
        didSet { host.persistChatSession() }
    }
    @Published var readingAssistantPanel: ReadingAssistantPanel = .explanation {
        didSet {
            guard !host.isRestoringSession else { return }
            host.persistChatSession()
        }
    }
    @Published var readingAssistantActiveTask: ReadingAssistantPanel?
    @Published var explanationSelectionText = ""
    @Published var explanationPanelSelectedText = ""

    func updateExplanationPanelSelection(_ text: String, range: NSRange? = nil) {
        host.document.updateExplanationPanelSelection(text, range: range)
    }

    func updateLessonPlanSelection(_ text: String, range: NSRange? = nil) {
        host.document.updateLessonPlanSelection(text, range: range)
    }
    @Published private(set) var explanationSelectAllSignal = UUID()
    @Published private(set) var isSpeakingExplanation = false
    @Published private(set) var isExplanationSpeechPaused = false
    @Published private(set) var currentSpeechSource: SpeechSource?
    var readingPromptMessages: [ChatMessage] = [ReadingAssistantSession.defaultWelcomeMessage]
    private var speakingRefreshTask: Task<Void, Never>?

    var effectiveSelectedText: String {
        let live = host.document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveLessonPlanSelectedText: String {
        let live = host.translation.lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveExplanationPanelSelectedText: String {
        let live = explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty
            || !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasExplanationContent: Bool {
        readingPromptMessages.contains { message in
            message.role == .assistant && !isReadingWelcomeMessage(message)
        }
    }

    var explanationDisplayMessages: [ChatMessage] {
        chatMessages.filter { shouldDisplayInExplanationPanel($0) }
    }



    func selectReadingAssistantPanel(_ panel: ReadingAssistantPanel) {
        guard readingAssistantPanel != panel else { return }
        readingAssistantPanel = panel
    }


    func updateAssistantMessage(id: UUID, content: String) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        guard chatMessages[index].content != content else { return }

        host.updatePromptMessage(id: id, content: content)
        var updated = chatMessages
        updated[index].content = content
        chatMessages = updated
    }


    func canEditExplanationMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && !isReadingWelcomeMessage(message)
    }


    func deleteChatMessage(id: UUID) {
        guard !host.isRunning else { return }
        let context = host.activePromptContext
        let messages = host.contextHistory(for: context)
        guard let message = messages.first(where: { $0.id == id }) else { return }
        let welcomeID = context == .reading
            ? ReadingAssistantSession.defaultWelcomeMessage.id
            : ReadingEvolutionSession.defaultEvolutionWelcomeMessage.id
        guard messages.count > 1 || message.id != welcomeID else { return }

        if message.role == .assistant, isSpeakingExplanation {
            host.assistant.stopExplanationSpeech()
        }

        host.removePromptMessage(id: id, from: context)
        if host.isDisplaying(context) {
            chatMessages.removeAll { $0.id == id }
        }
    }


    func saveAssistantMessage(id: UUID) {
        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.aiOutputEmptySave")
            return
        }

        host.document.exportContent(
            content,
            panelTitle: BookL10n.string("vm.panel.saveAIOutput"),
            panelMessage: BookL10n.string("vm.panel.saveAIOutputMsg"),
            suggestedName: host.document.assistantOutputFileName(for: message),
            successPrefix: BookL10n.string("vm.saved.aiOutput")
        )
    }


    func readAssistantMessage(id: UUID) {
        if isSpeakingExplanation {
            host.assistant.stopExplanationSpeech()
            return
        }

        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {
            return
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.aiOutputEmptySpeak")
            return
        }

        speakExplanation(content, source: .aiReply)
    }


    func openAssistantMessageFile() {
        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openAIOutput")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                host.errorMessage = BookL10n.string("vm.error.aiOutputOpenEmpty")
                return
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            let message = ChatMessage(role: .assistant, content: text)
            host.appendDisplayedMessage(message, to: .reading)
            host.errorMessage = nil
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.aiOutput", url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openAIOutput", error.localizedDescription)
        }
    }


    func shouldDisplayInExplanationPanel(_ message: ChatMessage) -> Bool {
        if message.role == .user { return false }
        if isExplanationInstructionMessage(message) { return false }
        return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    func explanationTranscriptText() -> String {
        readingPromptMessages
            .filter { shouldDisplayInExplanationPanel($0) }
            .map { message in
                "【助手】\n\(message.content)"
            }
            .joined(separator: "\n\n")
    }


    func explanationSpeakableText() -> String {
        readingPromptMessages
            .filter { shouldDisplayInExplanationPanel($0) }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }


    func newExplanationDocument() {
        guard !host.isRunning else { return }
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)
        host.assistant.stopExplanationSpeech()
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
        chatMessages = readingPromptMessages
        host.assistant.readingChatInput = ""
        explanationSelectionText = ""
        explanationPanelSelectedText = ""
        host.document.lastCommittedExplanationPanelSelectedText = ""
        host.errorMessage = nil
        host.persistChatSession()
    }


    func clearExplanation() {
        guard !host.isRunning else { return }
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)
        guard hasExplanationContent else { return }
        host.assistant.stopExplanationSpeech()
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
        chatMessages = readingPromptMessages
        host.assistant.readingChatInput = ""
        explanationSelectionText = ""
        explanationPanelSelectedText = ""
        host.document.lastCommittedExplanationPanelSelectedText = ""
        host.errorMessage = nil
        host.persistChatSession()
    }


    func saveExplanationDocument() {
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)
        host.persistChatSession()
        let content = explanationTranscriptText()
        guard !content.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noExplanationToSave")
            return
        }
        host.document.exportContent(
            content,
            panelTitle: BookL10n.string("vm.panel.saveExplanation"),
            panelMessage: BookL10n.string("vm.panel.saveExplanationMsg"),
            suggestedName: explanationFileName(),
            successPrefix: BookL10n.string("vm.saved.explanation")
        )
    }


    func openExplanationDocument() {
        guard !host.isRunning else { return }
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)

        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openExplanation")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadExplanation(at: url)
    }


    func loadExplanation(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                host.errorMessage = BookL10n.string("vm.error.explanationOpenEmpty")
                return
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            applyImportedExplanationText(text)
            host.errorMessage = nil
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.explanation", url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openExplanation", error.localizedDescription)
        }
    }


    func selectAllExplanation() {
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)
        let text = explanationTranscriptText()
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noExplanationSelection")
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

        let text = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noSourceToSpeak")
            return
        }

        speakExplanation(text, source: .originalFull)
    }


    func readOriginalSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        let text = effectiveSelectedText
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectSourceToSpeak")
            return
        }

        speakExplanation(text, source: .originalSelection)
    }


    func readTranslationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.translation)

        let text = host.translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.translationEmptySpeak")
            return
        }

        speakExplanation(text, source: .translationFull)
    }


    func readTranslationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.translation)

        let text = effectiveLessonPlanSelectedText
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectTranslationToSpeak")
            return
        }

        speakExplanation(text, source: .translationSelection)
    }


    func readExplanationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)

        let text = explanationSpeakableText()
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noExplanationToSpeak")
            return
        }

        speakExplanation(text, source: .explanationFull)
    }


    func readExplanationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)
        syncExplanationSelectionText()

        let text = effectiveExplanationPanelSelectedText
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectExplanationToSpeak")
            return
        }

        speakExplanation(text, source: .explanationSelection)
    }


    @discardableResult
    private func toggleReadAloudIfSpeaking() -> Bool {
        if isSpeakingExplanation {
            host.assistant.stopExplanationSpeech()
            return true
        }
        return false
    }


    private func isReadingWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.id == ReadingAssistantSession.defaultWelcomeMessage.id
            || (message.role == .assistant && message.content == ReadingAssistant.welcomeMessage)
    }


    private func isExplanationInstructionMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant else { return false }
        if isReadingWelcomeMessage(message) { return true }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty { return true }
        if content.hasPrefix("已打开「"), content.contains("选择讲解") { return true }
        return false
    }


    private func explanationFileName() -> String {
        let stem = (host.document.fileName as NSString).deletingPathExtension
        let base = stem.isEmpty || stem == ReadingViewModel.untitledMarker ? BookL10n.string("file.articleStem") : stem
        return "\(base)\(BookL10n.string("vm.filename.explanationSuffix"))"
    }


    func syncExplanationSelectionText() {
        explanationSelectionText = explanationTranscriptText()
    }


    private func applyImportedExplanationText(_ text: String) {
        let parsed = parseImportedExplanationMessages(text)
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage] + parsed
        chatMessages = readingPromptMessages
        explanationSelectionText = explanationTranscriptText()
        host.persistChatSession()
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
            ChatMessage(role: .user, content: BookL10n.string("vm.imported.explanationDraft")),
            ChatMessage(role: .assistant, content: text),
        ]
    }

    func explainSelection() {
        host.selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)

        let selection = effectiveSelectedText
        guard !selection.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectParagraph")
            return
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        let context = surroundingContext(for: selection, in: host.document.fileContent)
        let prompt = """
        请讲解下面这段文字：

        【选中内容】
        \(selection)

        【上下文】
        \(context)
        """

        host.sendMessage(
            prompt,
            displayText: BookL10n.format("vm.display.explainSelection", selection.count),
            speakReplyWhenDone: true
        )
    }


    func explainFullText() {
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.explanation)

        let fullText = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.openArticleFirst")
            return
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        let prompt = """
        请讲解下面这篇全文：

        【全文】
        \(fullText)
        """

        host.sendMessage(
            prompt,
            displayText: BookL10n.format("vm.display.explainFull", fullText.count),
            speakReplyWhenDone: true
        )
    }


    func readSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }

        host.selectRightPageTab(.readingAssistant)

        let selected = effectiveSelectedText
        let fullText = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = selected.isEmpty ? fullText : selected
        guard !text.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noReadableContent")
            return
        }

        let source: SpeechSource = selected.isEmpty ? .originalFull : .originalSelection
        speakExplanation(text, source: source)
    }


    func readLessonPlanAloud() {
        readTranslationFullTextAloud()
    }


    func supplementClassicLiterature() {
        let trimmed = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.classicsPasteFirst")
            return
        }

        guard AppSettings.shared.isBookLLMConfigured else {
            host.errorMessage = BookL10n.string("vm.error.classicsNeedLLM")
            return
        }

        let source = host.document.selectedText.isEmpty ? host.document.fileContent : host.document.selectedText
        let replacingSelection = !host.document.selectedText.isEmpty

        host.beginRun(showsExecutionTrace: false)
        host.errorMessage = nil

        let prompt = ClassicLiteratureSupplement.buildPrompt(source: source, isSelection: replacingSelection)
        let llmMode = AIBookLLMPrompt.Mode.classicLiteratureSupplement
        let settings = AppSettings.shared
        let selectionRange = replacingSelection ? host.document.currentSelectionRange(matching: source) : nil

        host.activeTask?.cancel()
        host.activeTask = Task {
            do {
                var streamed = ""
                let reply = try await host.llmService.chat(
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
                                self.host.streamingResponse = streamed
                                guard !replacingSelection else { return }
                                let preview = ClassicLiteratureSupplement.extractContent(from: streamed)
                                    ?? ClassicLiteratureSupplement.stripMarkers(from: streamed)
                                if !preview.isEmpty {
                                    self.host.document.fileContent = preview
                                }
                            }
                        }
                    }
                )

                guard !Task.isCancelled else { return }

                let finalText = ClassicLiteratureSupplement.extractContent(from: reply)
                    ?? ClassicLiteratureSupplement.stripMarkers(from: reply)
                host.document.applySupplementToLeftPage(finalText, selectionRange: selectionRange)
                host.document.persistLeftPage()

                appendDisplayOnlyMessage(
                    ChatMessage(
                        role: .assistant,
                        content: BookL10n.format("vm.classics.done", finalText.count)
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    let message = LLMServiceErrorPresenter.message(for: error, provider: settings.bookProvider)
                    host.errorMessage = message
                    appendDisplayOnlyMessage(
                        ChatMessage(role: .assistant, content: BookL10n.format("vm.classics.failed", message))
                    )
                }
            }
            host.isLoading = false
            host.isRunning = false
            host.streamingToolStatus = ""
            host.resetStreamingState()
        }
    }


    private func buildChatPrompt(for question: String) -> String {
        let contextPercent = AppSettings.shared.bookContextPercent
        var sections: [String] = []

        if !host.document.fileContent.isEmpty {
            let focus = host.document.selectedText.isEmpty ? nil : host.document.selectedText
            let excerpt = CursorContextCalculator.excerpt(
                from: host.document.fileContent,
                percent: contextPercent,
                focus: focus
            )
            let anchorHint = focus != nil ? "，围绕选中内容" : ""
            sections.append("【当前阅读文本节选（\(Int(contextPercent))%\(anchorHint)）】\n\(excerpt)")
        }

        if !host.document.selectedText.isEmpty {
            sections.append("【当前选中内容】\n\(host.document.selectedText)")
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


    func isTranslationHistoryMessage(_ message: ChatMessage) -> Bool {
        BookL10nMarkers.isTranslationTaskMessage(message.content)
    }

    private func appendDisplayOnlyMessage(_ message: ChatMessage) {
        if host.isDisplaying(.reading) {
            chatMessages.append(message)
        }
    }


    func speakExplanation(_ text: String, source: SpeechSource, preferLowLatency: Bool = false) {
        let settings = AppSettings.shared
        let units = SpeechTextSanitizer.speechUnits(
            for: text,
            mode: settings.speechLanguageMode
        )
        guard !units.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.speechEmpty")
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


    func syncExplanationSpeechState() {
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

}

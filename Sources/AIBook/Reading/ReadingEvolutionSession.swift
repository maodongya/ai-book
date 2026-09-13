import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// AI 进化会话：优化队列、分析/进化请求与 token 预算。
final class ReadingEvolutionSession: ObservableObject {
    unowned var host: ReadingViewModel!


    static var defaultEvolutionWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: EvolutionAssistant.welcomeMessage)
    }

    @Published var evolutionChatInput = "" {
        didSet { host.persistChatSession() }
    }
    @Published var optimizationQueue = OptimizationQueue.empty
    @Published var evolutionRunKind: ReadingEvolutionRunKind = .none
    @Published var evolutionLastRequestId: String?
    @Published var executingEvolutionCommandNumber: Int?
    @Published var isEvolutionRebuilding = false
    @Published var evolutionRebuildStatus = ""
    @Published var evolutionSessionTokensConsumed = 0
    @Published var evolutionAgentContextTokens = 0
    @Published var showsExecutionTrace = false
    private let optimizationQueueStore = OptimizationQueueStore(
        fileURL: OptimizationQueueStore.defaultFileURL
    )
    private var autoEvolutionTask: Task<Void, Never>?
    private var didScheduleAutoEvolution = false
    var evolutionPromptMessages: [ChatMessage] = []

    var evolutionStatusLabel: String? { SelfEvolution.statusLabel(from: optimizationQueue) }
    var evolutionItems: [OptimizationItem] { optimizationQueue.items.sorted { $0.number < $1.number } }
    var hasPendingOptimization: Bool { optimizationQueue.nextPending() != nil }

    var hasEvolutionConversation: Bool {
        evolutionPromptMessages.contains { !isEvolutionWelcomeMessage($0) }
    }



    func loadOptimizationQueue() {
        do {
            optimizationQueue = try optimizationQueueStore.migrateFromReadmeNotesIfNeeded(
                ReadmeNotesStore.shared.loadInitialContent()
            )
        } catch {
            host.errorMessage = BookL10n.format("vm.error.loadQueue", error.localizedDescription)
            optimizationQueue = .empty
        }
    }


    func persistOptimizationQueue() {
        do {
            try optimizationQueueStore.save(optimizationQueue)
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveQueue", error.localizedDescription)
        }
    }


    func evolutionTokenBudget(additionalPrompt: String?) -> ModelTokenBudget {
        let settings = AppSettings.shared
        return EvolutionTokenCalculator.budget(
            sessionConsumedTokens: evolutionSessionTokensConsumed,
            agentLiveContextTokens: evolutionAgentContextTokens,
            messages: evolutionPromptMessages,
            input: evolutionChatInput,
            streamingThinking: host.streamingThinking,
            streamingResponse: host.streamingResponse,
            toolSteps: host.streamingToolSteps,
            additionalPrompt: additionalPrompt,
            usesCursor: true,
            cursorModel: settings.resolvedCursorModel,
            llmModel: settings.model,
            llmProvider: settings.provider
        )
    }


    func ensureEvolutionUsesCursor() {
        let settings = AppSettings.shared
        settings.reloadCursorAPIKey()
        if settings.explanationSource != .cursor {
            settings.explanationSource = .cursor
        }
    }


    private func guardEvolutionTokenLimit(for prompt: String, action: String) -> Bool {
        let budget = evolutionTokenBudget(additionalPrompt: prompt)
        if let message = budget.blockMessage(for: action) {
            host.errorMessage = message
            return false
        }
        return true
    }


    func recordEvolutionTokenUsage(_ usage: LLMTokenUsage) {
        guard usage.totalTokens > 0 else { return }
        evolutionSessionTokensConsumed += usage.totalTokens
    }


    private func updateEvolutionAgentContextTokens(_ tokens: Int) {
        evolutionAgentContextTokens = max(0, tokens)
    }


    func recordEvolutionCursorEstimate(
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


    func clearEvolutionExecutionState() {
        executingEvolutionCommandNumber = nil
        evolutionRunKind = .none
    }


    func revertRunningOptimization(number: Int) {
        guard let item = optimizationQueue.items.first(where: { $0.number == number }) else { return }
        if optimizationQueue.revertRunningToPending(id: item.id) {
            persistOptimizationQueue()
        }
    }

    /// Refresh welcome chrome after interface language changes (keeps session data).

    func saveEvolutionCommands() {
        guard !optimizationQueue.items.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.queueEmptySave")
            return
        }
        let formatted = NumberedNoteFormatter.format(optimizationQueue)
        exportEvolutionCommands(
            formatted,
            panelTitle: BookL10n.string("vm.panel.saveEvolutionCommands"),
            panelMessage: BookL10n.string("vm.panel.saveEvolutionCommandsMsg"),
            successPrefix: BookL10n.string("vm.saved.evolutionCommands")
        )
    }

    /// 从本地编号命令文本文件加载优化队列。

    func openEvolutionCommands() {
        guard !host.isRunning else { return }

        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openEvolutionCommands")
        panel.message = BookL10n.string("vm.panel.openEvolutionCommandsMsg")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let imported = OptimizationQueue.importFromNotes(text)
            guard !imported.items.isEmpty else {
                host.errorMessage = BookL10n.string("vm.error.noValidCommands")
                return
            }
            if optimizationQueue.items.contains(where: { $0.status == .running }) {
                host.errorMessage = BookL10n.string("vm.error.evolutionRunningOpen")
                return
            }
            if !optimizationQueue.items.isEmpty,
               !host.document.confirmReplaceOptimizationQueue() {
                return
            }

            optimizationQueue = imported
            persistOptimizationQueue()
            host.document.syncLeftPageWithEvolutionCommands(from: url, formatted: NumberedNoteFormatter.format(imported))
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            host.errorMessage = nil
            let count = imported.items.count
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.evolutionCommands", count, url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openEvolutionCommands", error.localizedDescription)
        }
    }

    var canSaveEvolutionCommands: Bool {
        !optimizationQueue.items.isEmpty
    }

    var canOpenEvolutionCommands: Bool {
        !host.isRunning
    }


    private func exportEvolutionCommands(
        _ content: String,
        panelTitle: String,
        panelMessage: String,
        successPrefix: String
    ) {
        guard !content.isEmpty else { return }

        let directory = DocumentExporter.defaultDirectory(currentFileURL: host.document.currentFileURL)
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
            host.document.syncLeftPageWithEvolutionCommands(from: destination, formatted: content)
            host.errorMessage = nil
            let count = optimizationQueue.items.count
            host.document.showTransientSaveMessage(BookL10n.format("vm.saved.itemsTo", successPrefix, count, destination.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveEvolutionCommands", error.localizedDescription)
        }
    }


    private func isEvolutionWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && message.content == EvolutionAssistant.welcomeMessage
    }


    func startEvolution() {
        host.selectRightPageTab(.aiEvolution)
        ensureEvolutionWelcome()
        ensureEvolutionUsesCursor()

        if let running = optimizationQueue.items.first(where: { $0.status == .running }) {
            _ = optimizationQueue.revertRunningToPending(id: running.id)
            persistOptimizationQueue()
        }

        guard let pending = optimizationQueue.nextPending() else {
            host.errorMessage = BookL10n.string("vm.needAnalyzeFirst")
            AutoEvolutionCoordinator.clearChain()
            return
        }

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        guard SelfEvolution.sourceProjectReady else {
            host.errorMessage = BookL10n.format("vm.error.sourceProjectMissing", SelfEvolution.sourceProjectPath())
            return
        }

        let projectPath = SelfEvolution.sourceProjectPath()
        let prompt = EvolutionPlanner.buildEvolutionPrompt(
            queue: optimizationQueue,
            pending: pending,
            projectPath: projectPath
        )
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.evolve")) else { return }

        guard optimizationQueue.markRunning(id: pending.id) else { return }
        persistOptimizationQueue()
        AutoEvolutionCoordinator.markChainActive()

        host.sendMessage(
            prompt,
            displayText: BookL10n.format("vm.display.evolutionItem", pending.number),
            isEvolution: true,
            evolutionCommandNumber: pending.number,
            triggerEvolutionRebuild: true,
            evolutionRunKind: .evolution
        )
    }


    func analyzeOptimizations() {
        host.selectRightPageTab(.aiEvolution)
        ensureEvolutionWelcome()
        ensureEvolutionUsesCursor()
        guard !host.isRunning, !isEvolutionRebuilding else { return }

        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }
        guard SelfEvolution.sourceProjectReady else {
            host.errorMessage = BookL10n.format("vm.error.sourceProjectMissing", SelfEvolution.sourceProjectPath())
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
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.analyze")) else { return }

        evolutionRunKind = .analysis
        host.sendMessage(
            prompt,
            displayText: direction.isEmpty ? BookL10n.string("vm.display.analyze") : BookL10n.format("vm.display.analyzeWith", direction),
            isEvolution: true,
            evolutionCommandNumber: nil,
            triggerEvolutionRebuild: false,
            evolutionRunKind: .analysis
        )
    }


    func skipOptimization(id: UUID) {
        guard !host.isRunning else { return }
        if optimizationQueue.skip(id: id) {
            persistOptimizationQueue()
        }
    }


    func restoreOptimization(id: UUID) {
        guard !host.isRunning else { return }
        if optimizationQueue.restore(id: id) {
            persistOptimizationQueue()
        }
    }


    func deleteOptimization(id: UUID) {
        guard !host.isRunning else { return }
        optimizationQueue.remove(id: id)
        persistOptimizationQueue()
    }


    func pinOptimization(id: UUID) {
        guard !host.isRunning else { return }
        optimizationQueue.pin(id: id)
        persistOptimizationQueue()
    }


    func addUserOptimization(title: String) {
        guard !host.isRunning else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = optimizationQueue.addUserItem(title: trimmed)
        persistOptimizationQueue()
    }


    func sendEvolutionChatInput() {
        let text = evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        ensureEvolutionUsesCursor()
        if let configError = AppGuard.evolutionSourceErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        evolutionChatInput = ""
        let prompt = buildEvolutionChatPrompt(for: text)
        guard guardEvolutionTokenLimit(for: prompt, action: BookL10n.string("vm.action.followUp")) else { return }
        host.sendMessage(
            prompt,
            displayText: text,
            isEvolution: true,
            triggerEvolutionRebuild: false,
            evolutionRunKind: .followUp
        )
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
            guard let self, !self.host.isRunning else { return }
            guard self.optimizationQueue.nextPending() != nil else {
                AutoEvolutionCoordinator.clearChain()
                return
            }
            if AppGuard.evolutionSourceErrorMessage(for: settings) != nil { return }
            guard self.host.canRunEvolution else {
                AutoEvolutionCoordinator.clearChain()
                self.host.errorMessage = self.host.evolutionTokenBudget.blockMessage(for: BookL10n.string("vm.action.autoEvolve"))
                return
            }
            self.startEvolution()
        }
    }


    func handleEvolutionRebuild(projectPath: String, continueChain: Bool = true) async {
        await MainActor.run {
            isEvolutionRebuilding = true
            evolutionRebuildStatus = BookL10n.string("vm.rebuild.running")
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
            let message = result.message ?? BookL10n.string("vm.rebuild.failedDefault")
            host.errorMessage = message
            host.appendDisplayedMessage(
                ChatMessage(
                    role: .assistant,
                    content: BookL10n.format("vm.rebuild.failedStop", message)
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


    func ensureEvolutionWelcome() {
        if evolutionPromptMessages.isEmpty {
            evolutionPromptMessages = [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]
        }
    }


    func applyEvolutionQueueUpdate(reply: String, commandNumber: Int?) {
        guard let number = commandNumber,
              let item = optimizationQueue.items.first(where: { $0.number == number })
        else { return }

        let summary = EvolutionPlanner.parseCompletionSummary(from: reply, number: number)
            ?? BookL10n.format("vm.evolution.itemExecuted", number)

        if item.status == .running {
            _ = optimizationQueue.markCompleted(id: item.id, summary: summary)
        } else if let index = optimizationQueue.items.firstIndex(where: { $0.id == item.id }) {
            optimizationQueue.items[index].status = .completed
            optimizationQueue.items[index].completionSummary = summary
            optimizationQueue.updatedAt = Date()
        }
        persistOptimizationQueue()
        host.document.syncLeftPageFromOptimizationQueue()
    }


    func handleAnalysisCompletion(reply: String) {
        if let projectPath = SelfEvolution.sourceProjectDirectory()?.path,
           !gitWorkingTreeIsClean(at: projectPath) {
            host.appendDisplayedMessage(
                ChatMessage(
                    role: .assistant,
                    content: BookL10n.string("vm.evolution.analysisDirty")
                ),
                to: .evolution
            )
            return
        }

        let drafts = EvolutionAnalyzer.parseItems(from: reply)
        if drafts.isEmpty {
            host.appendDisplayedMessage(
                ChatMessage(role: .assistant, content: BookL10n.string("vm.evolution.noNewItems")),
                to: .evolution
            )
            return
        }

        let report = optimizationQueue.merge(drafts: drafts)
        persistOptimizationQueue()
        host.document.syncLeftPageFromOptimizationQueue()
        host.appendDisplayedMessage(
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


    func extractEvolutionCommandNumber(from displayText: String) -> Int? {
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


}

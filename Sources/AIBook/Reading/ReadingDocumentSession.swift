import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 左页文档会话：打开/保存、选区、目录浏览与 readme 笔记状态。
final class ReadingDocumentSession: ObservableObject {
    unowned var host: ReadingViewModel!


    @Published var fileContent = "" {
        didSet {
            isDirty = fileContent != savedContent
            scheduleAutoSaveIfNotes()
            if !host.isRestoringSession, !host.translation.isApplyingAlignment {
                host.translation.refreshTranslationAlignmentStaleState()
            }
        }
    }
    @Published var fileName = ReadingViewModel.untitledMarker
    @Published private(set) var isDocumentOpen = false
    @Published var selectedText = ""
    var lastCommittedSelectionText = ""
    var lastCommittedSelectionRange: NSRange?
    @Published private(set) var leftSelectAllSignal = UUID()
    @Published private(set) var rightSelectAllSignal = UUID()
    var lastCommittedLessonPlanSelectedText = ""
    var lastCommittedExplanationPanelSelectedText = ""
    @Published private(set) var isDirty = false
    @Published var showDirectoryBrowser = false
    @Published var directoryBrowserSessions: [DirectoryBrowserRootSession] = []
    @Published var selectedDirectorySessionID: UUID?
    @Published private(set) var lastSaveMessage: String?
    var currentFileURL: URL?
    private var savedContent = ""
    var selectedTextRange: NSRange?
    private var autoSaveTask: Task<Void, Never>?
    private var saveMessageTask: Task<Void, Never>?
    private let readmeNotesStore = ReadmeNotesStore.shared

    var displayFileName: String {
        guard isDocumentOpen || currentFileURL != nil || !fileContent.isEmpty else {
            return BookL10n.string("vm.noFileOpen")
        }
        let name = currentFileURL?.lastPathComponent ?? fileName
        return isDirty ? "\(name) •" : name
    }

    var isEditingNotes: Bool { currentFileURL == nil }



    func newDocument() {
        guard !host.isRunning else { return }
        guard confirmDiscardUnsavedIfNeeded() else { return }

        host.assistant.stopExplanationSpeech()
        fileContent = ""
        savedContent = ""
        fileName = ReadingViewModel.untitledMarker
        currentFileURL = nil
        isDocumentOpen = true
        isDirty = false
        host.mode.readingPageTexts = []
        host.mode.readingSourcePageRanges = []
        host.mode.readingSpreadIndex = 0
        host.mode.experienceMode = .learning
        selectedText = ""
        lastCommittedSelectionText = ""
        lastCommittedSelectionRange = nil
        selectedTextRange = nil
        host.assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
        host.syncDisplayedChatMessages()
        host.assistant.readingChatInput = ""
        host.errorMessage = nil
        host.persistChatSession()
    }


    func openFile() {
        guard confirmDiscardUnsavedIfNeeded() else { return }

        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openTextFile")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(at: url)
    }


    func openDirectory() {
        guard !host.isRunning else { return }
        if directoryBrowserSessions.isEmpty {
            guard let url = pickDirectoryURL() else { return }
            addDirectorySession(for: url)
        }
        showDirectoryBrowser = true
    }


    func addDirectoryFromPanel() {
        guard !host.isRunning else { return }
        guard let url = pickDirectoryURL() else { return }
        addDirectorySession(for: url)
        showDirectoryBrowser = true
    }


    func selectDirectorySession(_ id: UUID) {
        selectedDirectorySessionID = id
    }


    func removeDirectorySession(_ id: UUID) {
        directoryBrowserSessions.removeAll { $0.id == id }
        if selectedDirectorySessionID == id {
            selectedDirectorySessionID = directoryBrowserSessions.first?.id
        }
        persistDirectoryBrowserSessions()
    }


    func toggleDirectoryNodeExpanded(sessionID: UUID, path: String) {
        guard let index = directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if directoryBrowserSessions[index].expandedPaths.contains(path) {
            directoryBrowserSessions[index].expandedPaths.remove(path)
        } else {
            directoryBrowserSessions[index].expandedPaths.insert(path)
        }
        persistDirectoryBrowserSessions()
    }


    func dismissDirectoryBrowser() {
        showDirectoryBrowser = false
    }


    func openFileFromDirectory(at url: URL, target: DirectoryFileOpenTarget) {
        switch target {
        case .original:
            guard confirmDiscardUnsavedIfNeeded() else { return }
            loadFile(at: url)
        case .translation:
            host.selectRightPageTab(.readingAssistant)
            host.assistant.selectReadingAssistantPanel(.translation)
            host.translation.loadLessonPlan(at: url)
        case .explanation:
            guard !host.isRunning else { return }
            host.selectRightPageTab(.readingAssistant)
            host.assistant.selectReadingAssistantPanel(.explanation)
            host.assistant.loadExplanation(at: url)
        }
        DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
    }


    private func pickDirectoryURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.chooseFolder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        DocumentExporter.lastDirectoryURL = url
        return url
    }


    private func addDirectorySession(for url: URL) {
        let standardized = url.standardizedFileURL
        if let existing = directoryBrowserSessions.first(where: { $0.rootURL == standardized }) {
            selectedDirectorySessionID = existing.id
            if existing.tree == nil, !existing.isLoading {
                loadDirectoryTree(for: existing.id)
            }
            return
        }

        let session = DirectoryBrowserRootSession.new(url: standardized)
        directoryBrowserSessions.append(session)
        selectedDirectorySessionID = session.id
        persistDirectoryBrowserSessions()
        loadDirectoryTree(for: session.id)
    }


    func restoreDirectoryBrowserSessions() {
        let stored = DirectoryBrowserPersistence.load()
        directoryBrowserSessions = stored.map { storedRoot in
            let url = URL(fileURLWithPath: storedRoot.urlPath, isDirectory: true).standardizedFileURL
            return DirectoryBrowserRootSession(
                id: storedRoot.id,
                rootURL: url,
                tree: nil,
                isLoading: false,
                expandedPaths: Set(storedRoot.expandedPaths),
                loadError: nil
            )
        }
        selectedDirectorySessionID = directoryBrowserSessions.first?.id
        for session in directoryBrowserSessions {
            loadDirectoryTree(for: session.id)
        }
    }


    private func persistDirectoryBrowserSessions() {
        DirectoryBrowserPersistence.save(directoryBrowserSessions)
    }


    private func loadDirectoryTree(for sessionID: UUID) {
        guard let index = directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let rootURL = directoryBrowserSessions[index].rootURL
        directoryBrowserSessions[index].isLoading = true
        directoryBrowserSessions[index].loadError = nil

        Task.detached(priority: .userInitiated) {
            let tree = DirectoryTreeScanner.scan(root: rootURL)
            await MainActor.run { [weak self] in
                guard let self,
                      let currentIndex = self.directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else {
                    return
                }
                self.directoryBrowserSessions[currentIndex].isLoading = false
                if let tree {
                    self.directoryBrowserSessions[currentIndex].tree = tree
                    self.directoryBrowserSessions[currentIndex].loadError = nil
                    if self.directoryBrowserSessions[currentIndex].expandedPaths.isEmpty {
                        self.directoryBrowserSessions[currentIndex].expandedPaths.insert(tree.id)
                    }
                } else {
                    self.directoryBrowserSessions[currentIndex].tree = nil
                    self.directoryBrowserSessions[currentIndex].loadError = BookL10n.string("vm.error.readDirectory")
                }
                self.persistDirectoryBrowserSessions()
            }
        }
    }


    func openDroppedFile(at url: URL) {
        guard url.pathExtension.lowercased() == "txt" || url.pathExtension.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.txtOnly")
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
                host.assistant.readingPromptMessages = []
                host.evolution.evolutionPromptMessages = []
                host.syncDisplayedChatMessages()
            }
            host.errorMessage = nil
            host.persistChatSession()
            host.translation.refreshTranslationAlignmentAfterSourceChange()
        } catch {
            host.errorMessage = BookL10n.format("vm.error.readFile", error.localizedDescription)
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
        host.document.exportContent(
            fileContent,
            panelTitle: BookL10n.string("vm.panel.saveAsText"),
            panelMessage: BookL10n.string("vm.panel.saveAsTextMsg"),
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName
            ),
            successPrefix: BookL10n.string("vm.saved.as")
        )
    }


    func saveSelectionAs() {
        let selection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectExportText")
            return
        }

        host.document.exportContent(
            selection,
            panelTitle: BookL10n.string("vm.panel.exportSelection"),
            panelMessage: BookL10n.string("vm.panel.exportSelectionMsg"),
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName,
                selectionSuffix: true
            ),
            successPrefix: BookL10n.string("vm.saved.exportSelection")
        )
    }


    func exportContent(
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
            host.errorMessage = nil
            host.document.showTransientSaveMessage("\(successPrefix) \(destination.lastPathComponent)")
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveFile", error.localizedDescription)
        }
    }


    func syncLeftPageWithEvolutionCommands(from url: URL, formatted: String) {
        fileContent = formatted
        savedContent = formatted
        fileName = url.lastPathComponent
        currentFileURL = url
        isDocumentOpen = true
        isDirty = false
        do {
            try ReadmeNotesStore.shared.save(formatted)
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)
        }
    }

    /// 将优化队列格式化为左页编号命令（N、…）并同步展示与持久化。

    func syncLeftPageFromOptimizationQueue() {
        guard !host.evolution.optimizationQueue.items.isEmpty else { return }
        let formatted = NumberedNoteFormatter.format(host.evolution.optimizationQueue)
        fileContent = formatted
        savedContent = formatted
        isDirty = false
        if !isDocumentOpen {
            isDocumentOpen = true
        }
        do {
            try ReadmeNotesStore.shared.save(formatted)
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)
        }
        if let url = currentFileURL {
            try? DocumentExporter.write(formatted, to: url)
        }
    }

    /// 左页含编号命令行时回写优化队列，使手动编辑与进化队列保持一致。

    func syncOptimizationQueueFromLeftPageIfNeeded() {
        guard !host.isRunning else { return }
        guard !host.evolution.optimizationQueue.items.contains(where: { $0.status == .running }) else { return }
        let imported = OptimizationQueue.importFromNotes(fileContent)
        guard !imported.items.isEmpty else { return }
        host.evolution.optimizationQueue = imported
        host.evolution.persistOptimizationQueue()
    }


    func confirmReplaceOptimizationQueue() -> Bool {
        let alert = NSAlert()
        alert.messageText = BookL10n.string("vm.alert.replaceQueueTitle")
        alert.informativeText = BookL10n.format("vm.alert.replaceQueueMsg", host.evolution.optimizationQueue.items.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: BookL10n.string("action.replace"))
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }


    func assistantOutputFileName(for message: ChatMessage) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "AI查询内容-\(formatter.string(from: message.timestamp)).txt"
    }


    func showTransientSaveMessage(_ message: String) {
        lastSaveMessage = message
        saveMessageTask?.cancel()
        saveMessageTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lastSaveMessage = nil
        }
    }


    func loadReadmeNotes() {
        let content = ReadmeNotesStore.shared.loadInitialContent()
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
            try ReadmeNotesStore.shared.save(fileContent)
            savedContent = fileContent
            fileName = "readme-notes.txt"
            currentFileURL = nil
            isDirty = false
            host.errorMessage = nil
            syncOptimizationQueueFromLeftPageIfNeeded()
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveCommandNotes", error.localizedDescription)
        }
    }


    private func syncReadmeNotesIfNeeded() {
        guard fileName == "readme-notes.txt" || currentFileURL == nil else { return }
        do {
            try ReadmeNotesStore.shared.save(fileContent)
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)
        }
    }


    private func writeContent(to url: URL) {
        do {
            try DocumentExporter.write(fileContent, to: url)
            currentFileURL = url
            fileName = url.lastPathComponent
            savedContent = fileContent
            isDirty = false
            host.errorMessage = nil
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            host.document.showTransientSaveMessage(BookL10n.format("vm.saved.file", url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveFile", error.localizedDescription)
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
            host.translation.lessonPlanSelectedText = trimmed
            lastCommittedLessonPlanSelectedText = trimmed
        } else {
            host.translation.lessonPlanSelectedText = ""
        }
    }


    func updateExplanationPanelSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            host.assistant.explanationPanelSelectedText = trimmed
            lastCommittedExplanationPanelSelectedText = trimmed
        } else {
            host.assistant.explanationPanelSelectedText = ""
        }
    }

    func selectAllLeftPage() {
        guard !fileContent.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.noSelectableText")
            return
        }
        leftSelectAllSignal = UUID()
    }


    func selectAllRightPage() {
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.translation)
        guard !host.translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.translationEmptySelectAll")
            return
        }
        rightSelectAllSignal = UUID()
    }

    func applySupplementToLeftPage(_ supplemented: String, selectionRange: Range<String.Index>?) {
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


    func currentSelectionRange(matching source: String) -> Range<String.Index>? {
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


    func persistLeftPage() {
        if let url = currentFileURL {
            writeContent(to: url)
        } else {
            saveReadmeNotes()
        }
    }


    private func scheduleAutoSaveIfNotes() {
        guard isEditingNotes, isDirty, !host.isRestoringSession else { return }

        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveReadmeNotes()
        }
    }

}

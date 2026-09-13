import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 翻译会话：译文内容、对齐、表格滚动与翻译 API 调用链。
final class ReadingTranslationSession: ObservableObject {
    unowned var host: ReadingViewModel!


    @Published var lessonPlanSelectedText = ""
    @Published var lessonPlanContent = "" {
        didSet {
            if !isApplyingAlignment {
                refreshTranslationAlignmentStaleState(fromManualEdit: true)
            }
            host.persistChatSession()
        }
    }
    @Published var translationAlignment: TranslationAlignment? {
        didSet {
            translationScrollSync.resetAnchors()
            if isApplyingAlignment { return }
            syncTranslationScrollPresentation()
            host.persistChatSession()
        }
    }
    @Published var translationTableViewEnabled = false {
        didSet {
            syncTranslationScrollPresentation()
            host.persistChatSession()
        }
    }
    @Published var translationTableScrollTargetID: UUID?
    @Published var translationTableHighlightedBlockID: UUID?
    @Published var translationTableFocusTranslationBlockID: UUID?
    let sourceTextScrollProxy = SelectableTextViewProxy()
    let translationTextScrollProxy = SelectableTextViewProxy()
    let translationScrollSync = TranslationScrollSync()
    var isApplyingAlignment = false

    var canAlignTranslationWithSource: Bool {
        !host.isRunning
            && translationAlignment?.isLocked != true
            && !lessonPlanSourceText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isTranslationAlignmentLocked: Bool { translationAlignment?.isLocked == true }

    var translationAlignmentStatusText: String? {
        guard let alignment = translationAlignment else { return nil }
        if alignment.isStale { return BookL10n.string("vm.align.stale") }
        var parts = [BookL10n.format("vm.align.anchored", alignment.anchoredBlockCount, alignment.blocks.count)]
        if alignment.isLocked { parts.append(BookL10n.string("vm.align.locked")) }
        return parts.joined(separator: " · ")
    }

    var showsTranslationTableView: Bool { translationTableViewEnabled && canUseTranslationTableView }

    var canUseTranslationTableView: Bool {
        guard let alignment = translationAlignment, !alignment.isStale else { return false }
        return alignment.blocks.contains { $0.level == .word || $0.level == .phrase || $0.level == .paragraph }
    }

    var shouldSyncTranslationScroll: Bool {
        host.mode.experienceMode == .learning
            && host.rightPageTab == .readingAssistant
            && host.assistant.readingAssistantPanel == .translation
            && showsTranslationTableView
            && translationAlignment != nil
            && translationAlignment?.isStale == false
    }



    func sendChatInput() {
        let text = host.assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        host.assistant.readingChatInput = ""
        refineLessonPlan(instruction: text)
    }

    func selectAllRightPage() {
        host.document.selectAllRightPage()
    }


    func generateLessonPlan() {
        let source = lessonPlanSourceText()
        guard !source.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.translationSourceFirst")
            return
        }
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.translation)
        runLessonPlanTask(
            displayText: BookL10n.string("vm.display.wordTranslation"),
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
            host.errorMessage = BookL10n.string("vm.error.translationSourceFirst")
            return
        }
        host.selectRightPageTab(.readingAssistant)
        host.assistant.selectReadingAssistantPanel(.translation)
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        runLessonPlanTask(
            displayText: BookL10n.string("vm.display.paragraphTranslation"),
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
        guard !host.isRunning else { return }
        isApplyingAlignment = true
        translationAlignment = nil
        lessonPlanContent = ""
        isApplyingAlignment = false
    }


    func saveLessonPlan() {
        let content = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.translationEmptySave")
            return
        }
        host.document.exportContent(
            content,
            panelTitle: BookL10n.string("vm.panel.saveTranslation"),
            panelMessage: BookL10n.string("vm.panel.saveTranslationMsg"),
            suggestedName: lessonPlanFileName(),
            successPrefix: BookL10n.string("vm.saved.translation")
        )
    }


    func openLessonPlanFile() {
        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openTranslation")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadLessonPlan(at: url)
    }


    func loadLessonPlan(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            isApplyingAlignment = true
            lessonPlanContent = text
            isApplyingAlignment = false
            _ = alignTranslationWithSource(showFeedback: false)
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            host.errorMessage = nil
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.translation", url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openTranslation", error.localizedDescription)
        }
    }


    private func runLessonPlanTask(
        displayText: String,
        mode: TranslationAlignmentMode,
        prompt: String
    ) {
        let settings = AppSettings.shared
        if let configError = AppGuard.bookLLMErrorMessage(for: settings) {
            host.errorMessage = configError
            return
        }

        host.assistant.readingAssistantActiveTask = .translation
        host.beginRun(showsExecutionTrace: false)
        host.errorMessage = nil

        let llmMode = AIBookLLMPrompt.Mode.translation
        host.activeTask?.cancel()
        host.activeTask = Task {
            do {
                let outcome = try await host.fetchAssistantReply(
                    prompt: prompt,
                    history: llmMode.apiHistory,
                    settings: settings,
                    llmMode: llmMode
                )

                guard !Task.isCancelled else { return }
                let resolvedPlan = outcome.text.isEmpty ? host.streamingResponse : outcome.text
                applyTranslationResult(resolvedPlan, title: displayText, mode: mode)
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    let message = LLMServiceErrorPresenter.message(for: error, provider: AppSettings.shared.provider)
                    host.errorMessage = message
                }
            }
            host.isLoading = false
            host.isRunning = false
            host.activeTask = nil
            host.resetStreamingState()
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
        host.persistChatSession()
    }


    @discardableResult
    func alignTranslationWithSource(showFeedback: Bool = true) -> Bool {
        if translationAlignment?.isLocked == true {
            if showFeedback {
                host.errorMessage = BookL10n.string("vm.error.alignLocked")
            }
            return false
        }

        let source = lessonPlanSourceText()
        let content = lessonPlanContent
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if showFeedback {
                host.errorMessage = BookL10n.string("vm.error.alignNeedBoth")
            }
            return false
        }

        guard let outcome = TranslationAligner.align(source: source, translation: content) else {
            if showFeedback {
                host.errorMessage = BookL10n.string("vm.error.alignBuildFailed")
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
        host.persistChatSession()
        host.errorMessage = nil

        if showFeedback {
            let alignment = outcome.alignment
            let resegmented = outcome.renderedContent != nil ? BookL10n.string("vm.align.resegmentedSuffix") : ""
            host.document.showTransientSaveMessage(
                BookL10n.format("vm.align.done", alignment.anchoredBlockCount, alignment.blocks.count, resegmented)
            )
        }
        return true
    }


    func rebuildTranslationAlignment(from content: String) -> TranslationAlignment? {
        let source = lessonPlanSourceText()
        guard !source.isEmpty else { return nil }
        return TranslationAligner.align(source: source, translation: content)?.alignment
    }


    func refreshTranslationAlignmentAfterSourceChange() {
        if !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = alignTranslationWithSource(showFeedback: false)
        }
    }


    func repairCollapsedParagraphAlignmentIfNeeded() {
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
        host.persistChatSession()
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.savedLocked"))
    }


    func unlockTranslationAlignment() {
        guard var alignment = translationAlignment, alignment.isLocked else { return }
        alignment.isLocked = false
        translationAlignment = alignment
        host.persistChatSession()
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.unlocked"))
    }


    func updateTranslationTableBlock(
        id: UUID,
        sourceText: String? = nil,
        translationText: String? = nil,
        note: String? = nil
    ) {
        guard !host.isRunning, var alignment = translationAlignment, !alignment.isStale else { return }
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
        host.persistChatSession()
    }


    func splitTranslationTableBlock(
        id: UUID,
        translationBefore: String,
        translationAfter: String
    ) {
        guard !host.isRunning, var alignment = translationAlignment, !alignment.isStale else { return }
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }

        let block = alignment.blocks[index]
        guard block.level != .summary else { return }

        let before = translationBefore.trimmingCharacters(in: .newlines)
        let after = translationAfter.trimmingCharacters(in: .newlines)
        guard !before.isEmpty || !after.isEmpty else { return }

        guard let nextIndex = nextTranslationTableEntryIndex(after: index, in: alignment.blocks) else {
            host.document.showTransientSaveMessage(BookL10n.string("vm.align.cannotMergeDown"))
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
        host.persistChatSession()
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


    func syncTranslationScrollPresentation() {
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
        let fileNS = host.document.fileContent as NSString

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

        if TranslationSourceHasher.hash(host.document.selectedText) == hash {
            return offset(of: host.document.selectedText, preferring: host.document.selectedTextRange ?? host.document.lastCommittedSelectionRange)
        }
        if TranslationSourceHasher.hash(host.document.lastCommittedSelectionText) == hash {
            return offset(of: host.document.lastCommittedSelectionText, preferring: host.document.lastCommittedSelectionRange)
        }
        if TranslationSourceHasher.hash(host.document.fileContent) == hash {
            return offset(of: host.document.fileContent, preferring: nil)
        }
        return offset(of: lessonPlanSourceText(), preferring: host.document.lastCommittedSelectionRange)
    }


    func refreshTranslationAlignmentStaleState(fromManualEdit: Bool = false) {
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
        let candidates = [host.document.fileContent, host.document.selectedText, host.document.lastCommittedSelectionText]
        return candidates.contains { TranslationSourceHasher.hash($0) == alignment.sourceContentHash }
    }


    private func lessonPlanSourceText() -> String {
        let selected = host.document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty { return selected }
        return host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
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
            mode: mode,
            targetLanguage: AppSettings.shared.resolvedTranslationTargetLanguage
        )
    }


    private func lessonPlanFileName() -> String {
        let stem = (host.document.fileName as NSString).deletingPathExtension
        let base = stem.isEmpty || stem == ReadingViewModel.untitledMarker ? BookL10n.string("file.articleStem") : stem
        return "\(base)\(BookL10n.string("vm.filename.translationSuffix"))"
    }

}

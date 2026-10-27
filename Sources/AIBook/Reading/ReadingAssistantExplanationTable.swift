import Foundation

// MARK: - 讲解对照表与全文讲解进度弹出层

extension ReadingAssistantSession {
    var canUseExplanationTableView: Bool {
        guard let alignment = explanationAlignment, !alignment.blocks.isEmpty else { return false }
        return true
    }

    var showsExplanationTableView: Bool {
        explanationTableViewEnabled && canUseExplanationTableView
    }

    var usesStrictExplanationTable: Bool {
        explanationAlignment?.strictParagraphValidated == true
    }

    var isExplanationAlignmentLocked: Bool {
        explanationAlignment?.isLocked == true
    }

    func beginExplanationProgress(title: String) {
        explanationProgressTitle = title
        explanationStreamPreview = ""
        showsExplanationProgressSheet = true
    }

    func endExplanationProgress() {
        showsExplanationProgressSheet = false
        explanationStreamPreview = ""
    }

    func appendExplanationStreamPreview(_ delta: String) {
        guard !delta.isEmpty else { return }
        explanationStreamPreview += delta
    }

    /// 对齐用的原文：有严格对照快照时与快照 hash 一致；否则选区优先，再全文。
    func explanationSourceText() -> String {
        if let hash = explanationAlignment?.sourceContentHash, !hash.isEmpty {
            let full = host.document.fileContent
            if TranslationSourceHasher.hash(full) == hash {
                return full.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let selection = effectiveSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !selection.isEmpty, TranslationSourceHasher.hash(selection) == hash {
                return selection
            }
        }
        let selection = effectiveSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selection.isEmpty { return selection }
        return host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 可对照的讲解正文（不含欢迎语）。
    func explanationBodyForAlignment() -> String {
        explanationSpeakableText()
    }

    /// 全文讲解完成后建对照并默认开表。
    func applyExplanationResult(from reply: String, source: String, title: String) {
        let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReply.isEmpty, !trimmedSource.isEmpty else { return }
        guard let outcome = TranslationAligner.align(
            source: trimmedSource,
            translation: trimmedReply,
            displayTitle: title
        ) else { return }

        isApplyingExplanationAlignment = true
        var alignment = outcome.alignment
        if alignment.mode == .paragraph, !alignment.strictParagraphValidated {
            alignment.provenance = .realignedHeuristic
        }
        explanationAlignment = alignment
        explanationTableViewEnabled = true
        explanationTableFocusTranslationBlockID = alignment.blocks.first?.id
        isApplyingExplanationAlignment = false
        refreshExplanationAlignmentStaleState()
        host.persistChatSession()
    }

    @discardableResult
    func alignExplanationWithSource(showFeedback: Bool = true) -> Bool {
        if explanationAlignment?.isLocked == true {
            if showFeedback {
                host.errorMessage = BookL10n.string("vm.error.alignLocked")
            }
            return false
        }

        let source = explanationSourceText()
        let content = explanationBodyForAlignment()
        guard !source.isEmpty, !content.isEmpty else {
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

        isApplyingExplanationAlignment = true
        if let rendered = outcome.renderedContent {
            syncPrimaryExplanationMessage(with: rendered)
        }
        var alignment = outcome.alignment
        if alignment.mode == .paragraph, !alignment.strictParagraphValidated {
            alignment.provenance = .realignedHeuristic
        }
        explanationAlignment = alignment
        explanationTableViewEnabled = true
        isApplyingExplanationAlignment = false
        refreshExplanationAlignmentStaleState()
        host.persistChatSession()
        host.errorMessage = nil

        if showFeedback {
            let resegmented = outcome.renderedContent != nil ? BookL10n.string("vm.align.resegmentedSuffix") : ""
            host.document.showTransientSaveMessage(
                BookL10n.format("vm.align.done", alignment.anchoredBlockCount, alignment.blocks.count, resegmented)
            )
        }
        return true
    }

    func refreshExplanationAlignmentStaleState() {
        guard !isApplyingExplanationAlignment, var alignment = explanationAlignment else { return }
        let source = explanationSourceText()
        let hash = TranslationSourceHasher.hash(source)
        let stale = hash != alignment.sourceContentHash
        if alignment.isStale != stale {
            alignment.isStale = stale
            explanationAlignment = alignment
        }
    }

    func lockExplanationAlignment() {
        guard var alignment = explanationAlignment, !alignment.isStale else { return }
        alignment.isLocked = true
        explanationAlignment = alignment
        host.persistChatSession()
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.savedLocked"))
    }

    func unlockExplanationAlignment() {
        guard var alignment = explanationAlignment, alignment.isLocked else { return }
        alignment.isLocked = false
        explanationAlignment = alignment
        host.persistChatSession()
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.unlocked"))
    }

    func handleExplanationTableVisibleBlock(_ block: TranslationBlock) {
        guard canUseExplanationTableView, var alignment = explanationAlignment, !alignment.isStale else { return }
        explanationTableHighlightedBlockID = block.id
        let offset = explanationSourceRangeOffsetInFileContent()
        if offset != 0 {
            for index in alignment.blocks.indices where alignment.blocks[index].sourceLength > 0 {
                alignment.blocks[index].sourceLocation += offset
            }
        }
        let mappedBlock = alignment.blocks.first(where: { $0.id == block.id }) ?? block
        guard mappedBlock.isAnchored else { return }
        let sourceRange = mappedBlock.sourceRange
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let proxy = self.host.translation.sourceTextScrollProxy
            if proxy.scrollToCharacterRange(sourceRange, anchor: .top) {
                proxy.highlightRange(sourceRange)
            }
        }
    }

    /// 讲解对照若基于选区，块内 range 需平移到左页全文坐标。
    private func explanationSourceRangeOffsetInFileContent() -> Int {
        guard let hash = explanationAlignment?.sourceContentHash else { return 0 }
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
        return offset(of: explanationSourceText(), preferring: host.document.lastCommittedSelectionRange)
    }

    func updateExplanationTableBlock(
        id: UUID,
        sourceText: String? = nil,
        translationText: String? = nil,
        note: String? = nil
    ) {
        guard !host.isRunning, var alignment = explanationAlignment, !alignment.isStale else { return }
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }
        if usesStrictExplanationTable, sourceText != nil { return }

        let source = explanationSourceText()
        guard !source.isEmpty else { return }

        isApplyingExplanationAlignment = true
        defer { isApplyingExplanationAlignment = false }

        var blocks = alignment.blocks
        var block = blocks[index]

        if let sourceText {
            let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            block.sourceText = trimmed
            if block.level != .summary {
                let searchStart = explanationSourceSearchStart(forBlockAt: index, in: blocks)
                let range = TranslationAlignmentBuilder.reanchorSourceText(trimmed, in: source, searchStart: searchStart)
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

        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: explanationDisplayTitle())
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        explanationAlignment = alignment
        syncPrimaryExplanationMessage(with: rendered.content)
        host.persistChatSession()
    }

    func splitExplanationTableBlock(id: UUID, translationBefore: String, translationAfter: String) {
        guard !host.isRunning, var alignment = explanationAlignment, !alignment.isStale else { return }
        guard !usesStrictExplanationTable else { return }
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }

        let block = alignment.blocks[index]
        guard block.level != .summary else { return }

        let before = translationBefore.trimmingCharacters(in: .newlines)
        let after = translationAfter.trimmingCharacters(in: .newlines)
        guard !before.isEmpty || !after.isEmpty else { return }

        guard let nextIndex = nextExplanationTableEntryIndex(after: index, in: alignment.blocks) else {
            host.document.showTransientSaveMessage(BookL10n.string("vm.align.cannotMergeDown"))
            return
        }

        isApplyingExplanationAlignment = true
        defer { isApplyingExplanationAlignment = false }

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
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: explanationDisplayTitle())
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        explanationAlignment = alignment
        syncPrimaryExplanationMessage(with: rendered.content)
        explanationTableFocusTranslationBlockID = next.id
        host.persistChatSession()
    }

    func clearExplanationTableState() {
        explanationAlignment = nil
        explanationTableViewEnabled = false
        explanationTableHighlightedBlockID = nil
        explanationTableScrollTargetID = nil
        explanationTableFocusTranslationBlockID = nil
    }

    /// 有严格对照时导出可 round-trip 的纯文本；否则导出带标记的对话稿。
    func explanationFileExportContent() -> String {
        if let alignment = explanationAlignment,
           !alignment.isStale,
           alignment.mode == .paragraph,
           !alignment.blocks.isEmpty {
            return TranslationContentFormatter.render(alignment, title: explanationExportTitleFromMessages())
        }
        return explanationTranscriptText()
    }

    /// 用包里的一种语言替换当前讲解。
    func installBundledExplanation(text: String, alignment: TranslationAlignment?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
        } else {
            readingPromptMessages = [
                ReadingAssistantSession.defaultWelcomeMessage,
                ChatMessage(role: .assistant, content: trimmed),
            ]
        }
        if host.isDisplaying(.reading) {
            chatMessages = readingPromptMessages
        }
        explanationSelectionText = explanationTranscriptText()

        isApplyingExplanationAlignment = true
        if var alignment, !trimmed.isEmpty {
            let source = host.document.fileContent
            let hashMatches = TranslationSourceHasher.hash(source) == alignment.sourceContentHash
            let textMatches = TranslationContentFormatter.matchesRenderedContent(alignment, content: trimmed)
            alignment.isStale = !(hashMatches && textMatches)
            explanationAlignment = alignment
            explanationTableViewEnabled = hashMatches && textMatches && !alignment.blocks.isEmpty
        } else {
            explanationAlignment = nil
            explanationTableViewEnabled = false
        }
        isApplyingExplanationAlignment = false
        if explanationAlignment == nil, !trimmed.isEmpty {
            _ = alignExplanationWithSource(showFeedback: false)
        }
        host.persistChatSession()
    }

    /// 写入包时用的讲解正文：有对照表时用无标题的段式文本。
    func bundledExplanationExportText() -> String {
        if let alignment = explanationAlignment,
           !alignment.isStale,
           alignment.mode == .paragraph,
           !alignment.blocks.isEmpty {
            return TranslationContentFormatter.render(alignment)
        }
        let body = explanationBodyForAlignment()
        return body
    }

    func saveExplanationAlignmentSidecar(near txtURL: URL) {
        guard let alignment = explanationAlignment, !alignment.isStale else { return }
        guard alignment.mode == .paragraph else { return }
        ExplanationAlignmentSidecar.write(alignment, near: txtURL)
    }

    /// txt 同目录 sidecar 有效则直接恢复讲解对照表。
    @discardableResult
    func applyExplanationSidecarIfValid(from url: URL, content: String) -> Bool {
        guard let sidecar = ExplanationAlignmentSidecar.read(near: url) else { return false }
        guard explanationSourceTextMatchingSidecar(sidecar) != nil else { return false }
        guard !sidecar.isStale, sidecar.mode == .paragraph else { return false }
        guard TranslationContentFormatter.matchesRenderedContent(sidecar, content: content) else { return false }

        isApplyingExplanationAlignment = true
        var alignment = sidecar
        alignment.provenance = .importedPlain
        alignment.isStale = false
        explanationAlignment = alignment
        explanationTableViewEnabled = true
        isApplyingExplanationAlignment = false
        refreshExplanationAlignmentStaleState()
        host.persistChatSession()
        return true
    }

    /// 与 sidecar 保存时一致的原文（全文或选区）。
    private func explanationSourceTextMatchingSidecar(_ sidecar: TranslationAlignment) -> String? {
        let candidates = [
            host.document.fileContent,
            effectiveSelectedText,
            host.document.lastCommittedSelectionText,
        ]
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if TranslationSourceHasher.hash(trimmed) == sidecar.sourceContentHash {
                return trimmed
            }
        }
        return nil
    }

    private func explanationExportTitleFromMessages() -> String? {
        guard let first = readingPromptMessages.first(where: { message in
            message.role == .assistant && !isReadingWelcomeMessage(message)
        })?.content else { return nil }
        let line = first
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard line.hasPrefix("【"), line.hasSuffix("】"), line.count > 2 else { return nil }
        return String(line.dropFirst().dropLast())
    }

    private func explanationDisplayTitle() -> String? {
        nil
    }

    private func syncPrimaryExplanationMessage(with content: String) {
        guard let id = primaryExplanationAssistantMessageID(),
              let index = readingPromptMessages.firstIndex(where: { $0.id == id }) else { return }
        var messages = readingPromptMessages
        let existing = messages[index]
        messages[index] = ChatMessage(
            id: existing.id,
            role: .assistant,
            content: content,
            thinking: existing.thinking,
            toolSteps: existing.toolSteps
        )
        readingPromptMessages = messages
        if host.isDisplaying(.reading) {
            chatMessages = messages.filter { shouldDisplayInExplanationPanel($0) }
        }
    }

    private func primaryExplanationAssistantMessageID() -> UUID? {
        readingPromptMessages.last(where: { message in
            message.role == .assistant && !isReadingWelcomeMessage(message)
        })?.id
    }

    private func nextExplanationTableEntryIndex(after index: Int, in blocks: [TranslationBlock]) -> Int? {
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

    private func explanationSourceSearchStart(forBlockAt index: Int, in blocks: [TranslationBlock]) -> Int {
        let currentOrder = blocks[index].order
        let previous = blocks
            .filter { $0.level != .summary && $0.order < currentOrder && $0.isAnchored }
            .sorted { $0.order < $1.order }
            .last
        guard let previous else { return 0 }
        return previous.sourceRange.location + previous.sourceRange.length
    }
}

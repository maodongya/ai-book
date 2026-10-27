import Foundation

// MARK: - 按段讲解（严格原文/讲解对照）

extension ReadingAssistantSession {
    /// 全文讲解：按原文段分批请求，验收后写入讲解对话与对照表。
    func runFullTextParagraphExplanation() {
        let source = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.openArticleFirst")
            return
        }
        let displayText = BookL10n.format("vm.display.explainFull", source.count)
        startParagraphExplanationTask(displayText: displayText, source: source, optionalContext: nil)
    }

    /// 选区讲解：以选中文本分段对齐，上下文仅作参考。
    func runSelectionParagraphExplanation() {
        let selection = effectiveSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selection.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.selectParagraph")
            return
        }
        let context = surroundingContext(for: selection, in: host.document.fileContent)
        let displayText = BookL10n.format("vm.display.explainSelection", selection.count)
        startParagraphExplanationTask(displayText: displayText, source: selection, optionalContext: context)
    }

    private func startParagraphExplanationTask(
        displayText: String,
        source: String,
        optionalContext: String?
    ) {
        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {
            host.errorMessage = configError
            return
        }

        host.selectRightPageTab(.readingAssistant)
        selectReadingAssistantPanel(.explanation)
        readingAssistantActiveTask = .explanation
        host.beginRun(showsExecutionTrace: false)
        readingAssistantActiveTask = .explanation
        beginExplanationProgress(title: displayText)
        host.errorMessage = nil

        let llmMode = AIBookLLMPrompt.Mode.readingAssistant
        host.activeTask?.cancel()
        host.activeTask = Task {
            defer { endExplanationProgress() }
            do {
                try await runCoveringParagraphExplanation(
                    displayText: displayText,
                    source: source,
                    optionalContext: optionalContext,
                    settings: AppSettings.shared,
                    llmMode: llmMode
                )
            } catch {
                guard !Task.isCancelled else { return }
                if !(error is CancellationError) {
                    host.errorMessage = LLMServiceErrorPresenter.message(
                        for: error,
                        provider: AppSettings.shared.bookProvider
                    )
                }
            }
            host.isLoading = false
            host.isRunning = false
            host.activeTask = nil
            host.resetStreamingState()
        }
    }

    private func runCoveringParagraphExplanation(
        displayText: String,
        source: String,
        optionalContext: String?,
        settings: AppSettings,
        llmMode: AIBookLLMPrompt.Mode
    ) async throws {
        let index = SourceParagraphIndex.build(from: source)
        guard index.count > 0 else {
            host.errorMessage = BookL10n.string("vm.error.explanationSourceParagraphs")
            return
        }

        var collected: [ParagraphTranslationItem] = []

        for batch in ParagraphTranslationCoverage.batches(count: index.count) {
            try Task.checkCancellation()
            let indices = Array(batch)
            explanationProgressTitle = BookL10n.format(
                "explanation.progress.batch",
                (indices.first ?? 0) + 1,
                (indices.last ?? 0) + 1,
                index.count
            )
            appendExplanationProgressMarker(
                BookL10n.format(
                    "explanation.progress.batchHeader",
                    (indices.first ?? 0) + 1,
                    (indices.last ?? 0) + 1
                )
            )
            let previewStart = explanationStreamPreview.count
            let prompt = ExplanationPromptBuilder.build(
                source: source,
                paragraphIndices: indices,
                optionalContext: optionalContext
            )
            let incoming = try await fetchParagraphExplanationItems(
                prompt: prompt,
                previewStart: previewStart,
                settings: settings,
                llmMode: llmMode
            )
            collected = ParagraphTranslationCoverage.merge(collected, with: incoming)
        }

        var fillRound = 0
        while !ParagraphTranslationCoverage.isComplete(collected, expectedCount: index.count),
              fillRound < ParagraphTranslationCoverage.maxFillRounds {
            try Task.checkCancellation()
            fillRound += 1
            let missing = ParagraphTranslationCoverage.missingIndices(in: collected, expectedCount: index.count)
            explanationProgressTitle = BookL10n.format("explanation.progress.fillMissing", missing.count)
            appendExplanationProgressMarker(BookL10n.format("explanation.progress.fillHeader", missing.count))
            let previewStart = explanationStreamPreview.count
            let prompt = ExplanationPromptBuilder.build(
                source: source,
                paragraphIndices: missing,
                optionalContext: optionalContext
            )
            let incoming = try await fetchParagraphExplanationItems(
                prompt: prompt,
                previewStart: previewStart,
                settings: settings,
                llmMode: llmMode
            )
            collected = ParagraphTranslationCoverage.merge(collected, with: incoming)
        }

        let json = ParagraphTranslationCoverage.encodedJSON(collected)
        let speakText = applyExplanationParagraphResult(json, title: displayText, source: source)
        if let speakText, !host.suppressReplySpeech, !Task.isCancelled {
            speakExplanation(speakText, source: .aiReply)
        }
    }

    private func fetchParagraphExplanationItems(
        prompt: String,
        previewStart: Int,
        settings: AppSettings,
        llmMode: AIBookLLMPrompt.Mode
    ) async throws -> [ParagraphTranslationItem] {
        let outcome = try await host.fetchAssistantReply(
            prompt: prompt,
            history: llmMode.apiHistory,
            settings: settings,
            llmMode: llmMode
        )
        guard !Task.isCancelled else { return [] }
        let streamed = String(explanationStreamPreview.dropFirst(previewStart))
        let resolved = outcome.text.isEmpty ? streamed : outcome.text
        return TranslationAlignmentBuilder.parseParagraphTranslationItems(from: resolved)
    }

    /// 严格段验收；成功返回可朗读的讲解正文。
    @discardableResult
    private func applyExplanationParagraphResult(_ result: String, title: String, source: String) -> String? {
        switch TranslationAlignmentBuilder.buildStrictParagraph(from: result, source: source) {
        case .success(var alignment):
            let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)
            alignment.blocks = rendered.blocks
            alignment.isStale = false
            isApplyingExplanationAlignment = true
            explanationAlignment = alignment
            explanationTableViewEnabled = true
            explanationTableFocusTranslationBlockID = alignment.blocks.first?.id
            isApplyingExplanationAlignment = false
            refreshExplanationAlignmentStaleState()

            let assistantMessage = ChatMessage(role: .assistant, content: rendered.content)
            host.appendDisplayedMessage(assistantMessage, to: .reading)
            host.persistChatSession()
            return rendered.content
        case .failure(let failure):
            host.errorMessage = explanationParagraphValidationErrorMessage(failure)
            return nil
        }
    }

    private func appendExplanationProgressMarker(_ text: String) {
        if !explanationStreamPreview.isEmpty {
            explanationStreamPreview += "\n\n"
        }
        explanationStreamPreview += text + "\n"
    }

    private func explanationParagraphValidationErrorMessage(_ failure: ParagraphAlignmentValidationFailure) -> String {
        switch failure {
        case .countMismatch(let expected, let actual):
            return BookL10n.format("vm.error.paragraphAlign.countMismatch", expected, actual)
        case .indexCoverage:
            return BookL10n.string("vm.error.paragraphAlign.indexCoverage")
        case .emptyTranslation(let index):
            return BookL10n.format("vm.error.paragraphAlign.emptyTranslation", index + 1)
        case .sourceTextMismatch(let index):
            return BookL10n.format("vm.error.paragraphAlign.sourceMismatch", index + 1)
        case .anchoringIncomplete(let expected, let actual):
            return BookL10n.format("vm.error.paragraphAlign.anchoringIncomplete", actual, expected)
        }
    }
}

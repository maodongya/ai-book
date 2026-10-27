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

        let settings = AppSettings.shared
        let targets = settings.explanationTargetLanguages
        guard !targets.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.explanationLanguageMissing")
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
        let starting = host.document.explanationBundle.displayed
        host.document.explanationBundle.preserveDisplayed()
        host.activeTask?.cancel()
        host.activeTask = Task {
            var lastSuccess: TranslationTargetLanguage?
            var pendingSpeech: String?
            var stoppedByError = false
            defer { endExplanationProgress() }
            do {
                for (offset, target) in targets.enumerated() {
                    try Task.checkCancellation()
                    host.errorMessage = nil
                    let scope = languageScopeTitle(target, index: offset + 1, count: targets.count)
                    if host.document.explanationBundle.displayed != target {
                        stopExplanationSpeech()
                        host.document.explanationBundle.present(target)
                    }
                    if !scope.isEmpty {
                        appendExplanationProgressMarker(scope)
                    }
                    let spoken = try await runCoveringParagraphExplanation(
                        displayText: displayText,
                        source: source,
                        optionalContext: optionalContext,
                        settings: settings,
                        llmMode: llmMode,
                        target: target,
                        scope: scope
                    )
                    try Task.checkCancellation()
                    if let spoken {
                        host.document.explanationBundle.capture(languageID: target.rawValue)
                        lastSuccess = target
                        pendingSpeech = spoken
                    } else {
                        pendingSpeech = nil
                    }
                }
            } catch {
                stoppedByError = true
                if !Task.isCancelled, !(error is CancellationError) {
                    host.errorMessage = LLMServiceErrorPresenter.message(
                        for: error,
                        provider: AppSettings.shared.bookProvider
                    )
                }
            }
            let restore = lastSuccess ?? starting
            if host.document.explanationBundle.displayed != restore,
               host.document.bundledLanguages[restore.rawValue]?.hasExplanation == true {
                host.document.explanationBundle.show(restore)
            } else if let lastSuccess, settings.explanationTargetLanguage != lastSuccess {
                settings.explanationTargetLanguage = lastSuccess
            }
            if !stoppedByError, let pendingSpeech, !host.suppressReplySpeech {
                speakExplanation(pendingSpeech, source: .aiReply)
            }
            host.isLoading = false
            host.isRunning = false
            host.activeTask = nil
            host.resetStreamingState()
        }
    }

    /// 多种语言时的进度前缀，例如「日语（2/3）」。
    private func languageScopeTitle(_ language: TranslationTargetLanguage, index: Int, count: Int) -> String {
        guard count > 1 else { return "" }
        return BookL10n.format("translation.progress.language", language.localizedName, index, count)
    }

    private func scopedTitle(_ detail: String, scope: String) -> String {
        guard !scope.isEmpty else { return detail }
        return "\(scope) · \(detail)"
    }

    private func runCoveringParagraphExplanation(
        displayText: String,
        source: String,
        optionalContext: String?,
        settings: AppSettings,
        llmMode: AIBookLLMPrompt.Mode,
        target: TranslationTargetLanguage,
        scope: String
    ) async throws -> String? {
        let index = SourceParagraphIndex.build(from: source)
        guard index.count > 0 else {
            host.errorMessage = BookL10n.string("vm.error.explanationSourceParagraphs")
            return nil
        }

        var collected: [ParagraphTranslationItem] = []

        for batch in ParagraphTranslationCoverage.batches(count: index.count) {
            try Task.checkCancellation()
            let indices = Array(batch)
            explanationProgressTitle = scopedTitle(
                BookL10n.format(
                    "explanation.progress.batch",
                    (indices.first ?? 0) + 1,
                    (indices.last ?? 0) + 1,
                    index.count
                ),
                scope: scope
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
                optionalContext: optionalContext,
                targetLanguage: target
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
            explanationProgressTitle = scopedTitle(
                BookL10n.format("explanation.progress.fillMissing", missing.count),
                scope: scope
            )
            appendExplanationProgressMarker(BookL10n.format("explanation.progress.fillHeader", missing.count))
            let previewStart = explanationStreamPreview.count
            let prompt = ExplanationPromptBuilder.build(
                source: source,
                paragraphIndices: missing,
                optionalContext: optionalContext,
                targetLanguage: target
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
        return applyExplanationParagraphResult(json, title: displayText, source: source)
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

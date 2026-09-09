import Foundation

/// Local alignment of existing source + translation text (no LLM, no rewriting translation).
enum TranslationAligner {
    struct Outcome {
        var alignment: TranslationAlignment
        /// Resegmented readable translation for the right page editor.
        var renderedContent: String?
    }

    static func align(
        source: String,
        translation: String,
        displayTitle: String? = nil
    ) -> Outcome? {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty, !trimmedTranslation.isEmpty else { return nil }

        let mode = inferMode(from: trimmedTranslation)
        let title = displayTitle ?? inferDisplayTitle(from: trimmedTranslation)

        switch mode {
        case .paragraph:
            return alignParagraphMode(
                source: trimmedSource,
                translation: trimmedTranslation,
                title: title
            )
        case .wordByWord:
            return alignWordMode(
                source: trimmedSource,
                translation: trimmedTranslation,
                title: title
            )
        }
    }

    private static func alignParagraphMode(
        source: String,
        translation: String,
        title: String?
    ) -> Outcome? {
        let normalizedSource = TranslationParagraphText.collapsedBlankLines(source)
        let sourceParagraphs = TranslationParagraphText.contentParagraphRanges(in: normalizedSource)
        guard !sourceParagraphs.isEmpty else { return nil }

        let extracted = extractParagraphSegments(from: translation, source: normalizedSource)
        let weights = sourceParagraphs.map { ($0.text as NSString).length }
        let resegmented = TranslationParagraphSegmenter.resegment(
            translation: extracted.translationBody,
            targetCount: sourceParagraphs.count,
            sourceWeights: weights,
            notes: extracted.notes
        )
        guard !resegmented.isEmpty else { return nil }

        var alignment = TranslationAlignmentBuilder.buildParagraphAlignment(
            source: normalizedSource,
            segments: resegmented
        )
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        alignment.sourceContentHash = TranslationSourceHasher.hash(normalizedSource)

        return Outcome(alignment: alignment, renderedContent: rendered.content)
    }

    private static func alignWordMode(
        source: String,
        translation: String,
        title: String?
    ) -> Outcome? {
        var alignment = TranslationAlignmentBuilder.build(
            from: translation,
            source: source,
            mode: .wordByWord
        )
        guard !alignment.blocks.isEmpty else { return nil }

        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)
        alignment.blocks = rendered.blocks
        alignment.isStale = false
        alignment.sourceContentHash = TranslationSourceHasher.hash(source)

        let renderedContent = shouldNormalizeWordContent(original: translation, rendered: rendered.content)
            ? rendered.content
            : nil
        return Outcome(alignment: alignment, renderedContent: renderedContent)
    }

    private struct ExtractedParagraphs {
        var translationBody: String
        var notes: [String?]
    }

    private static func extractParagraphSegments(
        from translation: String,
        source: String
    ) -> ExtractedParagraphs {
        if let structured = structuredParagraphSegments(from: translation, source: source) {
            return structured
        }

        let body = TranslationParagraphText.prepareTranslationBody(translation)
        let paragraphs = TranslationParagraphText.contentParagraphs(in: body)
        if !paragraphs.isEmpty {
            return ExtractedParagraphs(translationBody: paragraphs.joined(separator: "\n\n"), notes: [])
        }
        return ExtractedParagraphs(translationBody: body, notes: [])
    }

    private static func structuredParagraphSegments(
        from translation: String,
        source: String
    ) -> ExtractedParagraphs? {
        var alignment = TranslationAlignmentBuilder.build(
            from: translation,
            source: source,
            mode: .paragraph
        )
        let paragraphBlocks = alignment.blocks
            .filter { $0.level == .paragraph }
            .sorted { $0.order < $1.order }

        guard !paragraphBlocks.isEmpty else { return nil }

        let texts = paragraphBlocks.map {
            TranslationParagraphText.trimParagraphContent($0.translationText)
        }.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return nil }

        let notes = paragraphBlocks.map(\.note)
        return ExtractedParagraphs(
            translationBody: texts.joined(separator: "\n\n"),
            notes: notes
        )
    }

    static func inferMode(from translation: String) -> TranslationAlignmentMode {
        let trimmed = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordEntries = TranslationLineParser.parseWordByWordLines(trimmed)
        if trimmed.contains("\"mode\": \"wordByWord\"") || trimmed.contains("\"entries\"") {
            return .wordByWord
        }
        if trimmed.contains("\"mode\": \"paragraph\"")
            || trimmed.contains("\"blocks\"")
            || trimmed.contains("```json") {
            return .paragraph
        }
        return wordEntries.count >= 2 ? .wordByWord : .paragraph
    }

    private static func inferDisplayTitle(from content: String) -> String? {
        let first = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard first.hasPrefix("【"), first.hasSuffix("】"), first.count > 2 else { return nil }
        return String(first.dropFirst().dropLast())
    }

    private static func shouldNormalizeWordContent(original: String, rendered: String) -> Bool {
        original.contains("```json") || original.contains("\"entries\"")
    }
}

import Foundation

/// 本地对齐已有原文和译文。不改译文，也不调大模型。
enum TranslationAligner {
    /// 对齐结果：块列表 + 是否用了降级分段。
    struct Outcome {
        var alignment: TranslationAlignment
        /// 重切后给右页编辑器的可读译文；逐词且原文已是表格时为 nil。
        var renderedContent: String?
    }

    /// 空原文或空译文回 nil。模式从译文形态推断。
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

    /// 按原文段数重切译文，再 build 对齐。
    private static func alignParagraphMode(
        source: String,
        translation: String,
        title: String?
    ) -> Outcome? {
        let normalizedSource = TranslationParagraphText.collapsedBlankLines(source)
        let sourceParagraphs = TranslationParagraphText.contentParagraphRanges(in: normalizedSource)
        guard !sourceParagraphs.isEmpty else { return nil }

        let extracted = extractParagraphSegments(from: translation, source: normalizedSource)
        let weights = sourceParagraphs.map { ($0.text as NSString).length } // 按原文段长切译文
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
        alignment.blocks = rendered.blocks // 带上 translationRange
        alignment.isStale = false
        alignment.sourceContentHash = TranslationSourceHasher.hash(normalizedSource)
        alignment.strictParagraphValidated = false
        alignment.provenance = .realignedHeuristic

        return Outcome(alignment: alignment, renderedContent: rendered.content)
    }

    /// 逐词：用 LineParser/JSON 建块。原文已是「词 → 译」就不再覆盖右页。
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
        alignment.strictParagraphValidated = false
        alignment.provenance = .aiWordByWordJSON

        let renderedContent = shouldNormalizeWordContent(original: translation, rendered: rendered.content)
            ? rendered.content // JSON 源要换成可读「词 → 译」
            : nil
        return Outcome(alignment: alignment, renderedContent: renderedContent)
    }

    /// 从模型输出抠出的段。空则走本地切段。
    private struct ExtractedParagraphs {
        var translationBody: String
        var notes: [String?]
    }

    /// 按空行切段，丢掉空段。
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

    /// 译文本身已是 JSON/对照表时抽出段。抽不出回 nil。
    private static func structuredParagraphSegments(
        from translation: String,
        source: String
    ) -> ExtractedParagraphs? {
        let alignment = TranslationAlignmentBuilder.build(
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

    /// JSON mode/entries 优先；否则至少两行「词 → 译」才当逐词。
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

    /// 首行【标题】抽出来。不像标题回 nil。
    private static func inferDisplayTitle(from content: String) -> String? {
        let first = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard first.hasPrefix("【"), first.hasSuffix("】"), first.count > 2 else { return nil }
        return String(first.dropFirst().dropLast())
    }

    /// JSON 源才需要换成可读正文，已经是「词 → 译」就别覆盖用户编辑。
    private static func shouldNormalizeWordContent(original: String, rendered: String) -> Bool {
        original.contains("```json") || original.contains("\"entries\"")
    }
}

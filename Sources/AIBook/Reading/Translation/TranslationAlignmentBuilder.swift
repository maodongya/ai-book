import Foundation

enum TranslationAlignmentBuilder {
    static func build(
        from llmText: String,
        source: String,
        mode: TranslationAlignmentMode
    ) -> TranslationAlignment {
        let sourceHash = TranslationSourceHasher.hash(source)
        let trimmed = llmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty(mode: mode, sourceHash: sourceHash)
        }

        if let jsonText = extractJSONText(from: trimmed),
           let alignment = parseJSON(jsonText, source: source, mode: mode, sourceHash: sourceHash) {
            return alignment
        }

        return buildFromPlainText(trimmed, source: source, mode: mode, sourceHash: sourceHash)
    }

    // MARK: - JSON

    private struct ParagraphJSON: Decodable {
        struct Block: Decodable {
            let sourceText: String
            let translationText: String
            let notes: String?
        }

        let mode: String?
        let blocks: [Block]?
    }

    private struct WordByWordJSON: Decodable {
        struct Entry: Decodable {
            let source: String
            let translation: String
            let note: String?
        }

        let mode: String?
        let entries: [Entry]?
        let summary: String?
        let hardPoints: [String]?
    }

    private static func parseJSON(
        _ jsonText: String,
        source: String,
        mode: TranslationAlignmentMode,
        sourceHash: String
    ) -> TranslationAlignment? {
        let data = Data(jsonText.utf8)
        switch mode {
        case .paragraph:
            guard let payload = try? JSONDecoder().decode(ParagraphJSON.self, from: data),
                  let blocks = payload.blocks,
                  !blocks.isEmpty else { return nil }
            let items = blocks.map {
                (sourceText: $0.sourceText, translationText: $0.translationText, note: $0.notes)
            }
            return makeAlignment(
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash
            )
        case .wordByWord:
            guard let payload = try? JSONDecoder().decode(WordByWordJSON.self, from: data) else { return nil }
            var blocks = anchorWordBlocks(payload.entries ?? [], in: source)
            appendSummaryBlocks(
                summary: payload.summary,
                hardPoints: payload.hardPoints,
                to: &blocks,
                source: source
            )
            guard !blocks.isEmpty else { return nil }
            return makeAlignment(mode: .wordByWord, blocks: blocks, sourceHash: sourceHash)
        }
    }

    // MARK: - Plain text fallback

    private static func buildFromPlainText(
        _ text: String,
        source: String,
        mode: TranslationAlignmentMode,
        sourceHash: String
    ) -> TranslationAlignment {
        switch mode {
        case .paragraph:
            let entries = TranslationLineParser.parseParagraphSections(text)
            let items = entries.map {
                (sourceText: $0.sourceText, translationText: $0.translationText, note: $0.note)
            }
            return makeAlignment(
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash,
                markPartialStale: true
            )
        case .wordByWord:
            let entries = TranslationLineParser.parseWordByWordLines(text)
            var blocks = anchorWordEntries(entries, in: source)
            if blocks.isEmpty, !text.isEmpty {
                blocks.append(
                    TranslationBlock(
                        sourceRange: fullSourceRange(source),
                        sourceText: source.trimmingCharacters(in: .whitespacesAndNewlines),
                        translationText: text,
                        level: .summary,
                        order: 0
                    )
                )
            }
            return makeAlignment(
                mode: .wordByWord,
                blocks: blocks,
                sourceHash: sourceHash,
                markPartialStale: true
            )
        }
    }

    // MARK: - Anchoring

    private static func anchorParagraphBlocks(
        _ items: [(sourceText: String, translationText: String, note: String?)],
        in source: String
    ) -> [TranslationBlock] {
        let paragraphs = paragraphRanges(in: source)
        var paragraphIndex = 0

        return items.enumerated().map { order, item in
            var matchedRange = NSRange(location: 0, length: 0)
            var matchedSource = normalized(item.sourceText)

            while paragraphIndex < paragraphs.count {
                let candidate = paragraphs[paragraphIndex]
                if textsMatch(candidate.text, item.sourceText) || textsMatch(candidate.text, item.translationText) {
                    matchedRange = candidate.range
                    matchedSource = candidate.text
                    paragraphIndex += 1
                    break
                }
                paragraphIndex += 1
            }

            return TranslationBlock(
                sourceRange: matchedRange,
                sourceText: matchedSource.isEmpty ? normalized(item.sourceText) : matchedSource,
                translationText: item.translationText,
                note: item.note,
                level: .paragraph,
                order: order
            )
        }
    }

    private static func anchorWordBlocks(
        _ entries: [WordByWordJSON.Entry],
        in source: String
    ) -> [TranslationBlock] {
        anchorWordEntries(
            entries.map {
                TranslationLineParser.ParsedEntry(
                    sourceText: $0.source,
                    translationText: $0.translation,
                    note: $0.note
                )
            },
            in: source
        )
    }

    private static func anchorWordEntries(
        _ entries: [TranslationLineParser.ParsedEntry],
        in source: String
    ) -> [TranslationBlock] {
        let ns = source as NSString
        var searchLocation = 0

        return entries.enumerated().map { order, entry in
            let needle = normalized(entry.sourceText)
            let searchRange = NSRange(location: searchLocation, length: max(0, ns.length - searchLocation))
            let found = ns.range(of: needle, options: [], range: searchRange)
            let range = found.location == NSNotFound ? NSRange(location: 0, length: 0) : found
            if found.location != NSNotFound {
                searchLocation = found.location + found.length
            }
            let level: TranslationBlockLevel = needle.count >= 4 ? .phrase : .word
            return TranslationBlock(
                sourceRange: range,
                sourceText: needle,
                translationText: entry.translationText,
                note: entry.note,
                level: level,
                order: order
            )
        }
    }

    private static func appendSummaryBlocks(
        summary: String?,
        hardPoints: [String]?,
        to blocks: inout [TranslationBlock],
        source: String
    ) {
        var order = (blocks.map(\.order).max() ?? -1) + 1
        let fullRange = fullSourceRange(source)

        if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(
                TranslationBlock(
                    sourceRange: fullRange,
                    sourceText: source.trimmingCharacters(in: .whitespacesAndNewlines),
                    translationText: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    level: .summary,
                    order: order
                )
            )
            order += 1
        }

        if let hardPoints, !hardPoints.isEmpty {
            let text = hardPoints
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            guard !text.isEmpty else { return }
            blocks.append(
                TranslationBlock(
                    sourceRange: fullRange,
                    sourceText: "难点词语",
                    translationText: text,
                    level: .summary,
                    order: order
                )
            )
        }
    }

    private static func paragraphRanges(in source: String) -> [(range: NSRange, text: String)] {
        let ns = source as NSString
        guard ns.length > 0 else { return [] }

        var results: [(NSRange, String)] = []
        var location = 0
        let parts = source.components(separatedBy: "\n\n")

        for (index, part) in parts.enumerated() {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                location += part.utf16.count + (index < parts.count - 1 ? 2 : 0)
                continue
            }
            let searchRange = NSRange(location: location, length: max(0, ns.length - location))
            let found = ns.range(of: part, options: [], range: searchRange)
            if found.location != NSNotFound {
                results.append((found, trimmed))
                location = found.location + found.length + 2
            }
        }

        if results.isEmpty {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                results.append((NSRange(location: 0, length: ns.length), trimmed))
            }
        }
        return results
    }

    private static func fullSourceRange(_ source: String) -> NSRange {
        NSRange(location: 0, length: (source as NSString).length)
    }

    private static func makeAlignment(
        mode: TranslationAlignmentMode,
        blocks: [TranslationBlock],
        sourceHash: String,
        markPartialStale: Bool = false
    ) -> TranslationAlignment {
        let anchored = blocks.filter(\.isAnchored).count
        let stale = markPartialStale || (blocks.isEmpty ? false : anchored < blocks.count)
        return TranslationAlignment(
            mode: mode,
            blocks: blocks,
            sourceContentHash: sourceHash,
            createdAt: Date(),
            isStale: stale
        )
    }

    private static func extractJSONText(from text: String) -> String? {
        if let fenceStart = text.range(of: "```json"),
           let fenceEnd = text[fenceStart.upperBound...].range(of: "```") {
            return String(text[fenceStart.upperBound..<fenceEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let fenceStart = text.range(of: "```"),
           let fenceEnd = text[fenceStart.upperBound...].range(of: "```") {
            let candidate = String(text[fenceStart.upperBound..<fenceEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.hasPrefix("{") { return candidate }
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return nil
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func textsMatch(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalized(lhs)
        let b = normalized(rhs)
        if a.isEmpty || b.isEmpty { return false }
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }
        return false
    }
}

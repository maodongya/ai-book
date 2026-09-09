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

        if looksLikeJSON(trimmed) || extractJSONText(from: trimmed) != nil,
           let alignment = parseJSON(trimmed, source: source, mode: mode, sourceHash: sourceHash) {
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
        switch mode {
        case .paragraph:
            guard let payload = decodeParagraphJSON(from: jsonText),
                  let blocks = payload.blocks,
                  !blocks.isEmpty else { return nil }
            let items = normalizeParagraphItems(
                blocks.map {
                    (
                        sourceText: $0.sourceText,
                        translationText: $0.translationText,
                        note: nonemptyNote($0.notes)
                    )
                },
                source: source
            )
            guard !items.isEmpty else { return nil }
            return makeAlignment(
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash
            )
        case .wordByWord:
            guard let jsonBlob = extractJSONText(from: jsonText) ?? (looksLikeJSON(jsonText) ? stripJSONFences(jsonText) : nil),
                  let payload = try? JSONDecoder().decode(WordByWordJSON.self, from: Data(jsonBlob.utf8)) else {
                return nil
            }
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

    private static func decodeParagraphJSON(from text: String) -> ParagraphJSON? {
        var seen = Set<String>()
        var candidates: [String] = []
        if let extracted = extractJSONText(from: text) {
            candidates.append(extracted)
        }
        candidates.append(text)
        if let repairedFromFull = repairTruncatedParagraphJSON(text) {
            candidates.append(repairedFromFull)
        }

        for candidate in candidates {
            guard seen.insert(candidate).inserted else { continue }
            if let payload = try? JSONDecoder().decode(ParagraphJSON.self, from: Data(candidate.utf8)),
               let blocks = payload.blocks,
               !blocks.isEmpty {
                return payload
            }
            if let repaired = repairTruncatedParagraphJSON(candidate),
               let payload = try? JSONDecoder().decode(ParagraphJSON.self, from: Data(repaired.utf8)),
               let blocks = payload.blocks,
               !blocks.isEmpty {
                return payload
            }
        }
        return nil
    }

    /// Keep complete `blocks` objects when the LLM/file JSON is truncated mid-document.
    private static func repairTruncatedParagraphJSON(_ jsonText: String) -> String? {
        guard jsonText.contains("\"blocks\""), jsonText.contains("\"sourceText\"") else { return nil }
        let objects = extractCompleteJSONObjects(from: jsonText, afterKey: "\"blocks\"")
        guard !objects.isEmpty else { return nil }
        return #"{"mode":"paragraph","blocks":[\#(objects.joined(separator: ","))]}"#
    }

    private static func extractCompleteJSONObjects(from text: String, afterKey key: String) -> [String] {
        guard let keyRange = text.range(of: key),
              let arrayStart = text[keyRange.upperBound...].firstIndex(of: "[") else {
            return []
        }

        var objects: [String] = []
        var index = text.index(after: arrayStart)
        var depth = 0
        var objectStart: String.Index?
        var inString = false
        var escaping = false

        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaping {
                    escaping = false
                } else if character == "\\" {
                    escaping = true
                } else if character == "\"" {
                    inString = false
                }
                index = text.index(after: index)
                continue
            }

            if character == "\"" {
                inString = true
            } else if character == "{" {
                if depth == 0 {
                    objectStart = index
                }
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0, let start = objectStart {
                    objects.append(String(text[start...index]))
                    objectStart = nil
                }
            }
            index = text.index(after: index)
        }
        return objects
    }

    private static func nonemptyNote(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
            let entries = TranslationLineParser.parseParagraphSections(stripDisplayChrome(text))
            let items = normalizeParagraphItems(
                entries.map {
                    (sourceText: $0.sourceText, translationText: $0.translationText, note: $0.note)
                },
                source: source
            )
            return makeAlignment(
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash
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
                sourceHash: sourceHash
            )
        }
    }

    // MARK: - Anchoring

    private static func anchorParagraphBlocks(
        _ items: [(sourceText: String, translationText: String, note: String?)],
        in source: String
    ) -> [TranslationBlock] {
        let paragraphs = paragraphRanges(in: source)
        return items.enumerated().map { order, item in
            if paragraphs.indices.contains(order) {
                let candidate = paragraphs[order]
                return TranslationBlock(
                    sourceRange: candidate.range,
                    sourceText: candidate.text,
                    translationText: item.translationText,
                    note: item.note,
                    level: .paragraph,
                    order: order
                )
            }
            return TranslationBlock(
                sourceRange: NSRange(location: 0, length: 0),
                sourceText: normalized(item.sourceText),
                translationText: item.translationText,
                note: item.note,
                level: .paragraph,
                order: order
            )
        }
    }

    private static func normalizeParagraphItems(
        _ items: [(sourceText: String, translationText: String, note: String?)],
        source: String
    ) -> [(sourceText: String, translationText: String, note: String?)] {
        let paragraphs = paragraphRanges(in: source)
        var resolved: [(sourceText: String, translationText: String, note: String?)] = []

        for item in items {
            if looksLikeJSON(item.translationText),
               let nested = decodeParagraphItems(from: item.translationText),
               nested.count > 1 {
                resolved.append(contentsOf: nested)
            } else {
                resolved.append(
                    (
                        sourceText: item.sourceText,
                        translationText: stripJSONFences(item.translationText),
                        note: item.note
                    )
                )
            }
        }

        if resolved.count <= 1, paragraphs.count > 1 {
            let blob = resolved.first.map(\.translationText) ?? items.first?.translationText ?? ""
            if looksLikeJSON(blob), let nested = decodeParagraphItems(from: blob), nested.count > 1 {
                resolved = nested
            } else {
                let translationParagraphs = paragraphRanges(in: stripJSONFences(blob)).map(\.text)
                if translationParagraphs.count > 1 {
                    resolved = zipParagraphs(paragraphs.map(\.text), translationParagraphs)
                }
            }
        }

        return resolved.filter {
            !$0.translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func zipParagraphs(
        _ sources: [String],
        _ translations: [String]
    ) -> [(sourceText: String, translationText: String, note: String?)] {
        let paired = min(sources.count, translations.count)
        guard paired > 0 else { return [] }

        var items: [(sourceText: String, translationText: String, note: String?)] = (0..<paired).map { index in
            (sourceText: sources[index], translationText: translations[index], note: nil)
        }
        if translations.count > paired {
            let extra = translations[paired...].joined(separator: "\n\n")
            items[paired - 1].translationText += "\n\n\(extra)"
        }
        return items
    }

    private static func decodeParagraphItems(
        from text: String
    ) -> [(sourceText: String, translationText: String, note: String?)]? {
        guard let payload = decodeParagraphJSON(from: text),
              let blocks = payload.blocks,
              blocks.count > 1 else {
            return nil
        }
        return blocks.map {
            (sourceText: $0.sourceText, translationText: $0.translationText, note: nonemptyNote($0.notes))
        }
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("```json")
            || trimmed.contains("\"blocks\"")
            || trimmed.contains("\"mode\"")
            || (trimmed.hasPrefix("{") && trimmed.contains("translationText"))
    }

    private static func stripJSONFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```json") {
            result.removeFirst("```json".count)
        } else if result.hasPrefix("```") {
            result.removeFirst(3)
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("```") {
            result.removeLast(3)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripDisplayChrome(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           first.hasPrefix("【"), first.hasSuffix("】") {
            lines.removeFirst()
        }
        return stripJSONFences(lines.joined(separator: "\n"))
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
        sourceHash: String
    ) -> TranslationAlignment {
        return TranslationAlignment(
            mode: mode,
            blocks: blocks,
            sourceContentHash: sourceHash,
            createdAt: Date(),
            isStale: false
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
        let shorter = a.count < b.count ? a : b
        let longer = a.count < b.count ? b : a
        guard shorter.count >= 12 else { return false }
        let ratio = Double(shorter.count) / Double(max(longer.count, 1))
        return ratio >= 0.45 && longer.contains(shorter)
    }
}

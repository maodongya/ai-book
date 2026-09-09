import Foundation

/// Parses legacy plain-text translation output when JSON is unavailable.
enum TranslationLineParser {
    struct ParsedEntry {
        var sourceText: String
        var translationText: String
        var note: String?
    }

    static func parseWordByWordLines(_ text: String) -> [ParsedEntry] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap(parseWordLine)
    }

    static func parseParagraphSections(_ text: String) -> [ParsedEntry] {
        let chunks = text.components(separatedBy: "\n\n")
        var entries: [ParsedEntry] = []
        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("【") && trimmed.hasSuffix("】") { continue }
            if trimmed.hasPrefix("【注释】") || trimmed.hasPrefix("【难点") { continue }
            if let wordLine = parseWordLine(Substring(trimmed)) {
                entries.append(wordLine)
                continue
            }
            entries.append(ParsedEntry(sourceText: trimmed, translationText: trimmed, note: nil))
        }
        return entries
    }

    private static func parseWordLine(_ line: Substring) -> ParsedEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = [" → ", " -> ", "=>", "→", "－>", "->"]
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let source = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var remainder = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !remainder.isEmpty else { continue }

            var note: String?
            if let open = remainder.lastIndex(of: "（"), remainder.hasSuffix("）") {
                note = String(remainder[remainder.index(after: open)..<remainder.index(before: remainder.endIndex)])
                remainder = String(remainder[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ParsedEntry(sourceText: source, translationText: remainder, note: note)
        }
        return nil
    }
}

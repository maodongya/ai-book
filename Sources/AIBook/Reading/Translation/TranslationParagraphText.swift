import Foundation

/// Normalizes blank lines and splits source/translation into content paragraphs for alignment.
enum TranslationParagraphText {
    private static let blankLinePattern = #"\n[\t \u{00A0}]*\n+"#

    static func normalizedNewlines(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Collapse runs of blank lines to a single paragraph break.
    static func collapsedBlankLines(_ text: String) -> String {
        let normalized = normalizedNewlines(text)
        guard let regex = try? NSRegularExpression(pattern: blankLinePattern) else {
            return normalized
        }
        let ns = normalized as NSString
        return regex.stringByReplacingMatches(
            in: normalized,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "\n\n"
        )
    }

    static func trimParagraphContent(_ text: String) -> String {
        var lines = normalizedNewlines(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeFirst()
        }
        while lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Non-empty paragraphs in `text`, with UTF-16 ranges in the original string.
    static func contentParagraphRanges(in text: String) -> [(range: NSRange, text: String)] {
        let prepared = collapsedBlankLines(text)
        let chunks = splitOnBlankLines(prepared)
        guard !chunks.isEmpty else {
            let trimmed = trimParagraphContent(text)
            guard !trimmed.isEmpty else { return [] }
            let found = (text as NSString).range(of: trimmed)
            guard found.location != NSNotFound else { return [] }
            return [(found, trimmed)]
        }

        let ns = text as NSString
        var results: [(NSRange, String)] = []
        var searchLocation = 0

        for chunk in chunks {
            let paragraph = trimParagraphContent(chunk)
            guard !paragraph.isEmpty else { continue }
            let searchRange = NSRange(location: searchLocation, length: max(0, ns.length - searchLocation))
            let found = findParagraph(in: ns, text: paragraph, range: searchRange)
            guard found.location != NSNotFound else { continue }
            results.append((found, paragraph))
            searchLocation = found.location + found.length
        }
        return results
    }

    static func contentParagraphs(in text: String) -> [String] {
        contentParagraphRanges(in: text).map(\.text)
    }

    static func prepareTranslationBody(_ text: String) -> String {
        let withoutTitle = stripDisplayTitle(text)
        let collapsed = collapsedBlankLines(withoutTitle)
        return contentParagraphs(in: collapsed).joined(separator: "\n\n")
    }

    static func stripDisplayTitle(_ text: String) -> String {
        var lines = normalizedNewlines(text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              first.hasPrefix("【"),
              first.hasSuffix("】") else {
            return collapsedBlankLines(text)
        }
        lines.removeFirst()
        while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            lines.removeFirst()
        }
        return collapsedBlankLines(lines.joined(separator: "\n"))
    }

    private static func splitOnBlankLines(_ text: String) -> [String] {
        let normalized = normalizedNewlines(text)
        guard let regex = try? NSRegularExpression(pattern: blankLinePattern) else {
            return normalized.components(separatedBy: "\n\n")
        }
        let ns = normalized as NSString
        guard ns.length > 0 else { return [] }

        var parts: [String] = []
        var last = 0
        regex.enumerateMatches(in: normalized, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            let chunk = ns.substring(with: NSRange(location: last, length: match.range.location - last))
            parts.append(chunk)
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            parts.append(ns.substring(from: last))
        }
        return parts
    }

    private static func findParagraph(in ns: NSString, text: String, range: NSRange) -> NSRange {
        let direct = ns.range(of: text, options: [], range: range)
        if direct.location != NSNotFound { return direct }

        let escaped = NSRegularExpression.escapedPattern(for: text)
            .replacingOccurrences(of: "\n", with: "\\n[\\t ]*")
        guard let regex = try? NSRegularExpression(pattern: escaped) else {
            return NSRange(location: NSNotFound, length: 0)
        }
        if let match = regex.firstMatch(in: ns as String, range: range) {
            return match.range
        }
        return NSRange(location: NSNotFound, length: 0)
    }
}

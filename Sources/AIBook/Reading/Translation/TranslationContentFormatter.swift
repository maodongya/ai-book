import Foundation

enum TranslationContentFormatter {
    static func render(_ alignment: TranslationAlignment, title: String? = nil) -> String {
        var sections: [String] = []
        if let title, !title.isEmpty {
            sections.append("【\(title)】")
        }

        let sorted = alignment.blocks.sorted { $0.order < $1.order }
        switch alignment.mode {
        case .paragraph:
            sections.append(contentsOf: sorted.filter { $0.level == .paragraph }.map(formatParagraphBlock))
            let notes = sorted.filter { $0.level == .summary }
            if !notes.isEmpty {
                sections.append("【注释】")
                sections.append(contentsOf: notes.map(\.translationText))
            }
        case .wordByWord:
            let entries = sorted.filter { $0.level == .word || $0.level == .phrase }
            if !entries.isEmpty {
                sections.append(entries.map(formatWordBlock).joined(separator: "\n"))
            }
            let summaries = sorted.filter { $0.level == .summary }
            if !summaries.isEmpty {
                sections.append(contentsOf: summaries.map(formatSummaryBlock))
            }
        }

        return sections
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    static func matchesRenderedContent(_ alignment: TranslationAlignment, content: String) -> Bool {
        let rendered = render(alignment).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = contentWithoutDisplayTitle(content)
        return rendered == trimmed
    }

    private static func contentWithoutDisplayTitle(_ content: String) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              first.hasPrefix("【"),
              first.hasSuffix("】") else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        lines.removeFirst()
        while let line = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), line.isEmpty {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatParagraphBlock(_ block: TranslationBlock) -> String {
        var lines = [block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            lines.append("（\(note)）")
        }
        return lines.joined(separator: "\n")
    }

    private static func formatWordBlock(_ block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return "\(source) → \(translation)（\(note)）"
        }
        return "\(source) → \(translation)"
    }

    private static func formatSummaryBlock(_ block: TranslationBlock) -> String {
        block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

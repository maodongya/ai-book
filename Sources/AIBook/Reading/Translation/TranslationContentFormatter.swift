import Foundation

enum TranslationContentFormatter {
    static func render(_ alignment: TranslationAlignment, title: String? = nil) -> String {
        renderIndexed(alignment, title: title).content
    }

    static func renderIndexed(
        _ alignment: TranslationAlignment,
        title: String? = nil
    ) -> (content: String, blocks: [TranslationBlock]) {
        var builder = ContentBuilder()
        var blocks = alignment.blocks.sorted { $0.order < $1.order }

        if let title, !title.isEmpty {
            _ = builder.appendSection("【\(title)】")
        }

        switch alignment.mode {
        case .paragraph:
            let paragraphs = blocks.filter { $0.level == .paragraph }
            for (index, block) in paragraphs.enumerated() {
                let range = builder.appendSection(formatParagraphBlock(block), isFirstInGroup: index == 0)
                applyTranslationRange(range, to: block.id, in: &blocks)
            }

            let notes = blocks.filter { $0.level == .summary }
            if !notes.isEmpty {
                _ = builder.appendSection("【注释】")
                for (index, block) in notes.enumerated() {
                    let range = builder.appendSection(
                        block.translationText.trimmingCharacters(in: .whitespacesAndNewlines),
                        isFirstInGroup: index == 0
                    )
                    applyTranslationRange(range, to: block.id, in: &blocks)
                }
            }
        case .wordByWord:
            let entries = blocks.filter { $0.level == .word || $0.level == .phrase }
            for (index, block) in entries.enumerated() {
                let range = builder.appendLine(formatWordBlock(block), isFirstInGroup: index == 0)
                applyTranslationRange(range, to: block.id, in: &blocks)
            }

            let summaries = blocks.filter { $0.level == .summary }
            for (index, block) in summaries.enumerated() {
                let range = builder.appendSection(formatSummaryBlock(block), isFirstInGroup: index == 0)
                applyTranslationRange(range, to: block.id, in: &blocks)
            }
        }

        return (builder.content, blocks)
    }

    static func indexTranslationRanges(
        in content: String,
        blocks: [TranslationBlock],
        mode: TranslationAlignmentMode
    ) -> [TranslationBlock] {
        let ns = content as NSString
        var searchStart = bodyStartLocation(in: content)
        var updated = blocks.sorted { $0.order < $1.order }

        for index in updated.indices {
            let block = updated[index]
            let formatted: String
            switch block.level {
            case .paragraph:
                formatted = formatParagraphBlock(block)
            case .word, .phrase:
                formatted = formatWordBlock(block)
            case .summary:
                formatted = formatSummaryBlock(block)
            }

            let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let searchRange = NSRange(location: searchStart, length: max(0, ns.length - searchStart))
            let found = ns.range(of: trimmed, options: [], range: searchRange)
            guard found.location != NSNotFound else { continue }

            updated[index].translationLocation = found.location
            updated[index].translationLength = found.length
            searchStart = found.location + found.length

            if mode == .paragraph, block.level == .summary {
                continue
            }
        }

        return updated
    }

    static func matchesRenderedContent(_ alignment: TranslationAlignment, content: String) -> Bool {
        let rendered = TranslationSourceHasher.normalize(render(alignment))
        let trimmed = TranslationSourceHasher.normalize(contentWithoutDisplayTitle(content))
        return rendered == trimmed
    }

    private static func applyTranslationRange(
        _ range: NSRange,
        to blockID: UUID,
        in blocks: inout [TranslationBlock]
    ) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[index].translationLocation = range.location
        blocks[index].translationLength = range.length
    }

    private static func bodyStartLocation(in content: String) -> Int {
        let body = contentWithoutDisplayTitle(content)
        guard !body.isEmpty else { return 0 }
        let found = (content as NSString).range(of: body)
        return found.location == NSNotFound ? 0 : found.location
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

    private struct ContentBuilder {
        private(set) var content = ""

        mutating func appendSection(_ text: String, isFirstInGroup: Bool = true) -> NSRange {
            if !content.isEmpty {
                content += isFirstInGroup ? "\n\n" : "\n"
            }
            return appendRaw(text)
        }

        mutating func appendLine(_ text: String, isFirstInGroup: Bool) -> NSRange {
            if content.isEmpty {
                return appendRaw(text)
            }
            content += isFirstInGroup ? "\n\n" : "\n"
            return appendRaw(text)
        }

        private mutating func appendRaw(_ text: String) -> NSRange {
            let location = (content as NSString).length
            content += text
            return NSRange(location: location, length: (text as NSString).length)
        }
    }
}

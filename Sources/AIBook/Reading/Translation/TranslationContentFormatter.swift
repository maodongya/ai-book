import Foundation

/// 对齐块排成右页可读文本，并回写每块的 translationRange。
enum TranslationContentFormatter {
    /// 只要字符串。需要带 range 的块走 renderIndexed。
    static func render(_ alignment: TranslationAlignment, title: String? = nil) -> String {
        renderIndexed(alignment, title: title).content
    }

    /// 按 order 输出。title 写成【标题】且不参与对齐。
    static func renderIndexed(
        _ alignment: TranslationAlignment,
        title: String? = nil
    ) -> (content: String, blocks: [TranslationBlock]) {
        var builder = ContentBuilder()
        var blocks = alignment.blocks.sorted { $0.order < $1.order }

        if let title, !title.isEmpty {
            _ = builder.appendSection("【\(title)】") // 展示标题，不写回任何块的 range
        }

        switch alignment.mode {
        case .paragraph:
            let paragraphs = blocks.filter { $0.level == .paragraph }
            for block in paragraphs {
                // 段与段之间必须 \n\n，否则保存 txt 再打开会被合成一段。
                let range = builder.appendSection(formatParagraphBlock(block), isFirstInGroup: true)
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

    /// 用户改过纯文本后，按格式化串再搜一遍 range。搜不到就留下一块，不猜。
    static func indexTranslationRanges(
        in content: String,
        blocks: [TranslationBlock],
        mode: TranslationAlignmentMode
    ) -> [TranslationBlock] {
        let ns = content as NSString
        var searchStart = bodyStartLocation(in: content) // 跳过【标题】
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
            guard found.location != NSNotFound else { continue } // 用户改过字就对不上，保持旧 range

            updated[index].translationLocation = found.location
            updated[index].translationLength = found.length
            searchStart = found.location + found.length // 下一块只往后搜，避免重复命中

            if mode == .paragraph, block.level == .summary {
                continue
            }
        }

        return updated
    }

    /// 右页正文是否还是这次 render 的结果。标题不算。
    static func matchesRenderedContent(_ alignment: TranslationAlignment, content: String) -> Bool {
        let rendered = TranslationSourceHasher.normalize(render(alignment))
        let trimmed = TranslationSourceHasher.normalize(contentWithoutDisplayTitle(content))
        return rendered == trimmed
    }

    /// 从 `renderIndexed` 导出的纯文本解析整段译文；格式不符返回 nil。
    static func parseRenderedParagraphSections(
        from content: String
    ) -> [(translationText: String, note: String?)]? {
        var body = contentWithoutDisplayTitle(content)
        guard !body.isEmpty else { return nil }  // 空文件

        if let marker = body.range(of: "\n\n【注释】\n\n") {  // 摘要区不参与段数
            body = String(body[..<marker.lowerBound])
        } else if body.hasPrefix("【注释】\n\n") {
            return []  // 只有注释、没有正文段
        }

        let chunks = body.components(separatedBy: "\n\n")
        var sections: [(String, String?)] = []
        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("【"), trimmed.hasSuffix("】") { continue }  //  stray 标题行
            let parsed = splitRenderedParagraphChunk(trimmed)
            guard !parsed.translationText.isEmpty else { return nil }  // 空段不算导出格式
            sections.append((parsed.translationText, parsed.note))
        }
        return sections.isEmpty ? nil : sections
    }

    /// 段末单独一行的（注）与正文拆开。
    private static func splitRenderedParagraphChunk(_ chunk: String) -> (translationText: String, note: String?) {
        var lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let last = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines),
              last.hasPrefix("（"),
              last.hasSuffix("）"),
              last.count > 2 else {
            return (chunk.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let note = String(last.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        lines.removeLast()
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, note.isEmpty ? nil : note)
    }

    /// 只格式化指定原文范围。
    private static func applyTranslationRange(
        _ range: NSRange,
        to blockID: UUID,
        in blocks: inout [TranslationBlock]
    ) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        blocks[index].translationLocation = range.location
        blocks[index].translationLength = range.length
    }

    /// 【标题】之后正文起点。没有标题从 0。
    private static func bodyStartLocation(in content: String) -> Int {
        let body = contentWithoutDisplayTitle(content)
        guard !body.isEmpty else { return 0 }
        let found = (content as NSString).range(of: body)
        return found.location == NSNotFound ? 0 : found.location
    }

    /// 去掉首行【…】和紧随空行。
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

    /// 译文 + 可选（注）。
    private static func formatParagraphBlock(_ block: TranslationBlock) -> String {
        var lines = [block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            lines.append("（\(note)）")
        }
        return lines.joined(separator: "\n")
    }

    /// 「原文 → 译文（注）」，和 LineParser 对得上。
    private static func formatWordBlock(_ block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return "\(source) → \(translation)（\(note)）"
        }
        return "\(source) → \(translation)"
    }

    /// 摘要块：标题加条目。
    private static func formatSummaryBlock(_ block: TranslationBlock) -> String {
        block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 按块累加字符串，记下每段在结果里的 NSRange。
    private struct ContentBuilder {
        private(set) var content = ""

        /// 组间空两行，组内空一行。
        mutating func appendSection(_ text: String, isFirstInGroup: Bool = true) -> NSRange {
            if !content.isEmpty {
                content += isFirstInGroup ? "\n\n" : "\n"
            }
            return appendRaw(text)
        }

        /// 组内第一行空一行，其余只换行；空串直接追加。
        mutating func appendLine(_ text: String, isFirstInGroup: Bool) -> NSRange {
            if content.isEmpty {
                return appendRaw(text)
            }
            content += isFirstInGroup ? "\n\n" : "\n"
            return appendRaw(text)
        }

        /// 追加后的 range 用 UTF-16，和 NSTextView 对齐。
        private mutating func appendRaw(_ text: String) -> NSRange {
            let location = (content as NSString).length
            content += text
            return NSRange(location: location, length: (text as NSString).length)
        }
    }
}

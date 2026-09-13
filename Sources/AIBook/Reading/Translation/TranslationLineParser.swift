import Foundation

/// JSON 不可用时解析旧版纯文本译文。不是主路径。
enum TranslationLineParser {
    /// 一行「原文 | 译文」，可选括号注。
    struct ParsedEntry {
        var sourceText: String // 原文一侧，空行已在 parse 时丢掉
        var translationText: String // 译文一侧；整段降级时可能和原文相同
        var note: String? // 行尾（注），没有就 nil
    }

    /// 逐词：一行一条，认不出的行丢掉。
    static func parseWordByWordLines(_ text: String) -> [ParsedEntry] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap(parseWordLine) // 无箭头的行不是词条
    }

    /// 整段：按空行切。标题行和【注释】丢掉；认不出箭头就原文=译文占位。
    static func parseParagraphSections(_ text: String) -> [ParsedEntry] {
        let chunks = text.components(separatedBy: "\n\n") // 旧格式段与段之间空一行
        var entries: [ParsedEntry] = []
        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("【") && trimmed.hasSuffix("】") { continue } // 【标题】不是译文
            if trimmed.hasPrefix("【注释】") || trimmed.hasPrefix("【难点") { continue } // 注释放进 note，不当一段
            if let wordLine = parseWordLine(Substring(trimmed)) {
                entries.append(wordLine) // 段里偶发「词 → 译」也收
                continue
            }
            entries.append(ParsedEntry(sourceText: trimmed, translationText: trimmed, note: nil)) // 没箭头：先原文占两边，对齐器再修
        }
        return entries
    }

    /// 认一组箭头。右边（注）撕下来当 note。
    private static func parseWordLine(_ line: Substring) -> ParsedEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = [" → ", " -> ", "=>", "→", "－>", "->"] // 旧模型乱打箭头，都认
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let source = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var remainder = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !remainder.isEmpty else { continue } // 箭头两边都空则换下一种分隔符

            var note: String?
            if let open = remainder.lastIndex(of: "（"), remainder.hasSuffix("）") {
                note = String(remainder[remainder.index(after: open)..<remainder.index(before: remainder.endIndex)]) // 最后一个（…）当注
                remainder = String(remainder[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ParsedEntry(sourceText: source, translationText: remainder, note: note)
        }
        return nil
    }
}

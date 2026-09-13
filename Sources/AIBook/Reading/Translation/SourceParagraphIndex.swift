import Foundation

/// 一段原文在索引串里的 UTF-16 范围与展示文本。
struct ParagraphSlice: Equatable {
    var text: String
    var range: NSRange
}

/// 左页段落索引：Prompt 段数、锚点、表格行数唯一依据。
struct SourceParagraphIndex: Equatable {
    let normalizedSource: String
    let slices: [ParagraphSlice]

    /// 段数，和 slices 同步。
    var count: Int { slices.count }

    /// 与 `TranslationSourceHasher`、分段规则一致地建索引。
    static func build(from raw: String) -> SourceParagraphIndex {
        let normalized = TranslationSourceHasher.normalize(raw)
        let ranges = TranslationParagraphText.contentParagraphRanges(in: normalized)
        let slices = ranges.map { ParagraphSlice(text: $0.text, range: $0.range) }
        return SourceParagraphIndex(normalizedSource: normalized, slices: slices)
    }
}

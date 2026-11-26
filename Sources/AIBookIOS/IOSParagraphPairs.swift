import Foundation

/// 把原文和译文或讲解按行配成上下对照。行数不同时，多出来的一边留空。
enum IOSParagraphPairs {
    /// 空行丢掉，避免对照表里出现空白块。
    static func paragraphs(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 优先用 `.aibook` 对齐块；没有对齐时按段落分行配对。
    static func pairs(
        source: String,
        other: String,
        alignment: TranslationAlignment?
    ) -> (pairs: [(source: String, other: String)], usesAlignment: Bool) {
        if let pairs = pairsFromAlignment(alignment) {
            return (pairs, true)
        }
        return (pairs(source: source, other: other), false)
    }

    private static func pairsFromAlignment(_ alignment: TranslationAlignment?) -> [(source: String, other: String)]? {
        guard let alignment, !alignment.blocks.isEmpty else { return nil }
        let paragraphBlocks = alignment.blocks
            .filter { $0.level == .paragraph }
            .sorted { $0.order < $1.order }
        let blocks = paragraphBlocks.isEmpty
            ? alignment.blocks.sorted { $0.order < $1.order }
            : paragraphBlocks
        guard !blocks.isEmpty else { return nil }
        return blocks.map { (source: $0.sourceText, other: $0.translationText) }
    }

    /// 第 n 行原文配第 n 行另一侧。
    /// 根据原文选区、阅读锚点或对照明亮对应块。
    static func highlightedPairIndex(
        pairs: [(source: String, other: String)],
        source: String,
        selection: String,
        characterAnchor: Int? = nil,
        alignment: TranslationAlignment? = nil
    ) -> Int? {
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let exact = pairs.firstIndex(where: { $0.source == trimmed }) { return exact }
            if let match = pairs.firstIndex(where: { pair in
                !pair.source.isEmpty && (pair.source.contains(trimmed) || trimmed.contains(pair.source))
            }) {
                return match
            }
        }
        guard let anchor = characterAnchor, anchor >= 0 else { return nil }
        let clamped = min(anchor, max((source as NSString).length - 1, 0))
        if let alignment, !alignment.blocks.isEmpty {
            let blocks = alignment.blocks
                .filter { $0.level == .paragraph }
                .sorted { $0.order < $1.order }
            let ordered = blocks.isEmpty ? alignment.blocks.sorted { $0.order < $1.order } : blocks
            if let index = ordered.firstIndex(where: { $0.isAnchored && NSLocationInRange(clamped, $0.sourceRange) }) {
                return index
            }
        }
        let ns = source as NSString
        var searchStart = 0
        for (index, pair) in pairs.enumerated() {
            guard !pair.source.isEmpty else { continue }
            let found = ns.range(
                of: pair.source,
                options: [],
                range: NSRange(location: searchStart, length: max(0, ns.length - searchStart))
            )
            guard found.location != NSNotFound else { continue }
            if NSLocationInRange(clamped, found) { return index }
            searchStart = found.location + found.length
        }
        return nil
    }

    static func pairs(source: String, other: String) -> [(source: String, other: String)] {
        let left = paragraphs(source)
        let right = paragraphs(other)
        let count = max(left.count, right.count)
        guard count > 0 else { return [] }
        return (0 ..< count).map { index in
            (
                source: index < left.count ? left[index] : "",
                other: index < right.count ? right[index] : ""
            )
        }
    }
}

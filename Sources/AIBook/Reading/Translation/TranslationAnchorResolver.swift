import Foundation

/// 译文块对回原文 range，对不上就不高亮。
enum TranslationAnchorResolver {
    /// 左页可见范围落到哪一块。整段取最后一个相交；逐词取离中点最近。
    static func anchorBlock(
        forSourceVisibleRange visibleRange: NSRange, // 左页当前看得见的原文
        in alignment: TranslationAlignment
    ) -> TranslationBlock? {
        let blocks = syncableBlocks(in: alignment) // 去掉总结、没锚定的
        guard !blocks.isEmpty else { return nil }

        switch alignment.mode {
        case .paragraph:
            if let intersecting = blocks.filter({ rangesIntersect($0.sourceRange, visibleRange) }).last {
                return intersecting // 可见区跨多段时跟最后一段，避免停在已滚走的上一段
            }
            return blocks.first { $0.sourceRange.location >= visibleRange.location } // 不相交则取可见区之后最近一块
        case .wordByWord:
            let center = visibleRange.location + max(visibleRange.length / 2, 0) // 用中点，避免选区头尾偏向第一个词
            return blocks.min {
                distance(from: center, to: $0.sourceRange) < distance(from: center, to: $1.sourceRange)
            }
        }
    }

    /// 右页译文可见范围对回块。没有 translationRange 的块不参与。
    static func anchorBlock(
        forTranslationVisibleRange visibleRange: NSRange,
        in alignment: TranslationAlignment
    ) -> TranslationBlock? {
        let blocks = syncableBlocks(in: alignment).filter(\.hasTranslationRange)
        guard !blocks.isEmpty else { return nil }

        switch alignment.mode {
        case .paragraph:
            if let intersecting = blocks.filter({ rangesIntersect($0.translationRange, visibleRange) }).last {
                return intersecting
            }
            return blocks.first { $0.translationRange.location >= visibleRange.location }
        case .wordByWord:
            let center = visibleRange.location + max(visibleRange.length / 2, 0)
            return blocks.min {
                distance(from: center, to: $0.translationRange) < distance(from: center, to: $1.translationRange)
            }
        }
    }

    /// 能同步滚动的块：已锚定、不是篇末总结，按 order。
    static func syncableBlocks(in alignment: TranslationAlignment) -> [TranslationBlock] {
        alignment.blocks
            .filter { $0.isAnchored && $0.level != .summary }
            .sorted { $0.order < $1.order }
    }

    /// NSNotFound 当不相交，避免和 0 搞混。
    private static func rangesIntersect(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        guard lhs.location != NSNotFound, rhs.location != NSNotFound else { return false }
        let lhsEnd = lhs.location + lhs.length
        let rhsEnd = rhs.location + rhs.length
        return lhs.location < rhsEnd && rhs.location < lhsEnd
    }

    /// 点到 range 的距离：落在内部是 0，用来挑最近词。
    private static func distance(from location: Int, to range: NSRange) -> Int {
        guard range.location != NSNotFound else { return Int.max } // 无效 range 排到最后
        if location < range.location {
            return range.location - location
        }
        let rangeEnd = range.location + range.length
        if location > rangeEnd {
            return location - rangeEnd
        }
        return 0 // 点在块内，就是当前块
    }
}

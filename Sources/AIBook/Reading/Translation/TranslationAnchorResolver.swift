import Foundation

enum TranslationAnchorResolver {
    static func anchorBlock(
        forSourceVisibleRange visibleRange: NSRange,
        in alignment: TranslationAlignment
    ) -> TranslationBlock? {
        let blocks = syncableBlocks(in: alignment)
        guard !blocks.isEmpty else { return nil }

        switch alignment.mode {
        case .paragraph:
            if let intersecting = blocks.filter({ rangesIntersect($0.sourceRange, visibleRange) }).last {
                return intersecting
            }
            return blocks.first { $0.sourceRange.location >= visibleRange.location }
        case .wordByWord:
            let center = visibleRange.location + max(visibleRange.length / 2, 0)
            return blocks.min {
                distance(from: center, to: $0.sourceRange) < distance(from: center, to: $1.sourceRange)
            }
        }
    }

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

    static func syncableBlocks(in alignment: TranslationAlignment) -> [TranslationBlock] {
        alignment.blocks
            .filter { $0.isAnchored && $0.level != .summary }
            .sorted { $0.order < $1.order }
    }

    static func blockWithSyncOffset(
        from block: TranslationBlock,
        offset: Int,
        in alignment: TranslationAlignment
    ) -> TranslationBlock {
        guard offset != 0 else { return block }
        let syncable = syncableBlocks(in: alignment)
        guard let index = syncable.firstIndex(where: { $0.id == block.id }) else { return block }
        let targetIndex = min(max(0, index + offset), syncable.count - 1)
        return syncable[targetIndex]
    }

    private static func rangesIntersect(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        guard lhs.location != NSNotFound, rhs.location != NSNotFound else { return false }
        let lhsEnd = lhs.location + lhs.length
        let rhsEnd = rhs.location + rhs.length
        return lhs.location < rhsEnd && rhs.location < lhsEnd
    }

    private static func distance(from location: Int, to range: NSRange) -> Int {
        guard range.location != NSNotFound else { return Int.max }
        if location < range.location {
            return range.location - location
        }
        let rangeEnd = range.location + range.length
        if location > rangeEnd {
            return location - rangeEnd
        }
        return 0
    }
}

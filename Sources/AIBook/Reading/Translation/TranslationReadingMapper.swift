import Foundation

enum TranslationReadingMapper {
    struct Layout: Equatable {
        var translationPageTexts: [String]
        var sourcePageToTranslationPages: [Int: [Int]]
    }

    static func buildLayout(
        alignment: TranslationAlignment,
        sourcePageRanges: [NSRange],
        pageSize: CGSize
    ) -> Layout {
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: nil)
        let translationPages = BookPaginator.paginateWithRanges(
            text: rendered.content,
            pageSize: pageSize
        )

        guard !translationPages.isEmpty else {
            return Layout(translationPageTexts: [], sourcePageToTranslationPages: [:])
        }

        let blockToTranslationPages = mapBlocksToTranslationPages(
            blocks: rendered.blocks,
            translationPages: translationPages
        )
        let sourcePageToTranslationPages = mapSourcePagesToTranslationPages(
            alignment: alignment,
            sourcePageRanges: sourcePageRanges,
            blockToTranslationPages: blockToTranslationPages
        )

        return Layout(
            translationPageTexts: translationPages.map(\.text),
            sourcePageToTranslationPages: sourcePageToTranslationPages
        )
    }

    private static func mapBlocksToTranslationPages(
        blocks: [TranslationBlock],
        translationPages: [BookPaginator.PaginatedPage]
    ) -> [UUID: [Int]] {
        var result: [UUID: [Int]] = [:]
        for block in blocks where block.hasTranslationRange {
            let pages = translationPages.indices.filter { index in
                rangesIntersect(block.translationRange, translationPages[index].range)
            }
            if !pages.isEmpty {
                result[block.id] = pages
            }
        }
        return result
    }

    private static func mapSourcePagesToTranslationPages(
        alignment: TranslationAlignment,
        sourcePageRanges: [NSRange],
        blockToTranslationPages: [UUID: [Int]]
    ) -> [Int: [Int]] {
        var result: [Int: [Int]] = [:]
        let blocks = alignment.blocks.filter(\.isAnchored)

        for (sourceIndex, sourceRange) in sourcePageRanges.enumerated() {
            var pages = Set<Int>()
            for block in blocks where rangesIntersect(block.sourceRange, sourceRange) {
                if let mapped = blockToTranslationPages[block.id] {
                    pages.formUnion(mapped)
                }
            }
            if !pages.isEmpty {
                result[sourceIndex] = pages.sorted()
            }
        }
        return result
    }

    private static func rangesIntersect(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        guard lhs.location != NSNotFound, rhs.location != NSNotFound else { return false }
        let lhsEnd = lhs.location + lhs.length
        let rhsEnd = rhs.location + rhs.length
        return lhs.location < rhsEnd && rhs.location < lhsEnd
    }
}

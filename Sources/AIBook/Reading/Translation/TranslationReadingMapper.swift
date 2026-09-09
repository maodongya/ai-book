import Foundation

enum TranslationReadingMapper {
    struct Layout: Equatable {
        var translationPageTexts: [String]
        var sourcePageToTranslationPage: [Int: Int]
    }

    static func buildLayout(
        alignment: TranslationAlignment,
        sourcePageRanges: [NSRange],
        pageSize: CGSize
    ) -> Layout {
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: nil)
        let plainText = rendered.content
        let blocks = rendered.blocks
        let translationPages = BookPaginator.paginateWithRanges(text: plainText, pageSize: pageSize)

        guard !translationPages.isEmpty else {
            return Layout(translationPageTexts: [], sourcePageToTranslationPage: [:])
        }

        let blockToTranslationPage = mapBlocksToTranslationPages(
            blocks: blocks,
            translationPages: translationPages
        )
        let sourcePageToTranslationPage = mapSourcePagesToTranslationPages(
            alignment: alignment,
            sourcePageRanges: sourcePageRanges,
            blockToTranslationPage: blockToTranslationPage
        )

        return Layout(
            translationPageTexts: translationPages.map(\.text),
            sourcePageToTranslationPage: sourcePageToTranslationPage
        )
    }

    private static func mapBlocksToTranslationPages(
        blocks: [TranslationBlock],
        translationPages: [BookPaginator.PaginatedPage]
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for block in blocks where block.hasTranslationRange {
            guard let pageIndex = translationPages.firstIndex(where: { page in
                rangesIntersect(block.translationRange, page.range)
            }) else { continue }
            result[block.id] = pageIndex
        }
        return result
    }

    private static func mapSourcePagesToTranslationPages(
        alignment: TranslationAlignment,
        sourcePageRanges: [NSRange],
        blockToTranslationPage: [UUID: Int]
    ) -> [Int: Int] {
        var result: [Int: Int] = [:]
        let blocks = alignment.blocks.filter(\.isAnchored)

        for (sourceIndex, sourceRange) in sourcePageRanges.enumerated() {
            let matchedPages = blocks
                .filter { rangesIntersect($0.sourceRange, sourceRange) }
                .compactMap { blockToTranslationPage[$0.id] }
            if let first = matchedPages.min() {
                result[sourceIndex] = first
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

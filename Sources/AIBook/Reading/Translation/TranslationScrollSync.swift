import Foundation

final class TranslationScrollSync: ObservableObject {
    @Published var isEnabled = true

    weak var sourceView: SelectableTextViewProxy?
    weak var translationView: SelectableTextViewProxy?

    var usesTableView = false
    var onScrollTranslationToBlock: ((UUID) -> Void)?

    private var isPropagating = false
    private var lastSourceAnchorID: UUID?
    private var lastTranslationAnchorID: UUID?

    func resetAnchors() {
        lastSourceAnchorID = nil
        lastTranslationAnchorID = nil
        sourceView?.clearHighlight()
    }

    func sourceDidScroll(visibleRange: NSRange, alignment: TranslationAlignment) {
        guard isEnabled, !isPropagating, !alignment.isStale else { return }
        guard let anchored = TranslationAnchorResolver.anchorBlock(
            forSourceVisibleRange: visibleRange,
            in: alignment
        ), anchored.hasTranslationRange else { return }
        guard anchored.id != lastSourceAnchorID else { return }
        let block = anchored

        isPropagating = true
        defer { isPropagating = false }
        if usesTableView {
            onScrollTranslationToBlock?(block.id)
        } else {
            guard translationView?.scrollToCharacterRange(block.translationRange, anchor: .top) == true else {
                return
            }
        }
        lastSourceAnchorID = block.id
        lastTranslationAnchorID = block.id
        DispatchQueue.main.async { [weak self] in
            self?.sourceView?.highlightRange(block.sourceRange)
        }
    }

    func translationDidScroll(visibleRange: NSRange, alignment: TranslationAlignment) {
        guard !usesTableView else { return }
        guard isEnabled, !isPropagating, !alignment.isStale else { return }
        guard let block = TranslationAnchorResolver.anchorBlock(
            forTranslationVisibleRange: visibleRange,
            in: alignment
        ), block.isAnchored else { return }
        guard block.id != lastTranslationAnchorID else { return }

        isPropagating = true
        defer { isPropagating = false }
        guard sourceView?.scrollToCharacterRange(block.sourceRange, anchor: .top) == true else {
            return
        }
        lastTranslationAnchorID = block.id
        lastSourceAnchorID = block.id
        sourceView?.highlightRange(block.sourceRange)
    }

    func translationDidScrollToBlock(_ block: TranslationBlock, alignment: TranslationAlignment) {
        guard usesTableView else { return }
        guard isEnabled, !isPropagating, !alignment.isStale, block.isAnchored else { return }
        guard block.id != lastTranslationAnchorID else { return }

        isPropagating = true
        defer { isPropagating = false }
        guard sourceView?.scrollToCharacterRange(block.sourceRange, anchor: .top) == true else {
            return
        }
        lastTranslationAnchorID = block.id
        lastSourceAnchorID = block.id
        sourceView?.highlightRange(block.sourceRange)
    }
}

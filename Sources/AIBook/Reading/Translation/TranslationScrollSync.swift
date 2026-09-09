import Foundation

final class TranslationScrollSync: ObservableObject {
    @Published var isEnabled = true

    weak var sourceView: SelectableTextViewProxy?
    weak var translationView: SelectableTextViewProxy?

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
        guard let block = TranslationAnchorResolver.anchorBlock(
            forSourceVisibleRange: visibleRange,
            in: alignment
        ), block.hasTranslationRange else { return }
        guard block.id != lastSourceAnchorID else { return }

        isPropagating = true
        lastSourceAnchorID = block.id
        lastTranslationAnchorID = block.id
        translationView?.scrollToCharacterRange(block.translationRange, anchor: .top)
        sourceView?.highlightRange(block.sourceRange)
        isPropagating = false
    }

    func translationDidScroll(visibleRange: NSRange, alignment: TranslationAlignment) {
        guard isEnabled, !isPropagating, !alignment.isStale else { return }
        guard let block = TranslationAnchorResolver.anchorBlock(
            forTranslationVisibleRange: visibleRange,
            in: alignment
        ), block.isAnchored else { return }
        guard block.id != lastTranslationAnchorID else { return }

        isPropagating = true
        lastTranslationAnchorID = block.id
        lastSourceAnchorID = block.id
        sourceView?.scrollToCharacterRange(block.sourceRange, anchor: .top)
        sourceView?.highlightRange(block.sourceRange)
        isPropagating = false
    }
}

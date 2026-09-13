import Foundation

/// 左页选区与右页译文块滚动同步。
final class TranslationScrollSync: ObservableObject {
    @Published var isEnabled = true // 用户可关；关了不再互推滚动

    weak var sourceView: SelectableTextViewProxy? // 左页。weak，页卸掉不挽留
    weak var translationView: SelectableTextViewProxy? // 右页纯文本译文；表格模式不用它滚

    var usesTableView = false // true 时右页是对照表，改走 onScrollTranslationToBlock
    var onScrollTranslationToBlock: ((UUID) -> Void)? // 表格滚到指定块

    private var isPropagating = false // 正在推对面，防止回环再推回来
    private var lastSourceAnchorID: UUID? // 左页上次锚定，相同块不重复滚
    private var lastTranslationAnchorID: UUID? // 右页上次锚定

    /// 换文/换对齐时清高亮和记忆，否则会钉在旧块上。
    func resetAnchors() {
        lastSourceAnchorID = nil
        lastTranslationAnchorID = nil
        sourceView?.clearHighlight()
    }

    /// 左页滚动：对到译文块再推右页。过期对齐或回环中直接回。
    func sourceDidScroll(visibleRange: NSRange, alignment: TranslationAlignment) {
        guard isEnabled, !isPropagating, !alignment.isStale else { return }
        guard let anchored = TranslationAnchorResolver.anchorBlock(
            forSourceVisibleRange: visibleRange,
            in: alignment
        ), anchored.hasTranslationRange else { return } // 没译文 range 滚了也看不见
        guard anchored.id != lastSourceAnchorID else { return } // 还在同一块，别抖
        let block = anchored

        isPropagating = true
        defer { isPropagating = false } // 对面 scroll 回调进来会被挡掉
        if usesTableView {
            onScrollTranslationToBlock?(block.id)
        } else {
            guard translationView?.scrollToCharacterRange(block.translationRange, anchor: .top) == true else {
                return // 滚失败不记 last，下次还能再试
            }
        }
        lastSourceAnchorID = block.id
        lastTranslationAnchorID = block.id // 两边记同一块，回来时当已对齐
        DispatchQueue.main.async { [weak self] in
            self?.sourceView?.highlightRange(block.sourceRange) // 下一拍再高亮，避开滚动动画抢布局
        }
    }

    /// 右页纯文本滚动：对回原文并高亮。表格模式不走这里。
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

    /// 对照表滚到某块：只推左页。isAnchored 为假则原文对不上。
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

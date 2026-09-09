import AppKit
import SwiftUI

enum TextScrollAnchor {
    case top
    case center
    case bottom
}

final class SelectableTextViewProxy {
    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?
    private var highlightedRange: NSRange?

    func attach(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
    }

    func visibleCharacterRange() -> NSRange {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return NSRange(location: 0, length: 0)
        }
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    @discardableResult
    func scrollToCharacterRange(_ range: NSRange, anchor: TextScrollAnchor = .top) -> Bool {
        guard let textView,
              textView.window != nil,
              let scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return false
        }

        let length = textView.textStorage?.length ?? (textView.string as NSString).length
        guard length > 0 else { return false }

        let clamped = Self.clampRange(range, length: length)
        guard clamped.length > 0, NSMaxRange(clamped) <= length else { return false }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return false }

        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height

        let maxY = max(0, textView.bounds.height - scrollView.contentView.bounds.height)
        let targetY: CGFloat
        switch anchor {
        case .top:
            targetY = rect.minY
        case .center:
            targetY = rect.midY - scrollView.contentView.bounds.height / 2
        case .bottom:
            targetY = rect.maxY - scrollView.contentView.bounds.height
        }
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: min(max(0, targetY), maxY)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return true
    }

    func highlightRange(_ range: NSRange?, color: NSColor? = nil) {
        clearHighlight()
        guard let textView, let range, range.length > 0 else { return }
        let clamped = Self.clampRange(range, in: textView.string)
        guard clamped.length > 0 else { return }

        let fill = color ?? NSColor(BookTheme.selection).withAlphaComponent(0.35)
        guard let storage = textView.textStorage, NSMaxRange(clamped) <= storage.length else { return }
        storage.addAttribute(.backgroundColor, value: fill, range: clamped)
        highlightedRange = clamped
    }

    func clearHighlight() {
        guard let textView, let highlightedRange else { return }
        textView.textStorage?.removeAttribute(.backgroundColor, range: highlightedRange)
        self.highlightedRange = nil
    }

    func characterRect(for range: NSRange) -> CGRect? {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        let clamped = Self.clampRange(range, in: textView.string)
        guard clamped.length > 0 else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height
        return rect
    }

    private static func clampRange(_ range: NSRange, in text: String) -> NSRange {
        clampRange(range, length: (text as NSString).length)
    }

    private static func clampRange(_ range: NSRange, length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(max(range.location, 0), length)
        let end = min(max(range.location + max(range.length, 0), location), length)
        return NSRange(location: location, length: end - location)
    }
}

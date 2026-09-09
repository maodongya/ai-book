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

    func scrollToCharacterRange(_ range: NSRange, anchor: TextScrollAnchor = .top) {
        guard let textView else { return }
        let clamped = Self.clampRange(range, in: textView.string)
        guard clamped.location != NSNotFound else { return }

        textView.scrollRangeToVisible(clamped)

        guard anchor == .top,
              let scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: rect.origin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func highlightRange(_ range: NSRange?, color: NSColor? = nil) {
        clearHighlight()
        guard let textView, let range, range.length > 0 else { return }
        let clamped = Self.clampRange(range, in: textView.string)
        guard clamped.length > 0 else { return }

        let fill = color ?? NSColor(BookTheme.selection).withAlphaComponent(0.35)
        textView.textStorage?.addAttribute(.backgroundColor, value: fill, range: clamped)
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
        let length = (text as NSString).length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(max(range.location, 0), length)
        let end = min(max(range.location + range.length, location), length)
        return NSRange(location: location, length: end - location)
    }
}

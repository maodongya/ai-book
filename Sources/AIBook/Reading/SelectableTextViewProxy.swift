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
    private var isScrolling = false
    private var pendingScroll: (range: NSRange, anchor: TextScrollAnchor)?

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
        var containerRect = visibleRect
        let origin = textView.textContainerOrigin
        containerRect.origin.x -= origin.x
        containerRect.origin.y -= origin.y
        let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    @discardableResult
    func scrollToCharacterRange(_ range: NSRange, anchor: TextScrollAnchor = .top) -> Bool {
        guard range.length > 0, range.location != NSNotFound else { return false }

        if textView?.window == nil {
            pendingScroll = (range, anchor)
            DispatchQueue.main.async { [weak self] in self?.flushPendingScrollIfNeeded() }
            return false
        }

        if isScrolling {
            pendingScroll = (range, anchor)
            return false
        }

        return performScroll(to: range, anchor: anchor)
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
        let origin = textView.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y
        return rect
    }

    private func flushPendingScrollIfNeeded() {
        guard let pendingScroll, textView?.window != nil else { return }
        let request = pendingScroll
        self.pendingScroll = nil
        _ = performScroll(to: request.range, anchor: request.anchor)
    }

    private func performScroll(to range: NSRange, anchor: TextScrollAnchor) -> Bool {
        guard !isScrolling else {
            pendingScroll = (range, anchor)
            return false
        }
        guard let textView,
              textView.window != nil,
              let scrollView,
              scrollView.documentView === textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return false
        }

        let length = textView.textStorage?.length ?? (textView.string as NSString).length
        guard length > 0 else { return false }

        let clamped = Self.clampRange(range, length: length)
        guard clamped.length > 0, NSMaxRange(clamped) <= length else { return false }

        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        guard visibleHeight > 1 else {
            pendingScroll = (range, anchor)
            DispatchQueue.main.async { [weak self] in self?.flushPendingScrollIfNeeded() }
            return false
        }

        isScrolling = true
        defer {
            isScrolling = false
            if pendingScroll != nil {
                DispatchQueue.main.async { [weak self] in self?.flushPendingScrollIfNeeded() }
            }
        }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return false }

        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let origin = textView.textContainerOrigin
        rect.origin.x += origin.x
        rect.origin.y += origin.y

        let documentHeight = max(textView.bounds.height, rect.maxY)
        let maxY = max(0, documentHeight - visibleHeight)
        let targetY: CGFloat
        switch anchor {
        case .top:
            targetY = rect.minY
        case .center:
            targetY = rect.midY - visibleHeight / 2
        case .bottom:
            targetY = rect.maxY - visibleHeight
        }
        let clampedY = min(max(0, targetY), maxY)
        let targetPoint = NSPoint(x: 0, y: clampedY)

        if abs(clipView.bounds.origin.y - clampedY) < 1 {
            return true
        }

        clipView.setBoundsOrigin(targetPoint)
        scrollView.flashScrollers()
        return true
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

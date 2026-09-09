import AppKit
import SwiftUI

/// NSScrollView that does not steal first responder — keeps IME working on the inner NSTextView.
private final class ReadingScrollView: NSScrollView {
    override var acceptsFirstResponder: Bool { false }
}

private final class ReadingTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            window?.makeFirstResponder(self)
        }
        return became
    }
}

private func makeReadingTextView() -> ReadingTextView {
    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer(size: NSSize(
        width: 0,
        height: CGFloat.greatestFiniteMagnitude
    ))
    textContainer.widthTracksTextView = true
    textContainer.lineFragmentPadding = 0
    layoutManager.addTextContainer(textContainer)
    let textView = ReadingTextView(frame: .zero, textContainer: textContainer)
    textView.isRichText = false
    return textView
}

struct SelectableTextView: NSViewRepresentable {
    enum Appearance {
        case reading
        case editor

        var font: NSFont {
            switch self {
            case .reading: return BookTheme.readingFont
            case .editor: return NSFont.systemFont(ofSize: 15)
            }
        }

        var textContainerInset: NSSize {
            switch self {
            case .reading: return NSSize(width: 36, height: 32)
            case .editor: return NSSize(width: 12, height: 10)
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .reading: return BookTheme.tokens.typography.readingLineSpacing
            case .editor: return 7
            }
        }

        var paragraphSpacing: CGFloat {
            switch self {
            case .reading: return 14
            case .editor: return 8
            }
        }
    }

    @Binding var text: String
    var onSelectionChange: (String, NSRange?) -> Void
    var onVisibleRangeChange: ((NSRange, CGFloat) -> Void)? = nil
    var scrollProxy: SelectableTextViewProxy? = nil
    var appearance: Appearance = .reading
    var isEditable: Bool = true
    var selectAllSignal: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSelectionChange: onSelectionChange,
            onVisibleRangeChange: onVisibleRangeChange,
            scrollProxy: scrollProxy
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ReadingScrollView()
        let textView = makeReadingTextView()

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.size = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.drawsBackground = false
        applyAppearance(to: textView)

        textView.isEditable = isEditable

        textView.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.appearance = appearance
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        scrollProxy?.attach(textView: textView, scrollView: scrollView)
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            coordinator?.emitVisibleRange()
        }
        return scrollView
    }

    private func applyAppearance(to textView: NSTextView) {
        textView.font = appearance.font
        textView.textColor = NSColor(BookTheme.ink)
        textView.insertionPointColor = NSColor(BookTheme.leather)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(BookTheme.selection),
            .foregroundColor: NSColor(BookTheme.ink),
        ]
        textView.textContainerInset = appearance.textContainerInset
        textView.textContainer?.lineFragmentPadding = 0

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = appearance.lineSpacing
        paragraphStyle.paragraphSpacing = appearance.paragraphSpacing
        textView.defaultParagraphStyle = paragraphStyle
        var typing = textView.typingAttributes
        typing[.font] = appearance.font
        typing[.foregroundColor] = NSColor(BookTheme.ink)
        typing[.paragraphStyle] = paragraphStyle
        textView.typingAttributes = typing
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator

        textView.isEditable = isEditable
        applyAppearance(to: textView)
        coordinator.appearance = appearance
        coordinator.onVisibleRangeChange = onVisibleRangeChange
        scrollProxy?.attach(textView: textView, scrollView: scrollView)

        if coordinator.lastSelectAllSignal != selectAllSignal, selectAllSignal != nil {
            coordinator.lastSelectAllSignal = selectAllSignal
            coordinator.selectAll()
        }

        // Do not overwrite the text view while the user is composing with IME.
        if coordinator.isUpdatingFromView || coordinator.isComposingText || textView.hasMarkedText() { return }
        guard textView.string != text else { return }

        scrollProxy?.clearHighlight()
        coordinator.isUpdatingFromBinding = true
        defer { coordinator.isUpdatingFromBinding = false }

        let selectedRange = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        let location = min(selectedRange.location, length)
        let selectionLength = min(selectedRange.length, length - location)
        textView.setSelectedRange(NSRange(location: location, length: selectionLength))
        DispatchQueue.main.async { [weak coordinator] in
            coordinator?.emitVisibleRange()
        }
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.scrollProxy?.clearHighlight()
        coordinator.textView = nil
        coordinator.scrollView = nil
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var textView: NSTextView?
        var scrollView: NSScrollView?
        var appearance: Appearance = .reading
        var lastSelectAllSignal: UUID?
        @Binding var text: String
        let onSelectionChange: (String, NSRange?) -> Void
        var onVisibleRangeChange: ((NSRange, CGFloat) -> Void)?
        weak var scrollProxy: SelectableTextViewProxy?

        /// True while `textDidChange` is syncing NSTextView → SwiftUI binding.
        var isUpdatingFromView = false
        /// True while `updateNSView` is applying an external binding change.
        var isUpdatingFromBinding = false
        /// True while the user is composing CJK text with an input method.
        var isComposingText = false

        init(
            text: Binding<String>,
            onSelectionChange: @escaping (String, NSRange?) -> Void,
            onVisibleRangeChange: ((NSRange, CGFloat) -> Void)?,
            scrollProxy: SelectableTextViewProxy?
        ) {
            _text = text
            self.onSelectionChange = onSelectionChange
            self.onVisibleRangeChange = onVisibleRangeChange
            self.scrollProxy = scrollProxy
        }

        @objc func boundsDidChange(_ notification: Notification) {
            emitVisibleRange()
        }

        func emitVisibleRange() {
            guard let textView, !textView.hasMarkedText(), !isComposingText else { return }
            let range = scrollProxy?.visibleCharacterRange()
                ?? visibleCharacterRange(in: textView)
            let offset = scrollView?.contentView.bounds.origin.y ?? 0
            onVisibleRangeChange?(range, offset)
        }

        private func visibleCharacterRange(in textView: NSTextView) -> NSRange {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return NSRange(location: 0, length: 0)
            }
            var visibleRect = textView.visibleRect
            let origin = textView.textContainerOrigin
            visibleRect.origin.x -= origin.x
            visibleRect.origin.y -= origin.y
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdatingFromBinding else { return }

            isComposingText = textView.hasMarkedText()
            guard !isComposingText else { return }

            isUpdatingFromView = true
            text = textView.string
            isUpdatingFromView = false
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !textView.hasMarkedText() else { return }

            let range = textView.selectedRange()
            guard range.length > 0, let swiftRange = Range(range, in: textView.string) else {
                onSelectionChange("", nil)
                return
            }
            onSelectionChange(String(textView.string[swiftRange]), range)
        }

        func selectAll() {
            guard let textView else { return }
            guard (textView.string as NSString).length > 0 else { return }

            textView.window?.makeFirstResponder(textView)
            textView.selectAll(nil)

            let range = textView.selectedRange()
            guard range.length > 0, let swiftRange = Range(range, in: textView.string) else {
                onSelectionChange("", nil)
                return
            }
            onSelectionChange(String(textView.string[swiftRange]), range)
        }
    }
}

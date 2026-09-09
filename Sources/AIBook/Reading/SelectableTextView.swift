import AppKit
import SwiftUI

/// NSScrollView that does not steal first responder — keeps IME working on the inner NSTextView.
private final class ReadingScrollView: NSScrollView {
    override var acceptsFirstResponder: Bool { false }
}

/// NSTextView tuned for CJK IME: plain text, no smart substitutions, scroll view stays non-responder.
private final class ReadingTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            window?.makeFirstResponder(self)
        }
        return became
    }
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
    var appearance: Appearance = .reading
    var isEditable: Bool = true
    var selectAllSignal: UUID?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSelectionChange: onSelectionChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ReadingScrollView()
        let textView = ReadingTextView(frame: .zero)

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
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
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
        context.coordinator.appearance = appearance
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

        if coordinator.lastSelectAllSignal != selectAllSignal, selectAllSignal != nil {
            coordinator.lastSelectAllSignal = selectAllSignal
            coordinator.selectAll()
        }

        // Do not overwrite the text view while the user is composing with IME.
        if coordinator.isUpdatingFromView || coordinator.isComposingText || textView.hasMarkedText() { return }
        guard textView.string != text else { return }

        coordinator.isUpdatingFromBinding = true
        defer { coordinator.isUpdatingFromBinding = false }

        let selectedRange = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        let location = min(selectedRange.location, length)
        let selectionLength = min(selectedRange.length, length - location)
        textView.setSelectedRange(NSRange(location: location, length: selectionLength))
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.textView = nil
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var textView: NSTextView?
        var appearance: Appearance = .reading
        var lastSelectAllSignal: UUID?
        @Binding var text: String
        let onSelectionChange: (String, NSRange?) -> Void

        /// True while `textDidChange` is syncing NSTextView → SwiftUI binding.
        var isUpdatingFromView = false
        /// True while `updateNSView` is applying an external binding change.
        var isUpdatingFromBinding = false
        /// True while the user is composing CJK text with an input method.
        var isComposingText = false

        init(text: Binding<String>, onSelectionChange: @escaping (String, NSRange?) -> Void) {
            _text = text
            self.onSelectionChange = onSelectionChange
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

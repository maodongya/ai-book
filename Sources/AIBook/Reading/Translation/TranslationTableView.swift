import AppKit
import SwiftUI

struct TranslationTableView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    let alignment: TranslationAlignment
    var isEditable: Bool = true
    var highlightedBlockID: UUID?
    var scrollTargetBlockID: UUID?
    var focusTranslationBlockID: UUID?
    var onSelectBlock: (TranslationBlock) -> Void
    var onUpdateBlock: (UUID, String?, String?, String?) -> Void
    var onSplitTranslation: (UUID, String, String) -> Void
    var onClearFocusTranslation: () -> Void

    private var entryBlocks: [TranslationBlock] {
        let words = alignment.blocks
            .filter { $0.level == .word || $0.level == .phrase }
            .sorted { $0.order < $1.order }
        if !words.isEmpty { return words }
        return alignment.blocks
            .filter { $0.level == .paragraph }
            .sorted { $0.order < $1.order }
    }

    private var summaryBlocks: [TranslationBlock] {
        alignment.blocks
            .filter { $0.level == .summary }
            .sorted { $0.order < $1.order }
    }

    private var showsNotes: Bool {
        entryBlocks.contains { noteText(for: $0) != nil }
            || (isEditable && alignment.mode == .wordByWord)
    }

    var body: some View {
        GeometryReader { viewport in
            let layout = TranslationTableLayout.columnLayout(
                totalWidth: max(viewport.size.width - 24, 1),
                showsNotes: showsNotes
            )
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entryBlocks) { block in
                            TranslationTableEditableRow(
                                block: block,
                                layout: layout,
                                showsNotes: showsNotes,
                                isEditable: isEditable,
                                isHighlighted: highlightedBlockID == block.id,
                                shouldFocusTranslation: focusTranslationBlockID == block.id,
                                onSelect: { onSelectBlock(block) },
                                onUpdate: { source, translation, note in
                                    onUpdateBlock(block.id, source, translation, note)
                                },
                                onSplitTranslation: { before, after in
                                    onSplitTranslation(block.id, before, after)
                                },
                                onClearFocusTranslation: onClearFocusTranslation
                            )
                            .id(block.id)
                        }

                        if !summaryBlocks.isEmpty {
                            summaryHeader
                            ForEach(summaryBlocks) { block in
                                TranslationTableSummaryRow(
                                    block: block,
                                    isEditable: isEditable,
                                    onUpdate: { translation in
                                        onUpdateBlock(block.id, nil, translation, nil)
                                    }
                                )
                                .id(block.id)
                            }
                        }
                    }
                }
                .onChange(of: scrollTargetBlockID) { blockID in
                    guard let blockID else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(blockID, anchor: .top)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .id(styleManager.revision)
    }

    private var summaryHeader: some View {
        HStack {
            Text("补充说明")
                .font(BookTheme.captionFont.weight(.semibold))
                .foregroundStyle(BookTheme.inkSecondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BookTheme.pageEdge.opacity(0.12))
    }

    private func rowBackground(isHighlighted: Bool) -> some View {
        Group {
            if isHighlighted {
                BookTheme.selection.opacity(0.28)
            } else {
                Color.white.opacity(0.12)
            }
        }
    }

    private var tableDivider: some View {
        Divider()
            .frame(width: 1)
            .background(BookTheme.pageEdge.opacity(0.65))
    }

    private func noteText(for block: TranslationBlock) -> String? {
        let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? nil : note
    }

}

struct TranslationTableColumnHeader: View {
    let alignment: TranslationAlignment
    var isEditable: Bool = true

    private var showsNotes: Bool {
        TranslationTableLayout.showsNotes(for: alignment, isEditable: isEditable)
    }

    var body: some View {
        GeometryReader { viewport in
            let layout = TranslationTableLayout.columnLayout(
                totalWidth: max(viewport.size.width - 24, 1),
                showsNotes: showsNotes
            )
            HStack(alignment: .top, spacing: 0) {
                headerCell("原文", width: layout.source)
                tableDivider
                headerCell("译文", width: layout.translation)
                if showsNotes {
                    tableDivider
                    headerCell("说明", width: layout.note)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 24)
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .frame(width: width, alignment: .leading)
            .font(BookTheme.captionFont.weight(.semibold))
            .foregroundStyle(BookTheme.inkSecondary)
    }

    private var tableDivider: some View {
        Divider()
            .frame(width: 1)
            .background(BookTheme.pageEdge.opacity(0.65))
    }
}

enum TranslationTableLayout {
    static func showsNotes(for alignment: TranslationAlignment, isEditable: Bool) -> Bool {
        let entryBlocks = entryBlocks(for: alignment)
        let hasNotes = entryBlocks.contains {
            let note = $0.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !note.isEmpty
        }
        return hasNotes || (isEditable && alignment.mode == .wordByWord)
    }

    static func columnLayout(totalWidth: CGFloat, showsNotes: Bool) -> ColumnLayout {
        let source = totalWidth * (showsNotes ? 0.34 : 0.40)
        let note = showsNotes ? totalWidth * 0.22 : 0
        let translation = max(0, totalWidth - source - note)
        return ColumnLayout(source: source, translation: translation, note: note)
    }

    private static func entryBlocks(for alignment: TranslationAlignment) -> [TranslationBlock] {
        let words = alignment.blocks
            .filter { $0.level == .word || $0.level == .phrase }
            .sorted { $0.order < $1.order }
        if !words.isEmpty { return words }
        return alignment.blocks
            .filter { $0.level == .paragraph }
            .sorted { $0.order < $1.order }
    }
}

private struct TranslationTableEditableRow: View {
    let block: TranslationBlock
    let layout: ColumnLayout
    let showsNotes: Bool
    let isEditable: Bool
    let isHighlighted: Bool
    let shouldFocusTranslation: Bool
    let onSelect: () -> Void
    let onUpdate: (String?, String?, String?) -> Void
    let onSplitTranslation: (String, String) -> Void
    let onClearFocusTranslation: () -> Void

    @State private var sourceDraft: String
    @State private var translationDraft: String
    @State private var noteDraft: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case source(UUID)
        case translation(UUID)
        case note(UUID)
    }

    init(
        block: TranslationBlock,
        layout: ColumnLayout,
        showsNotes: Bool,
        isEditable: Bool,
        isHighlighted: Bool,
        shouldFocusTranslation: Bool,
        onSelect: @escaping () -> Void,
        onUpdate: @escaping (String?, String?, String?) -> Void,
        onSplitTranslation: @escaping (String, String) -> Void,
        onClearFocusTranslation: @escaping () -> Void
    ) {
        self.block = block
        self.layout = layout
        self.showsNotes = showsNotes
        self.isEditable = isEditable
        self.isHighlighted = isHighlighted
        self.shouldFocusTranslation = shouldFocusTranslation
        self.onSelect = onSelect
        self.onUpdate = onUpdate
        self.onSplitTranslation = onSplitTranslation
        self.onClearFocusTranslation = onClearFocusTranslation
        _sourceDraft = State(initialValue: block.sourceText)
        _translationDraft = State(initialValue: block.translationText)
        _noteDraft = State(initialValue: block.note ?? "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tableCell(
                text: $sourceDraft,
                width: layout.source,
                field: .source(block.id),
                onCommit: commitSource
            )
            tableDivider
            tableCell(
                text: $translationDraft,
                width: layout.translation,
                field: .translation(block.id),
                splitOnReturn: true,
                onCommit: commitTranslation,
                onSplit: { before, after in
                    onSplitTranslation(before, after)
                }
            )
            if showsNotes {
                tableDivider
                tableCell(
                    text: $noteDraft,
                    width: layout.note,
                    field: .note(block.id),
                    muted: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onCommit: commitNote
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard focusedField == nil else { return }
            onSelect()
        }
        .onChange(of: block.sourceText) { sourceDraft = $0 }
        .onChange(of: block.translationText) { translationDraft = $0 }
        .onChange(of: block.note) { noteDraft = $0 ?? "" }
        .onChange(of: focusedField) { field in
            guard field == nil else { return }
            commitAllIfNeeded()
        }
        .onChange(of: shouldFocusTranslation) { shouldFocus in
            guard shouldFocus else { return }
            focusedField = .translation(block.id)
            onClearFocusTranslation()
        }
    }

    @ViewBuilder
    private func tableCell(
        text: Binding<String>,
        width: CGFloat,
        field: Field,
        muted: Bool = false,
        splitOnReturn: Bool = false,
        onCommit: @escaping () -> Void,
        onSplit: ((String, String) -> Void)? = nil
    ) -> some View {
        if isEditable {
            TranslationTableCellEditor(
                text: text,
                width: width,
                muted: muted,
                splitOnReturn: splitOnReturn,
                isFocused: focusedField == field,
                onFocusChange: { focused in
                    focusedField = focused ? field : nil
                },
                onCommit: onCommit,
                onSplit: onSplit
            )
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(text.wrappedValue)
                .frame(width: width, alignment: .leading)
                .font(BookTheme.readingContentFont)
                .foregroundStyle(muted ? BookTheme.inkMuted : BookTheme.ink)
                .textSelection(.enabled)
                .lineSpacing(BookTheme.readingLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
    }

    private var rowBackground: some View {
        Group {
            if isHighlighted {
                BookTheme.selection.opacity(0.28)
            } else {
                Color.white.opacity(0.12)
            }
        }
    }

    private var tableDivider: some View {
        Divider()
            .frame(width: 1)
            .background(BookTheme.pageEdge.opacity(0.65))
    }

    private func commitSource() {
        let trimmed = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != block.sourceText else { return }
        onUpdate(trimmed, nil, nil)
    }

    private func commitTranslation() {
        let trimmed = translationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != block.translationText else { return }
        onUpdate(nil, trimmed, nil)
    }

    private func commitNote() {
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = block.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed != current else { return }
        onUpdate(nil, nil, trimmed)
    }

    private func commitAllIfNeeded() {
        commitSource()
        commitTranslation()
        commitNote()
    }
}

private struct TranslationTableSummaryRow: View {
    let block: TranslationBlock
    let isEditable: Bool
    let onUpdate: (String) -> Void

    @State private var translationDraft: String
    @FocusState private var isFocused: Bool

    init(
        block: TranslationBlock,
        isEditable: Bool,
        onUpdate: @escaping (String) -> Void
    ) {
        self.block = block
        self.isEditable = isEditable
        self.onUpdate = onUpdate
        _translationDraft = State(initialValue: block.translationText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryTitle(for: block))
                .font(BookTheme.captionFont.weight(.semibold))
                .foregroundStyle(BookTheme.leather)

            if isEditable {
                TextField("", text: $translationDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(BookTheme.readingContentFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                    .lineSpacing(BookTheme.readingLineSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { focused in
                        if !focused { commit() }
                    }
            } else {
                Text(block.translationText)
                    .font(BookTheme.readingContentFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BookTheme.selection.opacity(0.12))
        .onChange(of: block.translationText) { translationDraft = $0 }
    }

    private func commit() {
        let trimmed = translationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != block.translationText else { return }
        onUpdate(trimmed)
    }

    private func summaryTitle(for block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if source == "难点词语" { return "难点词语" }
        return "一句话总译"
    }
}

struct ColumnLayout {
    let source: CGFloat
    let translation: CGFloat
    let note: CGFloat
}

private struct TranslationTableCellEditor: NSViewRepresentable {
    @Binding var text: String
    let width: CGFloat
    let muted: Bool
    let splitOnReturn: Bool
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    let onCommit: () -> Void
    let onSplit: ((String, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> TranslationTableTextView {
        let textView = TranslationTableTextView()
        textView.isRichText = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = TranslationTableTextMetrics.containerInset
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator
        textView.splitOnReturn = splitOnReturn
        textView.onSplit = { [weak coordinator = context.coordinator] before, after in
            coordinator?.handleSplit(before: before, after: after)
        }
        textView.preferredWidth = width
        textView.isMuted = muted
        TranslationTableTextMetrics.applyTypography(to: textView, muted: muted)
        TranslationTableTextMetrics.setText(text, on: textView, muted: muted)
        return textView
    }

    func updateNSView(_ textView: TranslationTableTextView, context: Context) {
        context.coordinator.parent = self
        textView.splitOnReturn = splitOnReturn
        textView.onSplit = { [weak coordinator = context.coordinator] before, after in
            coordinator?.handleSplit(before: before, after: after)
        }

        textView.isMuted = muted
        TranslationTableTextMetrics.applyTypography(to: textView, muted: muted)
        textView.preferredWidth = width

        if !context.coordinator.isUpdatingFromView,
           !textView.hasMarkedText(),
           textView.plainString != text {
            let selectedRange = textView.selectedRange()
            TranslationTableTextMetrics.setText(text, on: textView, muted: muted)
            let length = (text as NSString).length
            let location = min(selectedRange.location, length)
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }

        if isFocused, textView.window?.firstResponder !== textView {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationTableCellEditor
        var isUpdatingFromView = false

        init(parent: TranslationTableCellEditor) {
            self.parent = parent
        }

        func handleSplit(before: String, after: String) {
            isUpdatingFromView = true
            parent.onSplit?(before, after)
            isUpdatingFromView = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? TranslationTableTextView else { return }
            guard !textView.isPerformingSplit else { return }
            isUpdatingFromView = true
            parent.text = textView.plainString
            isUpdatingFromView = false
            textView.invalidateIntrinsicContentSize()
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
            parent.onCommit()
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }
    }
}

private enum TranslationTableTextMetrics {
    static let containerInset = NSSize(width: 0, height: 1)

    static func applyTypography(to textView: NSTextView, muted: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = BookTheme.readingLineSpacing

        textView.font = BookTheme.readingFont
        textView.textColor = muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink)
        textView.insertionPointColor = NSColor(BookTheme.leather)
        textView.defaultParagraphStyle = paragraphStyle

        var typing = textView.typingAttributes
        typing[.font] = BookTheme.readingFont
        typing[.foregroundColor] = muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink)
        typing[.paragraphStyle] = paragraphStyle
        textView.typingAttributes = typing
    }

    static func setText(_ text: String, on textView: NSTextView, muted: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = BookTheme.readingLineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: BookTheme.readingFont,
            .foregroundColor: muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink),
            .paragraphStyle: paragraphStyle,
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
    }
}

private final class TranslationTableTextView: NSTextView {
    var preferredWidth: CGFloat = 0
    var splitOnReturn = false
    var isMuted = false
    var isPerformingSplit = false
    var onSplit: ((String, String) -> Void)?

    var plainString: String {
        string
    }

    override var acceptsFirstResponder: Bool { true }

    override var intrinsicContentSize: NSSize {
        guard let textContainer, let layoutManager else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let width = max(preferredWidth, 1)
        textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let verticalInset = textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(used.height + verticalInset, 18))
    }

    override func layout() {
        super.layout()
        if preferredWidth > 0 {
            textContainer?.containerSize = NSSize(
                width: preferredWidth,
                height: .greatestFiniteMagnitude
            )
        }
        invalidateIntrinsicContentSize()
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            window?.makeFirstResponder(self)
        }
        return became
    }

    override func doCommand(by commandSelector: Selector) {
        if commandSelector == #selector(NSResponder.insertNewline(_:)), splitOnReturn {
            if hasMarkedText() {
                super.doCommand(by: commandSelector)
                return
            }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                super.doCommand(by: commandSelector)
                return
            }

            let range = selectedRange()
            let nsString = string as NSString
            let before = nsString.substring(to: range.location)
            let after = nsString.substring(from: range.location)
            isPerformingSplit = true
            TranslationTableTextMetrics.setText(before, on: self, muted: isMuted)
            onSplit?(before, after)
            isPerformingSplit = false
            invalidateIntrinsicContentSize()
            return
        }
        super.doCommand(by: commandSelector)
    }
}

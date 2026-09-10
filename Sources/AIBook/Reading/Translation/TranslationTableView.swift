import SwiftUI

struct TranslationTableView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    let alignment: TranslationAlignment
    var isEditable: Bool = true
    var highlightedBlockID: UUID?
    var scrollTargetBlockID: UUID?
    var onSelectBlock: (TranslationBlock) -> Void
    var onUpdateBlock: (UUID, String?, String?, String?) -> Void

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
            let layout = columnLayout(totalWidth: max(viewport.size.width - 24, 1), showsNotes: showsNotes)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(entryBlocks) { block in
                                TranslationTableEditableRow(
                                    block: block,
                                    layout: layout,
                                    showsNotes: showsNotes,
                                    isEditable: isEditable,
                                    isHighlighted: highlightedBlockID == block.id,
                                    onSelect: { onSelectBlock(block) },
                                    onUpdate: { source, translation, note in
                                        onUpdateBlock(block.id, source, translation, note)
                                    }
                                )
                                .id(block.id)
                            }
                        } header: {
                            columnHeader(layout: layout)
                        }

                        if !summaryBlocks.isEmpty {
                            Section {
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
                            } header: {
                                summaryHeader
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
        .background(tableBackground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .id(styleManager.revision)
    }

    private func columnHeader(layout: ColumnLayout) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            headerCell("原文", width: layout.source)
            tableDivider
            headerCell("译文", width: layout.translation)
            if showsNotes {
                tableDivider
                headerCell("说明", width: layout.note)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(BookTheme.pageEdge.opacity(0.18))
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

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .frame(width: width, alignment: .leading)
            .font(BookTheme.captionFont.weight(.semibold))
            .foregroundStyle(BookTheme.inkSecondary)
    }

    private func rowBackground(isHighlighted: Bool) -> some View {
        Group {
            if isHighlighted {
                BookTheme.selection.opacity(0.28)
            } else {
                Color.white.opacity(0.55)
            }
        }
    }

    private var tableDivider: some View {
        Divider()
            .frame(width: 1)
            .background(BookTheme.pageEdge.opacity(0.65))
    }

    private var tableBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.70))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
            }
    }

    private func noteText(for block: TranslationBlock) -> String? {
        let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? nil : note
    }

    private func columnLayout(totalWidth: CGFloat, showsNotes: Bool) -> ColumnLayout {
        let source = totalWidth * (showsNotes ? 0.34 : 0.40)
        let note = showsNotes ? totalWidth * 0.22 : 0
        let translation = max(0, totalWidth - source - note)
        return ColumnLayout(source: source, translation: translation, note: note)
    }
}

private struct TranslationTableEditableRow: View {
    let block: TranslationBlock
    let layout: ColumnLayout
    let showsNotes: Bool
    let isEditable: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void
    let onUpdate: (String?, String?, String?) -> Void

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
        onSelect: @escaping () -> Void,
        onUpdate: @escaping (String?, String?, String?) -> Void
    ) {
        self.block = block
        self.layout = layout
        self.showsNotes = showsNotes
        self.isEditable = isEditable
        self.isHighlighted = isHighlighted
        self.onSelect = onSelect
        self.onUpdate = onUpdate
        _sourceDraft = State(initialValue: block.sourceText)
        _translationDraft = State(initialValue: block.translationText)
        _noteDraft = State(initialValue: block.note ?? "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            cell(
                text: $sourceDraft,
                width: layout.source,
                field: .source(block.id),
                onCommit: commitSource
            )
            tableDivider
            cell(
                text: $translationDraft,
                width: layout.translation,
                field: .translation(block.id),
                onCommit: commitTranslation
            )
            if showsNotes {
                tableDivider
                cell(
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
        .overlay(alignment: .bottom) { Divider() }
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
    }

    @ViewBuilder
    private func cell(
        text: Binding<String>,
        width: CGFloat,
        field: Field,
        muted: Bool = false,
        onCommit: @escaping () -> Void
    ) -> some View {
        if isEditable {
            TextField("", text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(BookTheme.readingContentFont)
                .foregroundStyle(muted ? BookTheme.inkMuted : BookTheme.ink)
                .lineSpacing(BookTheme.readingLineSpacing)
                .frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .focused($focusedField, equals: field)
                .onSubmit(onCommit)
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
                Color.white.opacity(0.55)
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
        .overlay(alignment: .bottom) { Divider() }
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

private struct ColumnLayout {
    let source: CGFloat
    let translation: CGFloat
    let note: CGFloat
}

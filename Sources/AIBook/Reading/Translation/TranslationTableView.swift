import SwiftUI

struct TranslationTableView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    let alignment: TranslationAlignment
    var highlightedBlockID: UUID?
    var scrollTargetBlockID: UUID?
    var onSelectBlock: (TranslationBlock) -> Void

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
    }

    var body: some View {
        GeometryReader { viewport in
            let layout = columnLayout(totalWidth: max(viewport.size.width - 24, 1), showsNotes: showsNotes)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(entryBlocks) { block in
                                row(for: block, layout: layout)
                                    .id(block.id)
                            }
                        } header: {
                            columnHeader(layout: layout)
                        }

                        if !summaryBlocks.isEmpty {
                            Section {
                                ForEach(summaryBlocks) { block in
                                    summaryRow(for: block)
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

    private func row(for block: TranslationBlock, layout: ColumnLayout) -> some View {
        Button {
            onSelectBlock(block)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                bodyCell(block.sourceText, width: layout.source, emphasized: true)
                tableDivider
                bodyCell(block.translationText, width: layout.translation)
                if showsNotes {
                    tableDivider
                    bodyCell(noteText(for: block) ?? "", width: layout.note, muted: noteText(for: block) == nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(for: block.id))
            .overlay(alignment: .bottom) { Divider() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(for block: TranslationBlock) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryTitle(for: block))
                .font(BookTheme.captionFont.weight(.semibold))
                .foregroundStyle(BookTheme.leather)
            Text(block.translationText)
                .font(BookTheme.readingContentFont)
                .foregroundStyle(BookTheme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BookTheme.selection.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func summaryTitle(for block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if source == "难点词语" { return "难点词语" }
        return "一句话总译"
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .frame(width: width, alignment: .leading)
            .font(BookTheme.captionFont.weight(.semibold))
            .foregroundStyle(BookTheme.inkSecondary)
    }

    private func bodyCell(
        _ text: String,
        width: CGFloat,
        emphasized: Bool = false,
        muted: Bool = false
    ) -> some View {
        Text(text)
            .frame(width: width, alignment: .leading)
            .font(BookTheme.readingContentFont)
            .foregroundStyle(muted ? BookTheme.inkMuted : BookTheme.ink)
            .textSelection(.enabled)
            .lineSpacing(BookTheme.readingLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private func rowBackground(for blockID: UUID) -> some View {
        Group {
            if highlightedBlockID == blockID {
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

private struct ColumnLayout {
    let source: CGFloat
    let translation: CGFloat
    let note: CGFloat
}

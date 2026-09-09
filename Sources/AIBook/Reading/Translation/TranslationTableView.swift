import SwiftUI

struct TranslationTableView: View {
    let alignment: TranslationAlignment
    var highlightedBlockID: UUID?
    var scrollTargetBlockID: UUID?
    var onVisibleBlockChange: (TranslationBlock) -> Void

    private var entryBlocks: [TranslationBlock] {
        alignment.blocks
            .filter { $0.level == .word || $0.level == .phrase }
            .sorted { $0.order < $1.order }
    }

    private var summaryBlocks: [TranslationBlock] {
        alignment.blocks
            .filter { $0.level == .summary }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(entryBlocks) { block in
                                row(for: block)
                                    .id(block.id)
                            }
                        } header: {
                            columnHeader
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
                .coordinateSpace(name: TranslationTableMetrics.coordinateSpaceName)
                .onPreferenceChange(TranslationRowFramePreference.self) { frames in
                    reportVisibleBlock(frames: frames, viewportHeight: viewport.size.height)
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
    }

    private var columnHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            headerCell("原文", width: TranslationTableMetrics.sourceColumnWidth)
            tableDivider
            headerCell("译文", flexible: true)
            tableDivider
            headerCell("说明", width: TranslationTableMetrics.noteColumnWidth)
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

    private func row(for block: TranslationBlock) -> some View {
        HStack(alignment: .top, spacing: 0) {
            bodyCell(block.sourceText, width: TranslationTableMetrics.sourceColumnWidth, emphasized: true)
            tableDivider
            bodyCell(block.translationText, flexible: true)
            tableDivider
            bodyCell(block.note ?? "—", width: TranslationTableMetrics.noteColumnWidth, muted: block.note == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground(for: block.id))
        .overlay(alignment: .bottom) { Divider() }
        .background(rowGeometryReporter(for: block.id))
    }

    private func summaryRow(for block: TranslationBlock) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryTitle(for: block))
                .font(BookTheme.captionFont.weight(.semibold))
                .foregroundStyle(BookTheme.leather)
            Text(block.translationText)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BookTheme.selection.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func rowGeometryReporter(for blockID: UUID) -> some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: TranslationRowFramePreference.self,
                value: [
                    TranslationRowFrame(
                        id: blockID,
                        frame: geo.frame(in: .named(TranslationTableMetrics.coordinateSpaceName))
                    ),
                ]
            )
        }
    }

    private func reportVisibleBlock(frames: [TranslationRowFrame], viewportHeight: CGFloat) {
        let candidates = frames.filter { frame in
            frame.frame.maxY > 0 && frame.frame.minY < viewportHeight
        }
        guard let blockID = candidates.min(by: {
            abs($0.frame.minY) < abs($1.frame.minY)
        })?.id,
            let block = entryBlocks.first(where: { $0.id == blockID }) else { return }
        onVisibleBlockChange(block)
    }

    private func summaryTitle(for block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if source == "难点词语" { return "难点词语" }
        return "一句话总译"
    }

    private func headerCell(_ title: String, width: CGFloat? = nil, flexible: Bool = false) -> some View {
        Group {
            if flexible {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(title)
                    .frame(width: width ?? 0, alignment: .leading)
            }
        }
        .font(BookTheme.captionFont.weight(.semibold))
        .foregroundStyle(BookTheme.inkSecondary)
    }

    private func bodyCell(
        _ text: String,
        width: CGFloat? = nil,
        flexible: Bool = false,
        emphasized: Bool = false,
        muted: Bool = false
    ) -> some View {
        Group {
            if flexible {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .frame(width: width ?? 0, alignment: .leading)
            }
        }
        .font(emphasized ? BookTheme.labelFont : BookTheme.captionFont)
        .foregroundStyle(muted ? BookTheme.inkMuted : BookTheme.ink)
        .textSelection(.enabled)
        .lineSpacing(3)
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
}

private enum TranslationTableMetrics {
    static let coordinateSpaceName = "translationTableScroll"
    static let sourceColumnWidth: CGFloat = 96
    static let noteColumnWidth: CGFloat = 120
}

private struct TranslationRowFrame: Equatable {
    let id: UUID
    let frame: CGRect
}

private struct TranslationRowFramePreference: PreferenceKey {
    static var defaultValue: [TranslationRowFrame] = []

    static func reduce(value: inout [TranslationRowFrame], nextValue: () -> [TranslationRowFrame]) {
        var merged = Dictionary(uniqueKeysWithValues: value.map { ($0.id, $0) })
        for frame in nextValue() {
            merged[frame.id] = frame
        }
        value = merged.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

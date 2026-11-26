import SwiftUI

/// iPhone 上的对照：上一格原文、下一格译文或讲解，浅色方格线连成一张表。
struct IOSCompareList: View {
    @Environment(\.colorScheme) private var colorScheme
    var pairs: [(source: String, other: String)]
    var highlightedPairIndex: Int?
    var otherColumnTitleKey = "target.translation"
    var showsColumnHeader = true
    var editableOther = false
    var onSelectSource: ((Int) -> Void)?
    var onEditOther: ((Int, String) -> Void)?

    private var gridLine: Color {
        IOSPaper.panelBorder.opacity(colorScheme == .dark ? 0.85 : 1)
    }
    private var highlightFill: Color { IOSPaper.inkMuted.opacity(0.12) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if showsColumnHeader {
                        columnHeader
                    }
                    ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                        compareGroup(index: index, pair: pair)
                    }
                }
                .overlay {
                    Rectangle().stroke(gridLine, lineWidth: 1)
                }
                .padding(20)
            }
            .onAppear { scrollIfNeeded(proxy) }
            .onChange(of: highlightedPairIndex) { _, _ in scrollIfNeeded(proxy) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("ios.compareList")
    }

    private var columnHeader: some View {
        VStack(spacing: 0) {
            headerCell(BookL10n.string("context.label.source"))
            gridDivider
            headerCell(BookL10n.string(otherColumnTitleKey))
            gridDivider
        }
    }

    private func headerCell(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(IOSPaper.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(IOSPaper.ink.opacity(0.06))
    }

    @ViewBuilder
    private func compareGroup(index: Int, pair: (source: String, other: String)) -> some View {
        let highlighted = highlightedPairIndex == index
        VStack(spacing: 0) {
            sourceCell(pair.source, index: index, highlighted: highlighted)
                .id("compare-source-\(index)")
            gridDivider
            otherCell(pair.other, index: index, highlighted: highlighted)
            if index < pairs.count - 1 {
                gridDivider
            }
        }
    }

    private func sourceCell(_ text: String, index: Int, highlighted: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(IOSPaper.readingFont)
            .foregroundStyle(IOSPaper.ink)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(highlighted ? highlightFill : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { onSelectSource?(index) }
            .accessibilityLabel("\(index + 1), \(BookL10n.string("context.label.source")), \(text)")
    }

    @ViewBuilder
    private func otherCell(_ text: String, index: Int, highlighted: Bool) -> some View {
        let label = "\(index + 1), \(BookL10n.string(otherColumnTitleKey)), \(text)"
        if editableOther, let onEditOther {
            IOSCompareEditableOtherCell(
                index: index,
                text: text,
                highlighted: highlighted,
                onEdit: onEditOther
            )
            .accessibilityLabel(label)
        } else {
            Text(text.isEmpty ? " " : text)
                .font(IOSPaper.readingFont)
                .foregroundStyle(IOSPaper.inkSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(highlighted ? highlightFill : Color.clear)
                .accessibilityLabel(label)
        }
    }

    private func scrollIfNeeded(_ proxy: ScrollViewProxy) {
        guard let index = highlightedPairIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo("compare-source-\(index)", anchor: .top)
        }
    }

    private var gridDivider: some View {
        Rectangle()
            .fill(gridLine)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// 对照表译文格：随内容增高，完整展示每一段。
private struct IOSCompareEditableOtherCell: View {
    let index: Int
    let text: String
    let highlighted: Bool
    let onEdit: (Int, String) -> Void
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var draft = ""

    var body: some View {
        let tokens = styleManager.tokens
        let font = tokens.typography.uiFont(size: tokens.typography.readingSize)
        let fill = highlighted ? UIColor(IOSPaper.ink.opacity(0.1)) : nil
        IOSCompareGrowingTextView(
            text: $draft,
            font: font,
            textColor: UIColor(IOSPaper.inkSecondary),
            highlightColor: fill
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { draft = text }
        .onChange(of: text) { _, fresh in
            if draft != fresh { draft = fresh } // 对齐或外部改写时跟上
        }
        .onChange(of: draft) { _, fresh in
            onEdit(index, fresh) // 编辑写回文档
        }
    }
}
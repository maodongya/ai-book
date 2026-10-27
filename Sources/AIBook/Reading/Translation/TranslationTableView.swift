import AppKit
import SwiftUI

/// 右页对照表。单元格内联编辑。
struct TranslationTableView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared  // 换字体整页重建

    let alignment: TranslationAlignment  // 当前对齐，行数据源
    var isEditable: Bool = true  // 跑着时宿主会关掉编辑
    var isSourceColumnEditable: Bool = true  // 严格段对齐时原文列只读
    var allowsSplitTranslation: Bool = true  // 严格段对齐禁止回车拆行
    var highlightedBlockID: UUID?  // 左页跟滚高亮的块
    var scrollTargetBlockID: UUID?  // 要滚到顶的块
    var focusTranslationBlockID: UUID?  // 打开后聚焦译文格，用过即清
    var onSelectBlock: (TranslationBlock) -> Void  // 点行：宿主记下可见块，好跟滚
    var onUpdateBlock: (UUID, String?, String?, String?) -> Void  // 提交原文/译文/注，nil 表示这列没改
    var onSplitTranslation: (UUID, String, String) -> Void  // 回车拆成两块
    var onClearFocusTranslation: () -> Void  // 聚焦过一次就清，避免反复抢焦

    /// 对照表正文行，不含 summary。
    private var entryBlocks: [TranslationBlock] {
        let words = alignment.blocks  // 先看词/短语级，有才用，否则整段
            .filter { $0.level == .word || $0.level == .phrase }  // 词表模式的细行
            .sorted { $0.order < $1.order }  // 按对齐序，不按原文出现序
        if !words.isEmpty { return words }  // 有细行就不用整段，避免两套叠
        return alignment.blocks  // 退回段级
            .filter { $0.level == .paragraph }  // 段级对照
            .sorted { $0.order < $1.order }  // 按对齐序，不按原文出现序
    }

    /// 文末 summary 行。
    private var summaryBlocks: [TranslationBlock] {
        alignment.blocks  // summary 从同一份 blocks 抽
            .filter { $0.level == .summary }  // 文末摘要，单独一区
            .sorted { $0.order < $1.order }  // 按对齐序，不按原文出现序
    }

    /// 有注或可编辑才留注列。
    private var showsNotes: Bool {
        entryBlocks.contains { noteText(for: $0) != nil }  // 任一细行有注就留注列
            || (isEditable && alignment.mode == .wordByWord)  // 词表可编辑时空注也留列，方便加注
    }

    /// 表头 + 正文行 + summary。
    var body: some View {
        GeometryReader { viewport in  // 量视口算列宽
            let layout = TranslationTableLayout.columnLayout(  // 按视口宽重算三列
                totalWidth: max(viewport.size.width - 24, 1),  // 扣掉左右 padding，至少 1 防除零
                showsNotes: showsNotes  // 有注列才分 22% 给注
            )
            ScrollViewReader { proxy in  // 用来 scrollTo
                ScrollView {  // 超出就滚
                    LazyVStack(spacing: 0) {  // 行贴行，分隔靠细线
                        ForEach(entryBlocks) { block in  // 正文行，不含 summary
                            TranslationTableEditableRow(  // 可编辑三列
                                block: block,
                                layout: layout,
                                showsNotes: showsNotes,
                                isEditable: isEditable,
                                isSourceColumnEditable: isSourceColumnEditable,
                                allowsSplitTranslation: allowsSplitTranslation,
                                isHighlighted: highlightedBlockID == block.id,  // 跟滚命中浅金底
                                shouldFocusTranslation: focusTranslationBlockID == block.id,  // 译完滚过来时聚焦译文格
                                onSelect: { onSelectBlock(block) },  // 点行同步左页
                                onUpdate: { source, translation, note in
                                    onUpdateBlock(block.id, source, translation, note)  // 三列草稿写回这块
                                },
                                onSplitTranslation: { before, after in
                                    onSplitTranslation(block.id, before, after)  // 回车拆这块
                                },
                                onClearFocusTranslation: onClearFocusTranslation
                            )
                            .id(block.id)  // scrollTo 用这块的 id
                        }

                        if !summaryBlocks.isEmpty {  // 没有摘要就别占表尾
                            summaryHeader
                            ForEach(summaryBlocks) { block in  // 摘要单独样式，不走三列
                                TranslationTableSummaryRow(  // 摘要只有译文可改
                                    block: block,
                                    isEditable: isEditable,
                                    onUpdate: { translation in
                                        onUpdateBlock(block.id, nil, translation, nil)  // 摘要不改原文和注
                                    }
                                )
                                .id(block.id)  // scrollTo 用这块的 id
                            }
                        }
                    }
                }
                .onChange(of: scrollTargetBlockID) { blockID in  // 左页跳段时右表跟过去
                    guard let blockID else { return }  // nil 表示没有要滚的目标
                    withAnimation(.easeInOut(duration: 0.18)) {  // 短动画，避免猛跳
                        proxy.scrollTo(blockID, anchor: .top)  // 目标行钉在视口顶
                    }
                }
            }
        }
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.vertical, 4)  // 表和页边留一点气
        .id(styleManager.revision)  // 字体变整页重建，避免残列宽
    }

    /// summary 区小标题。
    private var summaryHeader: some View {
        HStack {
            Text(BookL10n.string("label.note"))  // 摘要区小标题，复用注的文案
                .font(BookTheme.captionFont.weight(.semibold))  // 说明字号
                .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
            Spacer()  // 把后续控件推开
        }
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.vertical, 8)  // 上下边距
        .background(BookTheme.pageEdge.opacity(0.12))  // 摘要头浅底，和正文行区分
    }

    /// 当前同步行浅金底。
    private func rowBackground(isHighlighted: Bool) -> some View {
        Group {  // 只为了套修饰
            if isHighlighted {  // 跟滚命中
                BookTheme.selection.opacity(0.28)  // 浅金，不挡字
            } else {
                Color.white.opacity(0.12)  // 未命中也略亮于页底，方便扫行
            }
        }
    }

    /// 行列之间的细线。
    private var tableDivider: some View {
        Divider()  // 列间细线
            .frame(width: 1)  // 竖线，不是横分隔
            .background(BookTheme.pageEdge.opacity(0.65))  // 书边色，比纯灰暖
    }

    /// 空注不占列。
    private func noteText(for block: TranslationBlock) -> String? {
        let note = block.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // 空注当没有，不占列
        return note.isEmpty ? nil : note  // nil 让 showsNotes 跳过
    }

}

/// 列表头。
struct TranslationTableColumnHeader: View {
    let alignment: TranslationAlignment  // 当前对齐，行数据源
    var isEditable: Bool = true  // 跑着时宿主会关掉编辑
    var translationColumnTitleKey: String = "translation.header.translation"  // 第二列标题（译文/讲解）

    /// 有注或可编辑才留注列。
    private var showsNotes: Bool {
        TranslationTableLayout.showsNotes(for: alignment, isEditable: isEditable)  // 表头和表体共用同一套显隐
    }

    /// 表头 + 正文行 + summary。
    var body: some View {
        GeometryReader { viewport in  // 量视口算列宽
            let layout = TranslationTableLayout.columnLayout(  // 按视口宽重算三列
                totalWidth: max(viewport.size.width - 24, 1),  // 扣掉左右 padding，至少 1 防除零
                showsNotes: showsNotes  // 有注列才分 22% 给注
            )
            HStack(alignment: .top, spacing: 0) {  // 三列贴齐，分隔靠细线
                headerCell(BookL10n.string("translation.header.source"), width: layout.source)  // 原文列头
                tableDivider
                headerCell(BookL10n.string(translationColumnTitleKey), width: layout.translation)  // 译文/讲解列头
                if showsNotes {  // 没注列就不要第三头
                    tableDivider
                    headerCell(BookL10n.string("translation.header.note"), width: layout.note)  // 注列头
                }
            }
            .padding(.horizontal, 12)  // 和表头左右对齐
            .padding(.vertical, 6)  // 上下边距
        }
        .frame(height: 24)  // 表头矮于行，少挡正文
    }

    /// 表头一格，宽度来自 columnLayout。
    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)  // 按钮文案
            .frame(width: width, alignment: .leading)  // 和列宽锁定，避免挤兑
            .font(BookTheme.captionFont.weight(.semibold))  // 说明字号
            .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
    }

    /// 行列之间的细线。
    private var tableDivider: some View {
        Divider()  // 列间细线
            .frame(width: 1)  // 竖线，不是横分隔
            .background(BookTheme.pageEdge.opacity(0.65))  // 书边色，比纯灰暖
    }
}

/// 列宽算法。窗口变了重算。
enum TranslationTableLayout {
    /// 有任何注或可编辑才显示注列。
    static func showsNotes(for alignment: TranslationAlignment, isEditable: Bool) -> Bool {
        let entryBlocks = entryBlocks(for: alignment)  // 和表体同一套过滤
        let hasNotes = entryBlocks.contains {  // 任一细行有注才算
            let note = $0.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // 空白注不算有注
            return !note.isEmpty  // 有实质注才算
        }
        return hasNotes || (isEditable && alignment.mode == .wordByWord)  // 词表编辑时空注也留列
    }

    /// 按总宽和是否有注列分宽。
    static func columnLayout(totalWidth: CGFloat, showsNotes: Bool) -> ColumnLayout {
        let source = totalWidth * (showsNotes ? 0.34 : 0.40)  // 有注列原文略收，给注腾位
        let note = showsNotes ? totalWidth * 0.22 : 0  // 没注列宽为 0，译文吃掉
        let translation = max(0, totalWidth - source - note)  // 译文吃剩余，避免三列超宽
        return ColumnLayout(source: source, translation: translation, note: note)  // 给行和表头共用
    }

    /// 去掉 summary，按 order。
    private static func entryBlocks(for alignment: TranslationAlignment) -> [TranslationBlock] {
        let words = alignment.blocks  // 先看词/短语级，有才用，否则整段
            .filter { $0.level == .word || $0.level == .phrase }  // 词表模式的细行
            .sorted { $0.order < $1.order }  // 按对齐序，不按原文出现序
        if !words.isEmpty { return words }  // 有细行就不用整段，避免两套叠
        return alignment.blocks  // 退回段级
            .filter { $0.level == .paragraph }  // 段级对照
            .sorted { $0.order < $1.order }  // 按对齐序，不按原文出现序
    }
}

/// 一行可编辑对照。
private struct TranslationTableEditableRow: View {
    let block: TranslationBlock  // 这一行对应的对齐块
    let layout: ColumnLayout  // 本帧列宽，窗口变了会重算
    let showsNotes: Bool  // 这一帧要不要注列
    let isEditable: Bool  // 整表只读时三列都变 Text
    let isSourceColumnEditable: Bool  // 严格段对齐锁原文
    let allowsSplitTranslation: Bool  // 译文格回车是否拆行
    let isHighlighted: Bool  // 跟滚命中
    let shouldFocusTranslation: Bool  // 译完要聚焦这一行译文
    let onSelect: () -> Void  // 点行空白：同步左页
    let onUpdate: (String?, String?, String?) -> Void  // 失焦提交
    let onSplitTranslation: (String, String) -> Void  // 回车拆行
    let onClearFocusTranslation: () -> Void  // 聚焦后清掉信号

    @State private var sourceDraft: String  // 原文格未提交草稿
    @State private var translationDraft: String  // 译文格未提交草稿
    @State private var noteDraft: String  // 注格未提交草稿
    @FocusState private var focusedField: Field?  // 哪一格在编，失焦才 commit

    /// 焦点落在哪一格。
    private enum Field: Hashable {
        case source(UUID)  // 原文格，带块 id 防串行
        case translation(UUID)  // 译文格
        case note(UUID)  // 注格
    }

    /// 一行：原文/译文/注草稿和焦点。
    init(
        block: TranslationBlock,
        layout: ColumnLayout,
        showsNotes: Bool,
        isEditable: Bool,
        isSourceColumnEditable: Bool = true,  // 默认原文可改；严格表会关掉
        allowsSplitTranslation: Bool = true,  // 默认译文回车拆行
        isHighlighted: Bool,
        shouldFocusTranslation: Bool,
        onSelect: @escaping () -> Void,  // 点行同步左页
        onUpdate: @escaping (String?, String?, String?) -> Void,  // 三列提交
        onSplitTranslation: @escaping (String, String) -> Void,  // 回车拆行
        onClearFocusTranslation: @escaping () -> Void  // 聚焦用过即清
    ) {
        self.block = block  // 这一行的块
        self.layout = layout  // 本帧列宽
        self.showsNotes = showsNotes  // 本帧注列
        self.isEditable = isEditable  // 摘要只读时用 Text
        self.isSourceColumnEditable = isSourceColumnEditable  // 原文列是否可改
        self.allowsSplitTranslation = allowsSplitTranslation  // 译文回车是否拆
        self.isHighlighted = isHighlighted  // 跟滚底
        self.shouldFocusTranslation = shouldFocusTranslation  // 是否抢译文焦
        self.onSelect = onSelect  // 点行回调
        self.onUpdate = onUpdate  // 摘要提交
        self.onSplitTranslation = onSplitTranslation  // 拆行回调
        self.onClearFocusTranslation = onClearFocusTranslation  // 清聚焦信号
        _sourceDraft = State(initialValue: block.sourceText)  // 打开时用块上的原文
        _translationDraft = State(initialValue: block.translationText)  // 打开时用块上的译文
        _noteDraft = State(initialValue: block.note ?? "")  // 空注当空串，方便 TextView
    }

    /// 表头 + 正文行 + summary。
    var body: some View {
        HStack(alignment: .top, spacing: 0) {  // 三列贴齐，分隔靠细线
            tableCell(  // 一格：可编或只读
                text: $sourceDraft,
                width: layout.source,  // 原文列宽
                field: .source(block.id),  // 焦点身份带块 id，避免串行
                editable: isEditable && isSourceColumnEditable,
                onCommit: commitSource
            )
            tableDivider
            tableCell(  // 一格：可编或只读
                text: $translationDraft,
                width: layout.translation,  // 译文列宽
                field: .translation(block.id),  // 译文格焦点
                editable: isEditable,
                splitOnReturn: allowsSplitTranslation,
                onCommit: commitTranslation,
                onSplit: allowsSplitTranslation ? { before, after in
                    onSplitTranslation(before, after)  // 把回车前后交给宿主拆块
                } : nil
            )
            if showsNotes {  // 没注列就不要第三头
                tableDivider
                tableCell(  // 一格：可编或只读
                    text: $noteDraft,
                    width: layout.note,  // 注列宽
                    field: .note(block.id),  // 注格焦点
                    muted: noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,  // 空注用弱墨，提示可填
                    onCommit: commitNote
                )
            }
        }
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.vertical, 10)  // 行高靠内容，再加一点触达
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽
        .background(rowBackground)  // 跟滚浅金或浅白
        .contentShape(Rectangle())  // 空白也算点中这行
        .onTapGesture {  // 没在编格时才选行，避免和焦点抢
            guard focusedField == nil else { return }  // 正在编就别触发选行
            onSelect()  // 同步左页到这块
        }
        .onChange(of: block.sourceText) { sourceDraft = $0 }  // 外部改原文（拆行）覆盖未提交草稿
        .onChange(of: block.translationText) { translationDraft = $0 }  // 外部改摘要覆盖草稿
        .onChange(of: block.note) { noteDraft = $0 ?? "" }  // 外部清注时草稿也清空
        .onChange(of: focusedField) { field in  // 失焦才三列一起提交
            guard field == nil else { return }  // 换格中间不提交，等真正失焦
            commitAllIfNeeded()  // 有改动的列才写回
        }
        .onChange(of: shouldFocusTranslation) { shouldFocus in  // 译完滚过来
            guard shouldFocus else { return }  // 信号掉了就不管
            focusedField = .translation(block.id)  // 抢译文格
            onClearFocusTranslation()  // 用过即清，避免每帧再抢
        }
    }

    @ViewBuilder
    /// 可编辑单元格。提交走 commitXxx。
    private func tableCell(
        text: Binding<String>,
        width: CGFloat,
        field: Field,
        editable: Bool = true,  // 这一列自己的只读（原文列可单独锁）
        muted: Bool = false,  // 空注弱墨
        splitOnReturn: Bool = false,  // 只有译文列打开
        onCommit: @escaping () -> Void,  // 失焦提交
        onSplit: ((String, String) -> Void)? = nil  // 注/原文不拆行
    ) -> some View {
        if isEditable && editable {  // 整表和这一列都允许才上编辑器
            TranslationTableCellEditor(  // NSTextView，保 IME 和回车拆行
                text: text,
                width: width,
                muted: muted,
                splitOnReturn: splitOnReturn,
                isFocused: focusedField == field,  // 这一格是否该持焦
                onFocusChange: { focused in
                    focusedField = focused ? field : nil  // NSTextView 焦点回写 FocusState
                },
                onCommit: onCommit,
                onSplit: onSplit
            )
            .frame(width: width, alignment: .leading)  // 和列宽锁定，避免挤兑
            .fixedSize(horizontal: false, vertical: true)  // 按排版撑高，不裁行
        } else {
            Text(text.wrappedValue)  // 只读格，仍可划词
                .frame(width: width, alignment: .leading)  // 和列宽锁定，避免挤兑
                .font(BookTheme.readingContentFont)  // 和左页同一套正文字
                .foregroundStyle(muted ? BookTheme.inkMuted : BookTheme.ink)  // 空注弱墨
                .textSelection(.enabled)  // 只读也能划词
                .lineSpacing(BookTheme.readingLineSpacing)  // 和左页行距一致
                .fixedSize(horizontal: false, vertical: true)  // 按排版撑高，不裁行
                .multilineTextAlignment(.leading)  // 长行左对齐
        }
    }

    /// 高亮行底，跟选区走。
    private var rowBackground: some View {
        Group {  // 只为了套修饰
            if isHighlighted {  // 跟滚命中
                BookTheme.selection.opacity(0.28)  // 浅金，不挡字
            } else {
                Color.white.opacity(0.12)  // 未命中也略亮于页底，方便扫行
            }
        }
    }

    /// 行列之间的细线。
    private var tableDivider: some View {
        Divider()  // 列间细线
            .frame(width: 1)  // 竖线，不是横分隔
            .background(BookTheme.pageEdge.opacity(0.65))  // 书边色，比纯灰暖
    }

    /// 原文改了要重锚定。
    private func commitSource() {
        let trimmed = sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交前去空白
        guard trimmed != block.sourceText else { return }  // 没改就别写回，避免脏标记
        onUpdate(trimmed, nil, nil)  // 只改原文列
    }

    /// 只改译文，不重锚定原文。
    private func commitTranslation() {
        let trimmed = translationDraft.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交前去空白
        guard trimmed != block.translationText else { return }  // 摘要没改就跳过
        onUpdate(nil, trimmed, nil)  // 只改译文列
    }

    /// 注可空。
    private func commitNote() {
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交前去空白
        let current = block.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // 和块上的注比，空当空串
        guard trimmed != current else { return }  // 没改注就跳过
        onUpdate(nil, nil, trimmed)  // 只改注列
    }

    /// 失焦时把没提交的格写回。
    private func commitAllIfNeeded() {
        commitSource()  // 失焦时原文有改才写
        commitTranslation()  // 失焦时译文有改才写
        commitNote()  // 失焦时注有改才写
    }
}

/// 表底总结行。
private struct TranslationTableSummaryRow: View {
    let block: TranslationBlock  // 这一行对应的对齐块
    let isEditable: Bool  // 整表只读时三列都变 Text
    let onUpdate: (String) -> Void  // 摘要只回写译文

    @State private var translationDraft: String  // 译文格未提交草稿
    @FocusState private var isFocused: Bool

    /// 对照表：按对齐块铺三列。
    init(
        block: TranslationBlock,
        isEditable: Bool,
        onUpdate: @escaping (String) -> Void  // 摘要只回写译文
    ) {
        self.block = block  // 这一行的块
        self.isEditable = isEditable  // 摘要只读时用 Text
        self.onUpdate = onUpdate  // 摘要提交
        _translationDraft = State(initialValue: block.translationText)  // 打开时用块上的译文
    }

    /// 表头 + 正文行 + summary。
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {  // 摘要标题在上，正文在下
            Text(summaryTitle(for: block))  // 难点词语 vs 普通摘要
                .font(BookTheme.captionFont.weight(.semibold))  // 说明字号
                .foregroundStyle(BookTheme.leather)  // 进行中用皮色

            if isEditable {  // 可编才上 TextField
                TextField("", text: $translationDraft, axis: .vertical)  // 摘要竖向长文
                    .textFieldStyle(.plain)  // 不要系统边框
                    .font(BookTheme.readingContentFont)  // 和左页同一套正文字
                    .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
                    .lineSpacing(BookTheme.readingLineSpacing)  // 和左页行距一致
                    .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽
                    .focused($isFocused)  // 失焦提交
                    .onSubmit(commit)  // 回车也提交，摘要不拆行
                    .onChange(of: isFocused) { focused in  // 点走才写回
                        if !focused { commit() }  // 失焦提交
                    }
            } else {
                Text(block.translationText)  // 只读摘要
                    .font(BookTheme.readingContentFont)  // 和左页同一套正文字
                    .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
                    .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽
                    .textSelection(.enabled)  // 只读也能划词
            }
        }
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.vertical, 10)  // 行高靠内容，再加一点触达
        .background(BookTheme.selection.opacity(0.12))  // 摘要区略底色，和正文行区分
        .onChange(of: block.translationText) { translationDraft = $0 }  // 外部改摘要覆盖草稿
    }

    /// 单格提交入口。
    private func commit() {
        let trimmed = translationDraft.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交前去空白
        guard trimmed != block.translationText else { return }  // 摘要没改就跳过
        onUpdate(trimmed)  // 摘要只回写译文
    }

    private static let difficultSourceMarker = "难点词语"

    /// 对照表摘要列标题。
    private func summaryTitle(for block: TranslationBlock) -> String {
        let source = block.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)  // 和标记比之前去空白
        if source == Self.difficultSourceMarker { return BookL10n.string("translation.row.difficult") }  // 旧标记换成目录文案
        return BookL10n.string("translation.row.summary")  // 普通摘要标题
    }
}

/// 算好的各列宽。
struct ColumnLayout {
    let source: CGFloat  // 原文列宽
    let translation: CGFloat  // 译文列宽
    let note: CGFloat  // 注列宽，0 表示隐藏
}

/// 单元格 NSTextView，支持 IME。
private struct TranslationTableCellEditor: NSViewRepresentable {
    @Binding var text: String  // 和行草稿双向绑
    let width: CGFloat  // 列宽，决定换行和行高
    let muted: Bool  // 空注弱墨
    let splitOnReturn: Bool  // 只有译文格才拆行
    let isFocused: Bool  // SwiftUI 侧要不要抢焦
    let onFocusChange: (Bool) -> Void  // 回写 FocusState
    let onCommit: () -> Void  // 失焦提交块
    let onSplit: ((String, String) -> Void)?  // 回车拆行；注/原文为 nil

    /// 表格单元格的编辑/拆行状态。
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)  // IME 和拆行都走协调器
    }

    /// 建对照表宿主视图。
    func makeNSView(context: Context) -> TranslationTableTextView {
        let textView = TranslationTableTextView()  // 自绘行高和回车
        textView.isRichText = false  // 禁富文本，对照表只认纯字
        textView.drawsBackground = false  // 底由 SwiftUI 行背景画
        textView.backgroundColor = .clear  // 透明，露出跟滚底
        textView.isHorizontallyResizable = false  // 宽跟列走，不横向撑
        textView.isVerticallyResizable = true  // 高跟排版走
        textView.textContainerInset = TranslationTableTextMetrics.containerInset  // 上下 1pt，避免裁切字形
        textView.textContainer?.widthTracksTextView = true  // 换行跟视图宽
        textView.textContainer?.lineFragmentPadding = 0  // 去掉系统左右 pad，和只读 Text 齐
        textView.isAutomaticQuoteSubstitutionEnabled = false  // 禁弯引号，避免和原文对不齐
        textView.isAutomaticDashSubstitutionEnabled = false  // 禁破折号替换
        textView.isAutomaticTextReplacementEnabled = false  // 禁系统替换，译本要原样
        textView.delegate = context.coordinator  // 改字/失焦走协调器
        textView.splitOnReturn = splitOnReturn  // 译文格才拆
        textView.onSplit = { [weak coordinator = context.coordinator] before, after in  // 弱引用，避免和 NSTextView 环
            coordinator?.handleSplit(before: before, after: after)  // 拆行时锁 isUpdatingFromView
        }
        textView.preferredWidth = width  // 行高按这个宽测
        textView.isMuted = muted  // 空注弱墨
        TranslationTableTextMetrics.applyTypography(to: textView, muted: muted)  // 和左页同一套字
        TranslationTableTextMetrics.setText(text, on: textView, muted: muted)  // 首帧写入，清富文本
        return textView  // 交给 SwiftUI 托管
    }

    /// 对齐或字体变了重铺单元格。
    func updateNSView(_ textView: TranslationTableTextView, context: Context) {
        context.coordinator.parent = self  // 闭包和绑定换新
        textView.splitOnReturn = splitOnReturn  // 译文格才拆
        textView.onSplit = { [weak coordinator = context.coordinator] before, after in  // 弱引用，避免和 NSTextView 环
            coordinator?.handleSplit(before: before, after: after)  // 拆行时锁 isUpdatingFromView
        }

        textView.isMuted = muted  // 空注弱墨
        TranslationTableTextMetrics.applyTypography(to: textView, muted: muted)  // 和左页同一套字
        textView.preferredWidth = width  // 行高按这个宽测

        if !context.coordinator.isUpdatingFromView,  // 正在从 View 写回时不要再 setText
           !textView.hasMarkedText(),  // IME 未确认时不要掀草稿
           textView.plainString != text {  // 绑定和视图不一致才重铺
            let selectedRange = textView.selectedRange()  // 重铺前保住光标
            TranslationTableTextMetrics.setText(text, on: textView, muted: muted)  // 首帧写入，清富文本
            let length = (text as NSString).length  // UTF-16，和 NSRange 一致
            let location = min(selectedRange.location, length)  // 文本变短时夹光标
            textView.setSelectedRange(NSRange(location: location, length: 0))  // 不恢复选区长度，避免拆行后残选
        }

        if isFocused, textView.window?.firstResponder !== textView {  // SwiftUI 要焦但系统还没给
            textView.window?.makeFirstResponder(textView)  // 抢焦，好接着打字
        }
    }

    /// 把编辑写回 alignment。
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TranslationTableCellEditor  // 每次 update 换新绑定
        var isUpdatingFromView = false  // 拆行/写回时挡住 updateNSView 重铺

        /// 单元格文本视图的协调器。
        init(parent: TranslationTableCellEditor) {
            self.parent = parent  // 首建
        }

        /// 回车拆行。
        func handleSplit(before: String, after: String) {
            isUpdatingFromView = true  // 挡住回环
            parent.onSplit?(before, after)  // 宿主拆块；注列这个是 nil
            isUpdatingFromView = false  // 解开，后续用户输入再同步
        }

        /// 写回绑定，避开 IME。
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? TranslationTableTextView else { return }  // 只认自己的视图
            guard !textView.isPerformingSplit else { return }  // 拆行自己会写绑定，这里别插一脚
            isUpdatingFromView = true  // 挡住回环
            parent.text = textView.plainString  // 草稿写回 Binding
            isUpdatingFromView = false  // 解开，后续用户输入再同步
            textView.invalidateIntrinsicContentSize()  // 字变了重测行高
        }

        /// 编辑结束写回块。
        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)  // 清 FocusState
            parent.onCommit()  // 三列里该提交的提交
        }

        /// 开始编辑时记下原文，取消能回退。
        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)  // 记下正在编，点行手势要让路
        }
    }
}

/// 测文字高度，决定行高。
private enum TranslationTableTextMetrics {
    static let containerInset = NSSize(width: 0, height: 1)

    /// 字体行高跟本书设置。
    static func applyTypography(to textView: NSTextView, muted: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()  // 行距跟 BookTheme
        paragraphStyle.lineSpacing = BookTheme.readingLineSpacing  // 和左页一致

        textView.font = BookTheme.readingFont  // 对照表用阅读字体，不是 UI 字
        textView.textColor = muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink)  // 空注弱墨
        textView.insertionPointColor = NSColor(BookTheme.leather)  // 光标皮色，好找
        textView.defaultParagraphStyle = paragraphStyle  // 回车后仍用这套行距

        var typing = textView.typingAttributes  // 新打的字也跟主题
        typing[.font] = BookTheme.readingFont  // 续打字体
        typing[.foregroundColor] = muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink)  // 续打颜色
        typing[.paragraphStyle] = paragraphStyle  // 续打行距
        textView.typingAttributes = typing  // 写回
    }

    /// 设单元格文本并清选区。
    static func setText(_ text: String, on textView: NSTextView, muted: Bool) {
        let paragraphStyle = NSMutableParagraphStyle()  // 行距跟 BookTheme
        paragraphStyle.lineSpacing = BookTheme.readingLineSpacing  // 和左页一致
        let attributes: [NSAttributedString.Key: Any] = [  // 整段重铺，清掉粘贴来的富文本
            .font: BookTheme.readingFont,  // 阅读字体
            .foregroundColor: muted ? NSColor(BookTheme.inkMuted) : NSColor(BookTheme.ink),  // 空注弱墨
            .paragraphStyle: paragraphStyle,  // 阅读行距
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))  // 覆盖整段
    }
}

/// 单元格编辑器用，禁富文本粘贴。
private final class TranslationTableTextView: NSTextView {
    var preferredWidth: CGFloat = 0  // 列宽，0 表示还没量到
    var splitOnReturn = false  // 默认不拆，只有译文格打开
    var isMuted = false  // 空注弱墨
    var isPerformingSplit = false  // 拆行期间挡住 textDidChange
    var onSplit: ((String, String) -> Void)?  // 回车拆行出口

    /// 单元格纯文本，去掉附件。
    var plainString: String {
        string  // NSTextView 的纯字
    }

    /// 单元格要能聚焦才能编辑。
    override var acceptsFirstResponder: Bool { true }

    /// 按排版高度撑开行，避免裁切。
    override var intrinsicContentSize: NSSize {
        guard let textContainer, let layoutManager else {  // 还没挂上 TextKit 就先 0 高
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)  // 宽交给约束，高先 0
        }
        let width = max(preferredWidth, 1)  // 没量到当 1，避免 0 宽测高
        textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)  // 按列宽换行，高度不限
        layoutManager.ensureLayout(for: textContainer)  // 先排完再量
        let used = layoutManager.usedRect(for: textContainer)  // 实际墨水高度
        let verticalInset = textContainerInset.height * 2  // 上下 inset 都算进行高
        return NSSize(width: NSView.noIntrinsicMetric, height: max(used.height + verticalInset, 18))  // 最短 18，空格也能点中
    }

    /// 按列宽重排单元格。
    override func layout() {
        super.layout()  // 先让系统排
        if preferredWidth > 0 {  // 有列宽才锁 container
            textContainer?.containerSize = NSSize(  // 列宽变了重排换行
                width: preferredWidth,  // 当前列宽
                height: .greatestFiniteMagnitude  // 高度不限，行高自己报
            )
        }
        invalidateIntrinsicContentSize()  // 通知 SwiftUI 行高可能变了
    }

    /// 进编辑时通知协调器。
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()  // 先问系统
        if became {  // 成功才钉死，防止被 ScrollView 抢走
            window?.makeFirstResponder(self)  // 钉在这一格
        }
        return became  // 失败原样回
    }

    /// 拦截回车拆行，别插换行。
    override func doCommand(by commandSelector: Selector) {
        if commandSelector == #selector(NSResponder.insertNewline(_:)), splitOnReturn {  // 只有译文格拦截回车
            if hasMarkedText() {  // IME 未确认，回车先交给系统上屏
                super.doCommand(by: commandSelector)  // 其它按键原样
                return  // IME 路径到此
            }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {  // Shift+回车仍插换行，不拆行
                super.doCommand(by: commandSelector)  // 其它按键原样
                return  // IME 路径到此
            }

            let range = selectedRange()  // 从光标切开，选区会进 after
            let nsString = string as NSString  // 按 UTF-16 切，和 NSRange 一致
            let before = nsString.substring(to: range.location)  // 留在本块
            let after = nsString.substring(from: range.location)  // 新建下一块，含选中部分
            isPerformingSplit = true  // 挡住 textDidChange 把整段写回旧块
            TranslationTableTextMetrics.setText(before, on: self, muted: isMuted)  // 本格先变成前半
            onSplit?(before, after)  // 宿主插新块
            isPerformingSplit = false  // 解开
            invalidateIntrinsicContentSize()  // 通知 SwiftUI 行高可能变了
            return  // IME 路径到此
        }
        super.doCommand(by: commandSelector)  // 其它按键原样
    }
}

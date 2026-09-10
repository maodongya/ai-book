import AppKit
import SwiftUI

struct ExplanationChatView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var editingMessageIDs: Set<UUID> = []
    @AppStorage("aiBook.readingComposerVisible") private var isReadingComposerVisible = true
    @AppStorage("aiBook.readingChromeVisible") private var isReadingChromeVisible = true

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.rightPageTab {
            case .readingAssistant:
                readingAssistantPage
            case .aiEvolution:
                aiEvolutionPage
            }
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            settings.reloadCursorAPIKey()
        }
    }

    private var readingAssistantPage: some View {
        VStack(spacing: 0) {
            if isReadingChromeVisible {
                configurationNotice
                readingAssistantPanelSwitcher
            }

            readingAssistantContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if !isReadingChromeVisible {
                        readingChromeRestoreControl
                            .padding(10)
                    }
                }

            readingComposerSection
        }
    }

    @ViewBuilder
    private var readingAssistantContent: some View {
        switch viewModel.readingAssistantPanel {
        case .explanation:
            explanationPanel
        case .translation:
            translationPanel
        }
    }

    @ViewBuilder
    private var readingComposerSection: some View {
        if !isReadingChromeVisible {
            EmptyView()
        } else if isReadingComposerVisible {
            composer(for: .readingAssistant)
        } else {
            collapsedReadingComposerBar
        }
    }

    private var collapsedReadingComposerBar: some View {
        HStack(spacing: 8) {
            if viewModel.isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(collapsedRunningStatusText)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                        .lineLimit(1)
                }

                BookPageActionButton(
                    title: "停止",
                    icon: "stop.fill",
                    isDisabled: false
                ) {
                    viewModel.stopCurrentRun()
                }
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    isReadingComposerVisible = true
                }
            } label: {
                Label("显示输入", systemImage: "chevron.up")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            }
            .buttonStyle(.plain)
            .help("显示 AI 输入框")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.55), lineWidth: 1)
                }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var collapsedRunningStatusText: String {
        let text = viewModel.runningStatusText(for: .readingAssistant)
        return text.isEmpty ? "大模型生成中…" : text
    }

    private var readingAssistantPanelSwitcher: some View {
        HStack(spacing: 8) {
            Picker("右页分栏", selection: $viewModel.readingAssistantPanel) {
                ForEach(ReadingAssistantPanel.allCases) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)

            Button(action: enterReadingFocusMode) {
                Label("专注阅读", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            }
            .buttonStyle(.plain)
            .help("隐藏工具栏与分栏切换，只保留结果正文")
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var readingChromeRestoreControl: some View {
        Button(action: exitReadingFocusMode) {
            Label("显示工具栏", systemImage: "chevron.down")
                .font(styleManager.tokens.typography.captionFont)
                .foregroundStyle(styleManager.tokens.colors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
        }
        .buttonStyle(.plain)
        .help("显示读书助手标题、分栏切换与翻译状态栏")
    }

    private func enterReadingFocusMode() {
        withAnimation(.easeOut(duration: 0.18)) {
            isReadingChromeVisible = false
            isReadingComposerVisible = false
        }
    }

    private func exitReadingFocusMode() {
        withAnimation(.easeOut(duration: 0.18)) {
            isReadingChromeVisible = true
            isReadingComposerVisible = true
        }
    }

    private var explanationPanel: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.chatMessages.count <= 1 && !viewModel.isLoading {
                explanationPlaceholder
            }

            chatList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SelectableTextView(
                text: $viewModel.explanationSelectionText,
                onSelectionChange: { selection, _ in
                    viewModel.updateExplanationPanelSelection(selection)
                },
                appearance: .editor,
                isEditable: false,
                selectAllSignal: viewModel.explanationSelectAllSignal
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            if isReadingChromeVisible {
                VStack {
                    HStack(spacing: 8) {
                        Spacer()
                        explanationToolbar
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }

    private var explanationToolbar: some View {
        HStack(spacing: 8) {
            explanationToolbarButton(title: "新建") {
                viewModel.newExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: "保存") {
                viewModel.saveExplanationDocument()
            }
            .disabled(!viewModel.hasExplanationContent)

            explanationToolbarButton(title: "打开") {
                viewModel.openExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: "全选") {
                viewModel.selectAllExplanation()
            }
            .disabled(!viewModel.hasExplanationContent || viewModel.isRunning)

            explanationToolbarButton(title: "清空") {
                viewModel.clearExplanation()
            }
            .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                explanationToolbarButton(
                    title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停"
                ) {
                    viewModel.toggleExplanationSpeechPause()
                }
            }

            explanationToolbarButton(
                title: viewModel.isSpeakingExplanation ? "停止" : "朗读"
            ) {
                viewModel.readExplanationAloud()
            }
            .disabled(viewModel.isRunning || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation))
        }
        .id(styleManager.revision)
    }

    private func explanationToolbarButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(styleManager.tokens.typography.captionFont)
                .foregroundStyle(styleManager.tokens.colors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
        }
        .buttonStyle(.plain)
    }

    private var translationPanel: some View {
        VStack(spacing: 0) {
            if isReadingChromeVisible {
                translationSyncControls
            }
            ZStack(alignment: .topTrailing) {
                Group {
                    if viewModel.showsTranslationTableView, let alignment = viewModel.translationAlignment {
                        TranslationTableView(
                            alignment: alignment,
                            isEditable: !viewModel.isRunning,
                            highlightedBlockID: viewModel.translationTableHighlightedBlockID,
                            scrollTargetBlockID: viewModel.translationTableScrollTargetID,
                            focusTranslationBlockID: viewModel.translationTableFocusTranslationBlockID,
                            onSelectBlock: { block in
                                viewModel.handleTranslationTableVisibleBlock(block)
                            },
                            onUpdateBlock: { id, source, translation, note in
                                viewModel.updateTranslationTableBlock(
                                    id: id,
                                    sourceText: source,
                                    translationText: translation,
                                    note: note
                                )
                            },
                            onSplitTranslation: { id, before, after in
                                viewModel.splitTranslationTableBlock(
                                    id: id,
                                    translationBefore: before,
                                    translationAfter: after
                                )
                            },
                            onClearFocusTranslation: {
                                viewModel.translationTableFocusTranslationBlockID = nil
                            }
                        )
                    } else {
                        lessonPlanEditor
                    }
                }

                if isReadingChromeVisible, !viewModel.showsTranslationTableView {
                    VStack {
                        HStack(spacing: 8) {
                            Spacer()
                            lessonPlanSelectAllButton
                            lessonPlanReadAloudButton
                        }
                        Spacer()
                    }
                    .padding(10)
                }

                if viewModel.isLoading && viewModel.readingAssistantActiveTask == .translation {
                    translationLoadingBadge
                }
            }
        }
    }

    private var translationLoadingBadge: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("正在生成翻译…")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.88))
                .overlay {
                    Capsule()
                        .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var translationSyncControls: some View {
        if viewModel.translationAlignment?.isStale == true {
            translationStaleBanner
                .padding(.horizontal, 14)
                .padding(.top, 4)
        }

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("表格对照", isOn: $viewModel.translationTableViewEnabled)
                    .toggleStyle(.switch)
                    .font(BookTheme.captionFont)
                    .disabled(!viewModel.canUseTranslationTableView)
                Text("按左页段落建立原文与译文映射。可直接在表格中编辑；对照偏移可整体上下微调；锁定后保存且禁止整体调整。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.canUseTranslationTableView {
                    translationSyncOffsetControls
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                Button("对齐原文") {
                    viewModel.alignTranslationWithSource()
                }
                .buttonStyle(.bordered)
                .font(BookTheme.captionFont)
                .disabled(!viewModel.canAlignTranslationWithSource)

                if viewModel.isTranslationAlignmentLocked {
                    Button("解锁对照") {
                        viewModel.unlockTranslationAlignment()
                    }
                    .buttonStyle(.bordered)
                    .font(BookTheme.captionFont)
                } else if viewModel.canUseTranslationTableView {
                    Button("锁定对照") {
                        viewModel.lockTranslationAlignment()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(BookTheme.captionFont)
                }

                if let status = viewModel.translationAlignmentStatusText {
                    Text(status)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(
                            viewModel.translationAlignment?.isStale == true
                                ? Color.orange
                                : BookTheme.inkMuted
                        )
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var translationSyncOffsetControls: some View {
        HStack(spacing: 8) {
            Text("对照偏移")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)

            Button("左表↓") {
                viewModel.shiftTranslationSyncOffset(rightTableSteps: -1)
            }
            .buttonStyle(.bordered)
            .font(BookTheme.captionFont)
            .disabled(!viewModel.canAdjustTranslationSyncOffset)

            Button("右表↓") {
                viewModel.shiftTranslationSyncOffset(rightTableSteps: 1)
            }
            .buttonStyle(.bordered)
            .font(BookTheme.captionFont)
            .disabled(!viewModel.canAdjustTranslationSyncOffset)

            Text(offsetLabel)
                .font(BookTheme.captionFont.monospacedDigit())
                .foregroundStyle(BookTheme.leather)
                .frame(minWidth: 28)

            Button("复位") {
                viewModel.resetTranslationSyncOffset()
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.leather)
            .disabled(!viewModel.canAdjustTranslationSyncOffset || viewModel.translationSyncBlockOffset == 0)
        }
        .help("左表↓：右表整体上移一行对照；右表↓：右表整体下移一行对照。锁定后不可调整。")
    }

    private var offsetLabel: String {
        let offset = viewModel.translationSyncBlockOffset
        if offset == 0 { return "0" }
        return offset > 0 ? "+\(offset)" : "\(offset)"
    }

    private var translationStaleBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("对齐已失效。可点击右侧「对齐原文」恢复表格对照，无需重新翻译；仅当译文内容本身也要改时才重新生成。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        }
    }

    private var explanationPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("选中左页文字后点击「选择讲解」", systemImage: "sparkles.text.clipboard")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink.opacity(0.72))
            Text("也可在顶栏「讲解操作」中使用「全文讲解」；支持新建、保存、打开、全选、清空与朗读。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineSpacing(4)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .allowsHitTesting(false)
    }

    private var aiEvolutionPage: some View {
        VStack(spacing: 0) {
            configurationNotice

            EvolutionUtilityTabsPanel(
                items: viewModel.evolutionItems,
                projectPath: SelfEvolution.sourceProjectPath(),
                isRunning: viewModel.isRunning,
                isAnalyzing: viewModel.isAnalyzing,
                executingCommandNumber: viewModel.executingEvolutionCommandNumber,
                budget: viewModel.evolutionTokenBudget,
                liveToolLabel: viewModel.evolutionLiveToolLabel,
                lastRequestId: viewModel.evolutionLastRequestId,
                hasPending: viewModel.hasPendingOptimization,
                onAddUserItem: { viewModel.addUserOptimization(title: $0) },
                onSkip: { viewModel.skipOptimization(id: $0) },
                onDelete: { viewModel.deleteOptimization(id: $0) },
                onPin: { viewModel.pinOptimization(id: $0) },
                onRestore: { viewModel.restoreOptimization(id: $0) }
            )

            if viewModel.isEvolutionRebuilding {
                EvolutionRebuildBanner(status: viewModel.evolutionRebuildStatus)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }

            chatList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            composer(for: .aiEvolution)
        }
    }

    @ViewBuilder
    private var configurationNotice: some View {
        if viewModel.rightPageTab == .aiEvolution {
            if !settings.isCursorRunnable {
                CursorConfigPanel()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        } else if !settings.isBookLLMConfigured {
            bookConfigBanner
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
    }

    private var bookConfigBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(BookTheme.gold)
            Text("读书功能需配置 book 大模型（推荐本机 Ollama）。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
            Spacer(minLength: 8)
            Button("book设置") {
                viewModel.openBookSettings()
            }
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.leather)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BookTheme.selection.opacity(0.3))
        }
    }

    @ViewBuilder
    private func composer(for mode: RightPageTab) -> some View {
        if mode == .aiEvolution {
            CursorComposerView(mode: mode)
        } else {
            LLMComposerView(
                mode: mode,
                onCollapse: {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isReadingComposerVisible = false
                    }
                }
            )
        }
    }

    private var lessonPlanEditor: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lessonPlanPlaceholder
            }

            SelectableTextView(
                text: $viewModel.lessonPlanContent,
                onSelectionChange: { selection, _ in
                    viewModel.updateLessonPlanSelection(selection)
                },
                onVisibleRangeChange: { range, _ in
                    viewModel.handleTranslationTextScroll(visibleRange: range)
                },
                scrollProxy: viewModel.translationTextScrollProxy,
                isEditable: !viewModel.isRunning,
                selectAllSignal: viewModel.rightSelectAllSignal
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var lessonPlanSelectAllButton: some View {
        let isEmpty = viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            viewModel.selectAllRightPage()
        } label: {
            Label("全选", systemImage: "selection.pin.in.out")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .overlay {
                            Capsule()
                                .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(isEmpty || viewModel.isRunning)
        .help("全选翻译内容")
    }

    private var lessonPlanReadAloudButton: some View {
        let isEmpty = viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 8) {
            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                Button {
                    viewModel.toggleExplanationSpeechPause()
                } label: {
                    Label(
                        viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                        systemImage: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill"
                    )
                    .font(styleManager.tokens.typography.captionFont)
                    .foregroundStyle(styleManager.tokens.colors.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background { lessonPlanToolbarCapsule }
                }
                .buttonStyle(.plain)
                .help(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")
            }

            Button {
                viewModel.readLessonPlanAloud()
            } label: {
                Label(
                    viewModel.isSpeakingExplanation ? "停止" : "朗读",
                    systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
                )
                .font(styleManager.tokens.typography.captionFont)
                .foregroundStyle(styleManager.tokens.colors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRunning || (isEmpty && !viewModel.isSpeakingExplanation))
            .help(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译内容（\(BookKeyboardShortcuts.readTranslationFullHint)）")
        }
        .id(styleManager.revision)
    }

    private var lessonPlanToolbarCapsule: some View {
        let colors = styleManager.tokens.colors
        return Capsule()
            .fill(colors.menuItemFill)
            .overlay {
                Capsule()
                    .strokeBorder(colors.menuItemBorder, lineWidth: 1)
            }
    }

    private var lessonPlanPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("点击「逐字翻译」开始", systemImage: "sparkles")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink.opacity(0.72))
            Text("在顶栏「翻译操作」选择逐字/整段翻译；生成后可编辑，并点击右上角朗读或 \(BookKeyboardShortcuts.readTranslationFullHint)。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineSpacing(4)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .allowsHitTesting(false)
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.chatMessages) { message in
                        chatBubble(for: message)
                            .id(message.id)
                    }

                    if showsActiveStreamingBubble {
                        streamingBubble
                            .id("loading")
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
            }
            .onChange(of: viewModel.chatMessages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.showsExecutionTrace) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingThinking) { _ in
                guard viewModel.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingResponse) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingToolSteps.count) { _ in
                guard viewModel.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func chatBubble(for message: ChatMessage) -> some View {
        Group {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 10) {
                    assistantMessageHeader(message)
                    if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
                        AssistantExecutionTraceCard(
                            thinking: message.thinking,
                            toolSteps: message.toolSteps,
                            defaultExpanded: viewModel.rightPageTab == .aiEvolution
                        )
                    }
                    if !message.content.isEmpty {
                        assistantContent(message)
                    }
                }
                .contextMenu {
                    assistantMessageMenu(for: message)
                }
                .help("右键可编辑、保存、朗读、复制或删除此条 AI 输出")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("你", systemImage: "person.fill")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    bubbleContent(message.content, isUser: true)
                }
                .contextMenu {
                    userMessageMenu(for: message)
                }
                .help("右键可复制或删除此条消息")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func assistantMessageHeader(_ message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            Label(assistantLabel, systemImage: "sparkles")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

            Spacer(minLength: 12)
        }
    }

    @ViewBuilder
    private func assistantMessageMenu(for message: ChatMessage) -> some View {
        Button {
            toggleEditing(message.id)
        } label: {
            Label(isEditing(message.id) ? "完成编辑" : "编辑此条", systemImage: isEditing(message.id) ? "checkmark" : "pencil")
        }

        Button {
            viewModel.saveAssistantMessage(id: message.id)
        } label: {
            Label("保存 AI 输出", systemImage: "square.and.arrow.down")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button {
            viewModel.readAssistantMessage(id: message.id)
        } label: {
            Label(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读此条", systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

        Divider()

        Button {
            copyToPasteboard(message.content)
        } label: {
            Label("复制内容", systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
            Button {
                copyToPasteboard(message.executionTraceText)
            } label: {
                Label("复制执行过程", systemImage: "timeline.selection")
            }
        }

        Button(role: .destructive) {
            editingMessageIDs.remove(message.id)
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label("删除此条 AI 输出", systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    @ViewBuilder
    private func userMessageMenu(for message: ChatMessage) -> some View {
        Button {
            copyToPasteboard(message.content)
        } label: {
            Label("复制内容", systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        Divider()

        Button(role: .destructive) {
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label("删除此条消息", systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    private func assistantContent(_ message: ChatMessage) -> some View {
        Group {
            if isEditing(message.id) {
                editableAssistantContent(message)
            } else {
                bubbleContent(message.content, isUser: false)
            }
        }
    }

    private func editableAssistantContent(_ message: ChatMessage) -> some View {
        TextEditor(text: Binding(
            get: { messageContent(for: message.id) },
            set: { viewModel.updateAssistantMessage(id: message.id, content: $0) }
        ))
        .font(BookTheme.readingContentFont)
        .foregroundStyle(BookTheme.ink)
        .lineSpacing(BookTheme.readingLineSpacing)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    }

    private func bubbleContent(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .font(BookTheme.readingContentFont)
            .foregroundStyle(isUser ? BookTheme.inkSecondary : BookTheme.ink)
            .lineSpacing(BookTheme.readingLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(assistantLabel, systemImage: "sparkles")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

            if viewModel.showsExecutionTrace {
                cursorStreamingContent
            } else {
                llmStreamingContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cursorStreamingContent: some View {
        if !viewModel.streamingThinking.isEmpty || !viewModel.streamingToolSteps.isEmpty {
            AssistantExecutionTraceCard(
                thinking: viewModel.streamingThinking.isEmpty ? nil : viewModel.streamingThinking,
                toolSteps: viewModel.streamingToolSteps.isEmpty ? nil : viewModel.streamingToolSteps,
                isLive: true,
                defaultExpanded: true
            )
        } else if !viewModel.streamingToolStatus.isEmpty {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(viewModel.streamingToolStatus)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
        if !viewModel.streamingResponse.isEmpty {
            bubbleContent(viewModel.streamingResponse, isUser: false)
        } else if viewModel.streamingThinking.isEmpty
                    && viewModel.streamingToolSteps.isEmpty
                    && viewModel.streamingToolStatus.isEmpty {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(viewModel.rightPageTab == .aiEvolution ? "AI 进化执行中…" : "Cursor 正在执行…")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var llmStreamingContent: some View {
        if !viewModel.streamingResponse.isEmpty {
            bubbleContent(viewModel.streamingResponse, isUser: false)
        } else {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("大模型生成中…")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
    }

    private var assistantLabel: String {
        if viewModel.rightPageTab == .aiEvolution {
            return "AI进化"
        }
        return "读书助手"
    }

    private func isEditing(_ id: UUID) -> Bool {
        editingMessageIDs.contains(id)
    }

    private func toggleEditing(_ id: UUID) {
        if editingMessageIDs.contains(id) {
            editingMessageIDs.remove(id)
        } else {
            editingMessageIDs.insert(id)
        }
    }

    private func messageContent(for id: UUID) -> String {
        viewModel.chatMessages.first(where: { $0.id == id })?.content ?? ""
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var showsActiveStreamingBubble: Bool {
        if viewModel.rightPageTab == .aiEvolution {
            return viewModel.isLoading
        }
        return viewModel.isLoading && viewModel.readingAssistantActiveTask == .explanation
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if showsActiveStreamingBubble {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("loading", anchor: .bottom)
            }
            return
        }

        if let last = viewModel.chatMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

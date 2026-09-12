import AppKit
import SwiftUI

struct ExplanationChatView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
    var learningPaneFocus: LearningPaneFocus = .both
    var onLearningPaneFocusChange: ((LearningPaneFocus) -> Void)?
    @AppStorage("aiBook.readingComposerVisible") private var isReadingComposerVisible = true
    @AppStorage("aiBook.readingChromeVisible") private var isReadingChromeVisible = true

    var body: some View {
        let _ = settings.localizationRevision
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
                    title: BookL10n.string("action.stop"),
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
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BookTheme.leather)
            }
            .buttonStyle(.plain)
            .help(BookL10n.string("help.showInput"))
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
        return text.isEmpty ? BookL10n.string("llm.generating") : text
    }

    private var readingAssistantPanelSwitcher: some View {
        HStack(spacing: 8) {
            Picker(BookL10n.string("picker.rightPanel"), selection: $viewModel.readingAssistantPanel) {
                ForEach(ReadingAssistantPanel.allCases) { panel in
                    Text(panel.toolbarTitle).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let onLearningPaneFocusChange {
                readingAssistantRightFullscreenButton(onChange: onLearningPaneFocusChange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var readingChromeRestoreControl: some View {
        Button(action: exitReadingFocusMode) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(styleManager.tokens.colors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
        }
        .buttonStyle(.plain)
        .help(BookL10n.string("help.showToolbar"))
    }

    private func readingAssistantRightFullscreenButton(
        onChange: @escaping (LearningPaneFocus) -> Void
    ) -> some View {
        let isFocused = learningPaneFocus == .trailing

        return Button {
            onChange(isFocused ? .both : .trailing)
        } label: {
            Image(systemName: isFocused ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BookTheme.leather.opacity(0.72))
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(BookTheme.pageEdge.opacity(0.35))
                }
        }
        .buttonStyle(.plain)
        .help(
            isFocused
                ? BookL10n.string("help.restoreSpreadFromFocus")
                : BookL10n.string("help.rightFullscreen")
        )
    }

    private func exitReadingFocusMode() {
        withAnimation(.easeOut(duration: 0.18)) {
            isReadingChromeVisible = true
            isReadingComposerVisible = true
        }
    }

    private var explanationPanel: some View {
        ZStack(alignment: .topLeading) {
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
            explanationToolbarButton(title: BookL10n.string("action.new")) {
                viewModel.newExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.save")) {
                viewModel.saveExplanationDocument()
            }
            .disabled(!viewModel.hasExplanationContent)

            explanationToolbarButton(title: BookL10n.string("action.open")) {
                viewModel.openExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.selectAll")) {
                viewModel.selectAllExplanation()
            }
            .disabled(!viewModel.hasExplanationContent || viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.clear")) {
                viewModel.clearExplanation()
            }
            .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                explanationToolbarButton(
                    title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")
                ) {
                    viewModel.toggleExplanationSpeechPause()
                }
            }

            explanationToolbarButton(
                title: viewModel.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")
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
                translationToolbar
            }
            if viewModel.showsTranslationTableView, let alignment = viewModel.translationAlignment {
                TranslationTableColumnHeader(
                    alignment: alignment,
                    isEditable: !viewModel.isRunning
                )
                .padding(.horizontal, 12)
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

                if viewModel.isLoading && viewModel.readingAssistantActiveTask == .translation {
                    translationLoadingBadge
                }
            }
        }
    }

    private var translationLoadingBadge: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(BookL10n.string("translation.generating"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }

    private var translationToolbar: some View {
        HStack(spacing: 10) {
            if viewModel.translationAlignment?.isStale == true {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
                    .help(BookL10n.string("help.alignStale"))
            }

            Toggle(BookL10n.string("translation.tableCompare"), isOn: $viewModel.translationTableViewEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(BookTheme.captionFont)
                .disabled(!viewModel.canUseTranslationTableView)

            translationToolbarButton(title: BookL10n.string("translation.alignSource")) {
                viewModel.alignTranslationWithSource()
            }
            .disabled(!viewModel.canAlignTranslationWithSource)

            if viewModel.isTranslationAlignmentLocked {
                translationToolbarButton(title: BookL10n.string("translation.unlock")) {
                    viewModel.unlockTranslationAlignment()
                }
            } else if viewModel.canUseTranslationTableView {
                translationToolbarButton(title: BookL10n.string("translation.lock"), prominent: true) {
                    viewModel.lockTranslationAlignment()
                }
            }

            Spacer(minLength: 8)

            if !viewModel.showsTranslationTableView {
                translationToolbarButton(title: BookL10n.string("action.selectAll")) {
                    viewModel.selectAllRightPage()
                }
                .disabled(
                    viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )

                if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                    translationToolbarButton(
                        title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")
                    ) {
                        viewModel.toggleExplanationSpeechPause()
                    }
                }

                translationToolbarButton(
                    title: viewModel.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")
                ) {
                    if viewModel.isSpeakingExplanation {
                        viewModel.stopExplanationSpeech()
                    } else {
                        viewModel.readLessonPlanAloud()
                    }
                }
                .disabled(
                    viewModel.isRunning
                        || (
                            viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && !viewModel.isSpeakingExplanation
                        )
                )
            }
        }
        .font(BookTheme.captionFont)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func translationToolbarButton(
        title: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(prominent ? BookTheme.leather : BookTheme.ink)
        }
        .buttonStyle(.plain)
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
            Text(BookL10n.string("banner.bookLLM"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
            Spacer(minLength: 8)
            Button(BookL10n.string("settings.book")) {
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
        Text(BookL10n.string("translation.emptyHint"))
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.inkMuted)
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
    }

    private var displayedChatMessages: [ChatMessage] {
        if viewModel.rightPageTab == .readingAssistant {
            return viewModel.explanationDisplayMessages
        }
        return viewModel.chatMessages
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(displayedChatMessages) { message in
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
            .onChange(of: displayedChatMessages.count) { _ in
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
                .help(BookL10n.string("help.aiMessageContext"))
            } else {
                bubbleContent(message.content, isUser: true)
                .contextMenu {
                    userMessageMenu(for: message)
                }
                .help(BookL10n.string("help.chatMessageContext"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func assistantMessageMenu(for message: ChatMessage) -> some View {
        Button {
            viewModel.saveAssistantMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.saveAIOutput"), systemImage: "square.and.arrow.down")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button {
            viewModel.readAssistantMessage(id: message.id)
        } label: {
            Label(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.speechThisMessage"), systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

        Divider()

        Button {
            copyToPasteboard(message.content)
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
            Button {
                copyToPasteboard(message.executionTraceText)
            } label: {
                Label(BookL10n.string("action.copyTrace"), systemImage: "timeline.selection")
            }
        }

        Button(role: .destructive) {
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.deleteAIMessage"), systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    @ViewBuilder
    private func userMessageMenu(for message: ChatMessage) -> some View {
        Button {
            copyToPasteboard(message.content)
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        Divider()

        Button(role: .destructive) {
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.deleteMessage"), systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    private func assistantContent(_ message: ChatMessage) -> some View {
        Group {
            if viewModel.canEditExplanationMessage(message) && !viewModel.isRunning {
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
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .disabled(viewModel.isRunning)
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
                Text(viewModel.rightPageTab == .aiEvolution ? BookL10n.string("vm.evolutionRunning") : BookL10n.string("evolution.cursorExecuting"))
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
                Text(BookL10n.string("llm.generating"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
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

        if let last = displayedChatMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

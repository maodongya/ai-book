import AppKit
import SwiftUI

/// 右页：读书助手与 AI 进化（讲解 / 翻译 / 对话区壳层）。
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
        switch viewModel.assistant.readingAssistantPanel {
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
            Picker(BookL10n.string("picker.rightPanel"), selection: Binding(
                get: { viewModel.readingAssistantPanel },
                set: { viewModel.readingAssistantPanel = $0 }
            )) {
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
            ExplanationChatTranscriptView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SelectableTextView(
                text: Binding(
                    get: { viewModel.explanationSelectionText },
                    set: { viewModel.explanationSelectionText = $0 }
                ),
                onSelectionChange: { selection, _ in
                    viewModel.assistant.updateExplanationPanelSelection(selection)
                },
                appearance: .editor,
                isEditable: false,
                selectAllSignal: viewModel.assistant.explanationSelectAllSignal
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
                viewModel.assistant.newExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.save")) {
                viewModel.assistant.saveExplanationDocument()
            }
            .disabled(!viewModel.assistant.hasExplanationContent)

            explanationToolbarButton(title: BookL10n.string("action.open")) {
                viewModel.assistant.openExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.selectAll")) {
                viewModel.assistant.selectAllExplanation()
            }
            .disabled(!viewModel.assistant.hasExplanationContent || viewModel.isRunning)

            explanationToolbarButton(title: BookL10n.string("action.clear")) {
                viewModel.assistant.clearExplanation()
            }
            .disabled(viewModel.isRunning || !viewModel.assistant.hasExplanationContent)

            if viewModel.assistant.isSpeakingExplanation && !viewModel.isRunning {
                explanationToolbarButton(
                    title: viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")
                ) {
                    viewModel.assistant.toggleExplanationSpeechPause()
                }
            }

            explanationToolbarButton(
                title: viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")
            ) {
                viewModel.assistant.readExplanationAloud()
            }
            .disabled(viewModel.isRunning || (!viewModel.assistant.hasExplanationContent && !viewModel.assistant.isSpeakingExplanation))
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
            if viewModel.translation.showsTranslationTableView, let alignment = viewModel.translation.translationAlignment {
                TranslationTableColumnHeader(
                    alignment: alignment,
                    isEditable: !viewModel.isRunning
                )
                .padding(.horizontal, 12)
            }
            ZStack(alignment: .topTrailing) {
                Group {
                    if viewModel.translation.showsTranslationTableView, let alignment = viewModel.translation.translationAlignment {
                        TranslationTableView(
                            alignment: alignment,
                            isEditable: !viewModel.isRunning,
                            highlightedBlockID: viewModel.translation.translationTableHighlightedBlockID,
                            scrollTargetBlockID: viewModel.translation.translationTableScrollTargetID,
                            focusTranslationBlockID: viewModel.translation.translationTableFocusTranslationBlockID,
                            onSelectBlock: { block in
                                viewModel.translation.handleTranslationTableVisibleBlock(block)
                            },
                            onUpdateBlock: { id, source, translation, note in
                                viewModel.translation.updateTranslationTableBlock(
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
                                viewModel.translation.translationTableFocusTranslationBlockID = nil
                            }
                        )
                    } else {
                        lessonPlanEditor
                    }
                }

                if viewModel.isLoading && viewModel.assistant.readingAssistantActiveTask == .translation {
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
            if viewModel.translation.translationAlignment?.isStale == true {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
                    .help(BookL10n.string("help.alignStale"))
            }

            Toggle(BookL10n.string("translation.tableCompare"), isOn: Binding(
                get: { viewModel.translationTableViewEnabled },
                set: { viewModel.translationTableViewEnabled = $0 }
            ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(BookTheme.captionFont)
                .disabled(!viewModel.translation.canUseTranslationTableView)

            translationToolbarButton(title: BookL10n.string("translation.alignSource")) {
                viewModel.translation.alignTranslationWithSource()
            }
            .disabled(!viewModel.translation.canAlignTranslationWithSource)

            if viewModel.translation.isTranslationAlignmentLocked {
                translationToolbarButton(title: BookL10n.string("translation.unlock")) {
                    viewModel.unlockTranslationAlignment()
                }
            } else if viewModel.translation.canUseTranslationTableView {
                translationToolbarButton(title: BookL10n.string("translation.lock"), prominent: true) {
                    viewModel.lockTranslationAlignment()
                }
            }

            Spacer(minLength: 8)

            if !viewModel.translation.showsTranslationTableView {
                translationToolbarButton(title: BookL10n.string("action.selectAll")) {
                    viewModel.translation.selectAllRightPage()
                }
                .disabled(
                    viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )

                if viewModel.assistant.isSpeakingExplanation && !viewModel.isRunning {
                    translationToolbarButton(
                        title: viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")
                    ) {
                        viewModel.assistant.toggleExplanationSpeechPause()
                    }
                }

                translationToolbarButton(
                    title: viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")
                ) {
                    if viewModel.assistant.isSpeakingExplanation {
                        viewModel.assistant.stopExplanationSpeech()
                    } else {
                        viewModel.assistant.readLessonPlanAloud()
                    }
                }
                .disabled(
                    viewModel.isRunning
                        || (
                            viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && !viewModel.assistant.isSpeakingExplanation
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
                items: viewModel.evolution.evolutionItems,
                projectPath: SelfEvolution.sourceProjectPath(),
                isRunning: viewModel.isRunning,
                isAnalyzing: viewModel.isAnalyzing,
                executingCommandNumber: viewModel.evolution.executingEvolutionCommandNumber,
                budget: viewModel.evolutionTokenBudget,
                liveToolLabel: viewModel.evolutionLiveToolLabel,
                lastRequestId: viewModel.evolution.evolutionLastRequestId,
                hasPending: viewModel.evolution.hasPendingOptimization,
                onAddUserItem: { viewModel.evolution.addUserOptimization(title: $0) },
                onSkip: { viewModel.evolution.skipOptimization(id: $0) },
                onDelete: { viewModel.evolution.deleteOptimization(id: $0) },
                onPin: { viewModel.evolution.pinOptimization(id: $0) },
                onRestore: { viewModel.evolution.restoreOptimization(id: $0) }
            )

            if viewModel.evolution.isEvolutionRebuilding {
                EvolutionRebuildBanner(status: viewModel.evolution.evolutionRebuildStatus)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }

            ExplanationChatTranscriptView()
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
                text: Binding(
                    get: { viewModel.lessonPlanContent },
                    set: { viewModel.lessonPlanContent = $0 }
                ),
                onSelectionChange: { selection, _ in
                    viewModel.assistant.updateLessonPlanSelection(selection)
                },
                onVisibleRangeChange: { range, _ in
                    viewModel.translation.handleTranslationTextScroll(visibleRange: range)
                },
                scrollProxy: viewModel.translation.translationTextScrollProxy,
                isEditable: !viewModel.isRunning,
                selectAllSignal: viewModel.document.rightSelectAllSignal
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

}

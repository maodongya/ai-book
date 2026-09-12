import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var learningPaneFocus: LearningPaneFocus = .both

    private let learningSpineWidth: CGFloat = 34

    var body: some View {
        let _ = settings.localizationRevision
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()
            BookTheme.deskLampGlow
                .ignoresSafeArea()

            if showsLearningWorkspace {
                VStack(spacing: 0) {
                    bookHeader
                        .bookStyleRefreshing()
                    openBook
                }
                .padding(24)
            }
        }
        .alert(BookL10n.string("alert.title.hint"), isPresented: errorBinding) {
            Button(BookL10n.string("action.ok"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
                .environmentObject(viewModel)
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .sheet(isPresented: $viewModel.showBookSettings) {
            BookSettingsView()
                .environmentObject(viewModel)
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .sheet(isPresented: $viewModel.showUserManual) {
            BookUserManualView()
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .sheet(isPresented: $viewModel.showDirectoryBrowser) {
            directoryBrowserSheet
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .frame(minWidth: 960, minHeight: 640)
        .animation(.easeOut(duration: 0.2), value: styleManager.presetID)
        .animation(.easeOut(duration: 0.2), value: learningPaneFocus)
        .onAppear {
            viewModel.onAppear()
        }
        .onChange(of: viewModel.experienceMode) { mode in
            if mode == .reading, learningPaneFocus != .both {
                setLearningPaneFocus(.both)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            if learningPaneFocus != .both {
                learningPaneFocus = .both
            }
        }
        .background(learningModeKeyboardShortcuts)
        .overlay {
            if showsLearningPaneFullscreen {
                learningPaneFullscreenOverlay
                    .bookStyleEnvironment(styleManager)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .overlay {
            if viewModel.experienceMode == .reading {
                ReadingSpreadView()
                    .bookStyleEnvironment(styleManager)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    }

    private var showsLearningWorkspace: Bool {
        viewModel.experienceMode == .learning && learningPaneFocus == .both
    }

    private var showsLearningPaneFullscreen: Bool {
        viewModel.experienceMode == .learning && learningPaneFocus != .both
    }

    private var learningModeKeyboardShortcuts: some View {
        Group {
            if viewModel.experienceMode == .learning {
                Button(BookL10n.string("layout.spread")) { setLearningPaneFocus(.both) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button(BookL10n.string("layout.leftFullscreen")) { setLearningPaneFocus(.leading) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button(BookL10n.string("layout.rightFullscreen")) { setLearningPaneFocus(.trailing) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
            }
            if viewModel.canEnterReadingMode, viewModel.experienceMode == .learning {
                Button(BookL10n.string("mode.reading")) {
                    viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
                }
                .keyboardShortcut(BookKeyboardShortcuts.readingMode)
            }
            if viewModel.experienceMode == .reading {
                Button(BookL10n.string("mode.learning")) {
                    viewModel.exitReadingMode()
                }
                .keyboardShortcut(.escape, modifiers: [])
                Button(BookL10n.string("mode.exitReading")) {
                    viewModel.exitReadingMode()
                }
                .keyboardShortcut(BookKeyboardShortcuts.readingMode)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bookHeader: some View {
        VStack(spacing: 8) {
            brandBlock

            Divider()
                .overlay(Color.white.opacity(0.12))

            toolbarActionRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BookTheme.leatherGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.36), radius: 14, y: 8)
        }
        .padding(.bottom, 12)
    }

    private var brandBlock: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(BookTheme.chromeOverlay.opacity(0.08))
                    .frame(width: 34, height: 34)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(AIBookProduct.displayName)
                        .font(BookTheme.titleFont)
                        .foregroundStyle(BookTheme.goldSoft)
                    if viewModel.rightPageTab == .readingAssistant {
                        BookStatusPill(
                            title: settings.isBookLLMConfigured ? settings.bookLLMDisplayLabel : BookL10n.string("status.bookLLM.unconfigured"),
                            icon: "book.closed.fill",
                            tint: Color.white.opacity(0.52)
                        )
                        .help(BookL10n.string("help.bookLLMSettings"))
                    } else if viewModel.rightPageTab == .aiEvolution {
                        BookStatusPill(
                            title: settings.isCursorRunnable
                                ? ModelTokenLimits.cursorModelLabel(settings.resolvedCursorModel)
                                : BookL10n.string("status.cursor.notReady"),
                            icon: "cursorarrow.rays",
                            tint: Color.white.opacity(0.66)
                        )
                        .help(BookL10n.string("help.evolutionCursorModel"))
                    }

                    Spacer(minLength: 12)

                    headerModeAndSourceControls
                }

                Text(viewModel.displayFileName)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.chromeMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 标签栏右侧：当前模式与对应模型摘要。
    private var headerModeAndSourceControls: some View {
        HStack(spacing: 8) {
            if viewModel.isDirty {
                BookStatusPill(title: BookL10n.string("status.unsaved"), icon: "circle.fill", tint: Color.orange.opacity(0.95))
                    .help(BookL10n.string("help.unsavedChanges"))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var bookLLMToolbarHelp: String {
        AppGuard.bookLLMErrorMessage(for: settings)
            ?? BookL10n.string("help.configureBookLLM")
    }

    private var evolutionToolbarHelp: String {
        AppGuard.evolutionErrorMessage(for: settings)
            ?? (viewModel.evolutionStatusLabel ?? BookL10n.string("help.evolutionDefault"))
    }

    @ViewBuilder
    private var bookLLMConfigGuideMenuItem: some View {
        if !settings.isBookLLMConfigured {
            Button {
                viewModel.openBookSettings()
            } label: {
                Text(BookL10n.string("guide.bookLLMSetup"))
            }
            BookToolbarMenuDivider()
        }
    }

    @ViewBuilder
    private var evolutionConfigGuideMenuItem: some View {
        if !settings.isCursorRunnable {
            Button {
                viewModel.openSettings()
            } label: {
                Text(BookL10n.string("guide.cursorSetup"))
            }
            BookToolbarMenuDivider()
        }
    }

    private var requiresBookLLM: Bool { !settings.isBookLLMConfigured }

    private var requiresEvolutionBackend: Bool { !settings.isCursorRunnable }

    private var isReadingToolbarContext: Bool {
        viewModel.rightPageTab == .readingAssistant
    }

    private func toolbarColumnWidths(totalWidth: CGFloat) -> (left: CGFloat, center: CGFloat, right: CGFloat) {
        let dividerSpan = Self.toolbarDividerSpan
        let dividers = dividerSpan * 2
        switch viewModel.rightPageTab {
        case .readingAssistant:
            let left = totalWidth * 2 / 5
            let remaining = max(0, totalWidth - left - dividers)
            let side = remaining / 2
            return (left, side, side)
        case .aiEvolution:
            let left = totalWidth / 5
            let right = totalWidth / 5
            let center = max(0, totalWidth - left - right - dividers)
            return (left, center, right)
        }
    }

    private var toolbarActionRow: some View {
        GeometryReader { geometry in
            let widths = toolbarColumnWidths(totalWidth: geometry.size.width)

            HStack(spacing: 0) {
                documentActionBar
                    .frame(width: widths.left, alignment: .leading)

                toolbarSectionDivider

                readingActionBar
                    .frame(width: widths.center, alignment: .center)

                toolbarSectionDivider

                utilityActionBar
                    .frame(width: widths.right, alignment: .trailing)
            }
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.2), value: viewModel.rightPageTab)
        .animation(.easeOut(duration: 0.2), value: viewModel.readingAssistantPanel)
    }

    private static let toolbarDividerSpan: CGFloat = 21

    private var toolbarSectionDivider: some View {
        Rectangle()
            .fill(BookTheme.chromeOverlay.opacity(0.14))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 10)
    }

    private var documentActionBar: some View {
        BookToolbarOverflowRow {
            documentActionBarFull
        } compact: {
            documentActionBarCompact
        } minimal: {
            documentActionBarMinimal
        }
    }

    private var documentActionBarFull: some View {
        HStack(spacing: 8) {
            readingAssistantTabButton
            readingModeToolbarButton
            if isReadingToolbarContext {
                bookSettingsToolbarButton
            }
            documentOperationsMenu
            if isReadingToolbarContext, viewModel.readingAssistantPanel == .explanation {
                explanationOperationsMenu
            }
            if isReadingToolbarContext, viewModel.readingAssistantPanel == .translation {
                translationOperationsMenu
            }
            if isReadingToolbarContext {
                speechOperationsMenu
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var documentActionBarCompact: some View {
        HStack(spacing: 8) {
            readingAssistantTabButton
            documentOperationsMenu
            if isReadingToolbarContext, viewModel.readingAssistantPanel == .explanation {
                explanationOperationsMenu
            } else if isReadingToolbarContext, viewModel.readingAssistantPanel == .translation {
                translationOperationsMenu
            }
            if isReadingToolbarContext {
                documentToolbarOverflowMenu(includeDocumentMenu: false)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var documentActionBarMinimal: some View {
        HStack(spacing: 8) {
            readingAssistantTabButton
            documentToolbarOverflowMenu(includeDocumentMenu: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var readingAssistantTabButton: some View {
        BookActionButton(
            title: RightPageTab.readingAssistant.localizedTitle,
            isProminent: viewModel.rightPageTab == .readingAssistant,
            isCompact: true
        ) {
            viewModel.selectRightPageTab(.readingAssistant)
        }
        .help(BookL10n.string("help.switchReadingAssistant"))
    }

    private var readingModeToolbarButton: some View {
        BookActionButton(
            title: BookL10n.string("mode.reading"),
            isProminent: false,
            isCompact: true
        ) {
            viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
        }
        .disabled(!viewModel.canEnterReadingMode || viewModel.isRunning)
        .help(BookL10n.format("help.enterReadingMode", BookKeyboardShortcuts.readingModeHint))
    }

    private var bookSettingsToolbarButton: some View {
        BookActionButton(
            title: BookL10n.string("settings.book"),
            isProminent: false,
            isCompact: true
        ) {
            viewModel.openBookSettings()
        }
        .help(BookL10n.string("help.configureBookLLM"))
    }

    @ViewBuilder
    private var documentOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        Button {
            viewModel.newDocument()
        } label: {
            Text(BookL10n.string("action.new"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.newDocument)
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openFile()
        } label: {
            Text(BookL10n.string("action.open"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.openDocument)
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openDirectory()
        } label: {
            Text(BookL10n.string("action.openDirectoryShort"))
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
        } label: {
            Text(BookL10n.string("mode.reading"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.readingMode)
        .disabled(!viewModel.canEnterReadingMode || viewModel.isRunning)

        BookToolbarMenuDivider()

        Button {
            viewModel.save()
        } label: {
            Text(BookL10n.string("action.save"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.save)
        .disabled(viewModel.fileContent.isEmpty && !viewModel.isDirty)

        Button {
            viewModel.saveAs()
        } label: {
            Text(BookL10n.string("action.saveAs"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.saveAs)
        .disabled(viewModel.fileContent.isEmpty)

        Button {
            viewModel.selectAllLeftPage()
        } label: {
            Text(BookL10n.string("action.selectAllSource"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.selectAllLeftPage)
        .disabled(viewModel.fileContent.isEmpty)

        BookToolbarMenuDivider()

        Button {
            viewModel.supplementClassicLiterature()
        } label: {
            Text(ClassicLiteratureSupplement.capabilityLabel)
        }
        .bookMenuShortcut(BookKeyboardShortcuts.classicSupplement)
        .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning || requiresBookLLM)
    }

    private var documentOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.document")) {
            documentOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.documentMenu", BookKeyboardShortcuts.documentMenuSummary))
    }

    @ViewBuilder
    private func documentToolbarOverflowMenu(includeDocumentMenu: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.toolbarDocOverflow")) {
            if isReadingToolbarContext {
                Button {
                    viewModel.openBookSettings()
                } label: {
                    Text(BookL10n.string("settings.book"))
                }
                BookToolbarMenuDivider()
            }

            if includeDocumentMenu {
                BookToolbarSubmenu(title: BookL10n.string("menu.document")) {
                    documentOperationsMenuContent
                }
            }

            if isReadingToolbarContext {
                if includeDocumentMenu || viewModel.readingAssistantPanel != .explanation {
                    BookToolbarSubmenu(title: BookL10n.string("menu.explanation")) {
                        explanationOperationsMenuContent
                    }
                }
                if includeDocumentMenu || viewModel.readingAssistantPanel != .translation {
                    BookToolbarSubmenu(title: BookL10n.string("menu.translation")) {
                        translationOperationsMenuContent
                    }
                }
                BookToolbarSubmenu(title: BookL10n.string("menu.speech")) {
                    speechOperationsMenuContent
                }
            }
        }
    }

    private var explanationOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.explanation")) {
            explanationOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explanationMenu", BookKeyboardShortcuts.explanationMenuSummary))
    }

    @ViewBuilder
    private var explanationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        Button {
            viewModel.explainSelection()
        } label: {
            Text(BookL10n.string("action.explainSelection"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)
        .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

        Button {
            viewModel.explainFullText()
        } label: {
            Text(BookL10n.string("action.explainFull"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)
        .disabled(
            requiresBookLLM
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isRunning
        )

        BookToolbarMenuDivider()

        Button {
            viewModel.newExplanationDocument()
        } label: {
            Text(BookL10n.string("action.new"))
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openExplanationDocument()
        } label: {
            Text(BookL10n.string("action.open"))
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.saveExplanationDocument()
        } label: {
            Text(BookL10n.string("action.save"))
        }
        .disabled(!viewModel.hasExplanationContent)

        Button {
            viewModel.selectAllExplanation()
        } label: {
            Text(BookL10n.string("action.selectAll"))
        }
        .disabled(!viewModel.hasExplanationContent)

        Button(role: .destructive) {
            viewModel.clearExplanation()
        } label: {
            Text(BookL10n.string("action.clearExplanation"))
        }
        .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

        BookToolbarMenuDivider()

        Button {
            viewModel.readExplanationAloud()
        } label: {
            Text(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readExplanation"))
        }
        .disabled(viewModel.isRunning || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation))
    }

    private var translationOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.translation")) {
            translationOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.translationMenu", BookKeyboardShortcuts.translationMenuSummary))
    }

    @ViewBuilder
    private var translationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        BookToolbarSubmenu(title: BookL10n.string("translation.target.title")) {
            ForEach(TranslationTargetLanguage.allCases) { language in
                Button {
                    settings.translationTargetLanguage = language
                } label: {
                    HStack {
                        Text(language.localizedName)
                        if settings.translationTargetLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        BookToolbarMenuDivider()

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.generateLessonPlan()
        } label: {
            Text(BookL10n.string("action.wordTranslation"))
        }
        .disabled(
            requiresBookLLM
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isRunning
        )

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.refineLessonPlan()
        } label: {
            Text(BookL10n.string("action.paragraphTranslation"))
        }
        .disabled(
            requiresBookLLM
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isRunning
        )

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.readLessonPlanAloud()
        } label: {
            Text(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readTranslation"))
        }
        .bookMenuShortcut(
            viewModel.isSpeakingExplanation ? nil : BookKeyboardShortcuts.readTranslationFull
        )
        .disabled(
            viewModel.isRunning
                || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.selectAllRightPage()
        } label: {
            Text(BookL10n.string("action.selectAllTranslation"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        BookToolbarMenuDivider()

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.openLessonPlanFile()
        } label: {
            Text(BookL10n.string("action.openTranslation"))
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.alignTranslationWithSource()
        } label: {
            Text(BookL10n.string("translation.alignSource"))
        }
        .disabled(!viewModel.canAlignTranslationWithSource)

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.saveLessonPlan()
        } label: {
            Text(BookL10n.string("action.saveTranslation"))
        }
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button(role: .destructive) {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.clearLessonPlan()
        } label: {
            Text(BookL10n.string("action.clearTranslation"))
        }
        .disabled(viewModel.isRunning || viewModel.lessonPlanContent.isEmpty)
    }

    private var speechOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.speech")) {
            speechOperationsMenuContent
        }
        .help(BookL10n.format("help.speechMenu", BookKeyboardShortcuts.speechMenuSummary))
    }

    @ViewBuilder
    private var speechOperationsMenuContent: some View {
        Button {
            viewModel.readOriginalFullTextAloud()
        } label: {
            Text(BookL10n.string("menu.readOriginalFull"))
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.readOriginalSelectionAloud()
        } label: {
            Text(BookL10n.string("menu.readOriginalSelection"))
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.effectiveSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
        )

        BookToolbarMenuDivider()

        Button {
            viewModel.readTranslationFullTextAloud()
        } label: {
            Text(BookL10n.string("menu.readTranslationFull"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.readTranslationFull)
        .disabled(
            viewModel.isRunning
                || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.readTranslationSelectionAloud()
        } label: {
            Text(BookL10n.string("menu.readTranslationSelection"))
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.effectiveLessonPlanSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
        )

        BookToolbarMenuDivider()

        Button {
            viewModel.readExplanationFullTextAloud()
        } label: {
            Text(BookL10n.string("menu.readExplanationFull"))
        }
        .disabled(
            viewModel.isRunning
                || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.readExplanationSelectionAloud()
        } label: {
            Text(BookL10n.string("menu.readExplanationSelection"))
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.effectiveExplanationPanelSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
        )
    }

    private var readingActionBar: some View {
        Group {
            if viewModel.isSpeakingExplanation {
                BookToolbarOverflowRow {
                    unifiedSpeechPlaybackBarFull
                } compact: {
                    unifiedSpeechPlaybackBarCompact
                } minimal: {
                    unifiedSpeechPlaybackBarMinimal
                }
            } else if isReadingToolbarContext {
                BookToolbarOverflowRow {
                    readingPrimaryActionBarFull
                } compact: {
                    readingPrimaryActionBarCompact
                } minimal: {
                    readingPrimaryActionBarMinimal
                }
            } else {
                BookToolbarOverflowRow {
                    evolutionPrimaryActionBarFull
                } compact: {
                    evolutionPrimaryActionBarCompact
                } minimal: {
                    evolutionPrimaryActionBarMinimal
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.18), value: viewModel.isSpeakingExplanation)
        .animation(.easeOut(duration: 0.2), value: viewModel.rightPageTab)
    }

    private var readingPrimaryActionBarFull: some View {
        HStack(spacing: 8) {
            readingAssistantPanelSwitcher
            switch viewModel.readingAssistantPanel {
            case .explanation:
                explanationPrimaryActionButtons
            case .translation:
                translationPrimaryActionButtons
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var readingPrimaryActionBarCompact: some View {
        HStack(spacing: 8) {
            readingAssistantPanelSwitcher
            readingPrimaryOverflowMenu(includePanelSwitcher: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var readingPrimaryActionBarMinimal: some View {
        HStack(spacing: 8) {
            readingPrimaryOverflowMenu(includePanelSwitcher: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func readingPrimaryOverflowMenu(includePanelSwitcher: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.panelOverflow")) {
            if includePanelSwitcher {
                ForEach(ReadingAssistantPanel.allCases) { panel in
                    Button {
                        viewModel.selectRightPageTab(.readingAssistant)
                        viewModel.selectReadingAssistantPanel(panel)
                    } label: {
                        Text(panel.toolbarTitle)
                    }
                }
                BookToolbarMenuDivider()
            }

            switch viewModel.readingAssistantPanel {
            case .explanation:
                Button {
                    viewModel.explainSelection()
                } label: {
                    Text(BookL10n.string("action.explainSelection"))
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)
                .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

                Button {
                    viewModel.explainFullText()
                } label: {
                    Text(BookL10n.string("action.explainFull"))
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)
                .disabled(
                    requiresBookLLM
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )
            case .translation:
                Button {
                    viewModel.generateLessonPlan()
                } label: {
                    Text(BookL10n.string("action.wordTranslation"))
                }
                .disabled(
                    requiresBookLLM
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )

                Button {
                    viewModel.refineLessonPlan()
                } label: {
                    Text(BookL10n.string("action.paragraphTranslation"))
                }
                .disabled(
                    requiresBookLLM
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )
            }
        }
    }

    private var readingAssistantPanelSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(ReadingAssistantPanel.allCases) { panel in
                BookActionButton(
                    title: panel.toolbarTitle,
                    isProminent: viewModel.rightPageTab == .readingAssistant
                        && viewModel.readingAssistantPanel == panel,
                    isCompact: true
                ) {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.selectReadingAssistantPanel(panel)
                }
                .help(panel.toolbarHelp)
            }
        }
    }

    private var evolutionPrimaryActionBarFull: some View {
        HStack(spacing: 8) {
            evolutionPrimaryActionButtons
            if viewModel.isRunning {
                evolutionStopButton
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var evolutionPrimaryActionBarCompact: some View {
        HStack(spacing: 8) {
            BookActionButton(
                title: BookL10n.string("action.evolve"),
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.startEvolution()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.format("help.runNextEvolution", BookKeyboardShortcuts.evolutionHint))

            evolutionPrimaryOverflowMenu(includeEvolution: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var evolutionPrimaryActionBarMinimal: some View {
        HStack(spacing: 8) {
            evolutionPrimaryOverflowMenu(includeEvolution: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func evolutionPrimaryOverflowMenu(includeEvolution: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.evolutionOverflow")) {
            if includeEvolution {
                Button {
                    viewModel.startEvolution()
                } label: {
                    Text(BookL10n.string("action.evolve"))
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)
                .disabled(requiresEvolutionBackend || viewModel.isRunning)
            }

            Button {
                viewModel.analyzeOptimizations()
            } label: {
                Text(BookL10n.string("action.analyze"))
            }
            .disabled(requiresEvolutionBackend || viewModel.isRunning)

            if viewModel.isRunning {
                Button {
                    viewModel.stopCurrentRun()
                } label: {
                    Text(BookL10n.string("action.stop"))
                }
            }
        }
    }

    private var unifiedSpeechPlaybackBarFull: some View {
        HStack(spacing: 8) {
            speechSourcePill
            speechPauseResumeButton
            speechStopButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var unifiedSpeechPlaybackBarCompact: some View {
        HStack(spacing: 8) {
            speechSourcePill
            speechPlaybackOverflowMenu(includeSource: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var unifiedSpeechPlaybackBarMinimal: some View {
        HStack(spacing: 8) {
            speechPlaybackOverflowMenu(includeSource: true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var speechSourcePill: some View {
        if let source = viewModel.currentSpeechSource {
            BookStatusPill(
                title: source.label,
                icon: source.icon,
                tint: BookTheme.goldSoft
            )
            .help(BookL10n.format("help.currentSpeech", source.label))
        } else {
            BookStatusPill(
                title: BookL10n.string("status.speaking"),
                icon: "speaker.wave.2.fill",
                tint: BookTheme.goldSoft
            )
            .help(BookL10n.string("help.speakingNow"))
        }
    }

    private var speechPauseResumeButton: some View {
        BookActionButton(
            title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause"),
            isCompact: true,
            isDisabled: viewModel.isRunning
        ) {
            viewModel.toggleExplanationSpeechPause()
        }
        .help(viewModel.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))
    }

    private var speechStopButton: some View {
        BookActionButton(
            title: BookL10n.string("action.stop"),
            isCompact: true,
            isDisabled: viewModel.isRunning
        ) {
            viewModel.stopExplanationSpeech()
        }
        .help(BookL10n.string("help.stopSpeech"))
    }

    @ViewBuilder
    private func speechPlaybackOverflowMenu(includeSource: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.speechControls")) {
            if includeSource, let source = viewModel.currentSpeechSource {
                BookToolbarMenuCaption(title: BookL10n.format("help.currentSpeech", source.label))
            } else if includeSource {
                BookToolbarMenuCaption(title: BookL10n.string("status.speaking"))
            }
            if includeSource {
                BookToolbarMenuDivider()
            }

            Button {
                viewModel.toggleExplanationSpeechPause()
            } label: {
                Text(viewModel.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))
            }
            .disabled(viewModel.isRunning)

            Button {
                viewModel.stopExplanationSpeech()
            } label: {
                Text(BookL10n.string("menu.stopSpeaking"))
            }
            .disabled(viewModel.isRunning)
        }
    }

    private var explanationPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: BookL10n.string("action.explainSelection"),
                isCompact: true,
                isDisabled: requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning
            ) {
                viewModel.explainSelection()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainSelection", BookKeyboardShortcuts.explainSelectionHint))

            BookActionButton(
                title: BookL10n.string("action.explainFull"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.explainFullText()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainFull", BookKeyboardShortcuts.explainFullTextHint))
        }
    }

    private var translationPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: BookL10n.string("action.wordTranslation"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.generateLessonPlan()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.wordTranslationJSON"))

            BookActionButton(
                title: BookL10n.string("action.paragraphTranslation"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.refineLessonPlan()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.paragraphTranslationJSON"))
        }
    }

    private var evolutionPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: BookL10n.string("action.evolve"),
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.startEvolution()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.format("help.runNextEvolution", BookKeyboardShortcuts.evolutionHint))

            BookActionButton(
                title: BookL10n.string("action.analyze"),
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.analyzeOptimizations()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.string("help.analyzeSource"))
        }
    }

    private var evolutionStopButton: some View {
        BookActionButton(
            title: BookL10n.string("action.stop"),
            isCompact: true
        ) {
            viewModel.stopCurrentRun()
        }
        .help(BookL10n.string("help.stopEvolutionTask"))
    }

    private var utilityActionBar: some View {
        BookToolbarOverflowRow {
            utilityActionBarFull
        } compact: {
            utilityActionBarCompact
        } minimal: {
            utilityActionBarMinimal
        }
    }

    private var utilityActionBarFull: some View {
        HStack(spacing: 8) {
            aiEvolutionTabButton
            if !isReadingToolbarContext {
                evolutionOperationsMenu
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var utilityActionBarCompact: some View {
        HStack(spacing: 8) {
            aiEvolutionTabButton
            if !isReadingToolbarContext {
                utilityEvolutionOverflowMenu(includeTab: false)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var utilityActionBarMinimal: some View {
        HStack(spacing: 8) {
            if isReadingToolbarContext {
                aiEvolutionTabButton
            } else {
                utilityEvolutionOverflowMenu(includeTab: true)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var aiEvolutionTabButton: some View {
        BookActionButton(
            title: RightPageTab.aiEvolution.localizedTitle,
            isProminent: viewModel.rightPageTab == .aiEvolution,
            isCompact: true
        ) {
            viewModel.selectRightPageTab(.aiEvolution)
        }
        .help(BookL10n.string("help.switchEvolution"))
    }

    @ViewBuilder
    private func utilityEvolutionOverflowMenu(includeTab: Bool) -> some View {
        BookToolbarOverflowMenu(
            help: requiresEvolutionBackend
                ? evolutionToolbarHelp
                : (viewModel.evolutionStatusLabel ?? BookL10n.format("help.evolutionDefaultMenu", BookKeyboardShortcuts.evolutionMenuSummary))
        ) {
            if includeTab {
                Button {
                    viewModel.selectRightPageTab(.aiEvolution)
                } label: {
                    Text(RightPageTab.aiEvolution.localizedTitle)
                }
                BookToolbarMenuDivider()
            }

            BookToolbarSubmenu(
                title: RightPageTab.aiEvolution.toolbarMenuTitle ?? RightPageTab.aiEvolution.localizedTitle
            ) {
                evolutionOperationsMenuContent
            }
        }
    }

    private var evolutionOperationsMenu: some View {
        BookToolbarMenuButton(
            title: RightPageTab.aiEvolution.toolbarMenuTitle ?? RightPageTab.aiEvolution.rawValue
        ) {
            evolutionOperationsMenuContent
        }
        .help(requiresEvolutionBackend ? evolutionToolbarHelp : (viewModel.evolutionStatusLabel ?? BookL10n.format("help.evolutionDefaultMenu", BookKeyboardShortcuts.evolutionMenuSummary)))
    }

    @ViewBuilder
    private var evolutionOperationsMenuContent: some View {
        evolutionConfigGuideMenuItem

        Button {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.startEvolution()
        } label: {
            Text(BookL10n.string("action.evolve"))
        }
        .bookMenuShortcut(BookKeyboardShortcuts.evolution)
        .disabled(requiresEvolutionBackend || viewModel.isRunning)

        Button {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.analyzeOptimizations()
        } label: {
            Text(BookL10n.string("action.analyze"))
        }
        .disabled(requiresEvolutionBackend || viewModel.isRunning)

        Button {
            viewModel.openSettings()
        } label: {
            Text(BookL10n.string("settings.evolution"))
        }

        BookToolbarMenuDivider()

        Button {
            viewModel.saveEvolutionCommands()
        } label: {
            Text(BookL10n.string("action.saveEvolutionCommands"))
        }
        .disabled(!viewModel.canSaveEvolutionCommands)

        Button {
            viewModel.openEvolutionCommands()
        } label: {
            Text(BookL10n.string("action.openEvolutionCommands"))
        }
        .disabled(!viewModel.canOpenEvolutionCommands)

        Button(role: .destructive) {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.clearAIContext()
        } label: {
            Text(BookL10n.string("action.clearAIContext"))
        }
        .disabled(viewModel.isRunning || !viewModel.canClearAIContext)

        if viewModel.isRunning {
            BookToolbarMenuDivider()

            Button {
                viewModel.stopCurrentRun()
            } label: {
                Text(BookL10n.string("action.stop"))
            }
        }
    }

    private var openBook: some View {
        GeometryReader { geometry in
            let pageWidth = max(0, (geometry.size.width - learningSpineWidth) / 2)

            BookInterface.SpreadShell {
                HStack(spacing: 0) {
                    leftPage
                        .frame(width: pageWidth)

                    ZStack(alignment: .top) {
                        bookSpine
                        BookInterface.BookmarkRibbon()
                    }

                    rightPage
                        .frame(width: pageWidth)
                }
            }
        }
    }

    private var learningPaneFullscreenOverlay: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()
            BookTheme.deskLampGlow
                .ignoresSafeArea()

            VStack(spacing: 14) {
                learningPaneFullscreenHeader
                Group {
                    if learningPaneFocus == .leading {
                        leftPage
                    } else {
                        rightPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
        }
        .background(learningPaneFullscreenShortcuts)
    }

    private var learningPaneFullscreenHeader: some View {
        HStack(spacing: 12) {
            Button(action: { setLearningPaneFocus(.both) }) {
                BookToolbarCapsuleLabel(
                    title: BookL10n.string("layout.spread"),
                    isProminent: true,
                    isCompact: false,
                    isHovering: false
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(BookL10n.string("help.restoreSpread"))
            .keyboardShortcut(.escape, modifiers: [])

            Text(learningPaneFullscreenTitle)
                .font(BookTheme.titleFont)
                .foregroundStyle(BookTheme.goldSoft)
                .lineLimit(1)
                .layoutPriority(-1)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BookTheme.leatherGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)
        }
    }

    private var learningPaneFullscreenShortcuts: some View {
        Group {
            Button(BookL10n.string("layout.spread")) { setLearningPaneFocus(.both) }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var leftPage: some View {
        VStack(spacing: 0) {
            pageLabel(
                title: BookL10n.string("page.source"),
                icon: "text.book.closed",
                paneSide: .leading
            )

            ZStack {
                SelectableTextView(
                    text: $viewModel.fileContent,
                    onSelectionChange: { selection, range in
                        viewModel.updateSelection(selection, range: range)
                    },
                    onVisibleRangeChange: { range, _ in
                        viewModel.handleSourceTextScroll(visibleRange: range)
                    },
                    scrollProxy: viewModel.sourceTextScrollProxy,
                    selectAllSignal: viewModel.leftSelectAllSignal
                )
                .id("leftPageTextView")

                if viewModel.fileContent.isEmpty && !viewModel.isDocumentOpen {
                    BookInterface.EmptyPageWelcome {
                        viewModel.openFile()
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                BookInterface.PageCornerFold()
            }

            leftPageFooter
        }
        .bookPaperTexture()
        .bookPage(BookTheme.pageLeft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
    }

    private var leftPageFooter: some View {
        HStack(spacing: 16) {
            BookInterface.PageMark(label: BookInterface.leftPageMark)
            Label(BookL10n.format("footer.characters", viewModel.fileContent.count), systemImage: "character.cursor.ibeam")
            if !viewModel.effectiveSelectedText.isEmpty {
                Label(BookL10n.format("footer.selected", viewModel.effectiveSelectedText.count), systemImage: "highlighter")
            }
            Spacer()
            Button(BookL10n.string("action.selectAll")) {
                viewModel.selectAllLeftPage()
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.leather)
            .disabled(viewModel.fileContent.isEmpty)
            .help(BookL10n.string("help.selectAllLeftPage"))
            Text(leftPageSaveStatus)
                .foregroundStyle(viewModel.isDirty ? Color.orange : BookTheme.inkMuted)
        }
        .font(BookTheme.captionFont)
        .foregroundStyle(BookTheme.inkMuted)
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(BookTheme.pageEdge.opacity(0.22))
                .overlay(alignment: .top) { Divider() }
        }
    }

    private var rightPage: some View {
        VStack(spacing: 0) {
            if showsRightPageLabel {
                pageLabel(
                    title: viewModel.rightPageTab.localizedTitle,
                    icon: viewModel.rightPageTab.icon,
                    paneSide: .trailing
                )
            }

            ExplanationChatView(
                learningPaneFocus: learningPaneFocus,
                onLearningPaneFocusChange: setLearningPaneFocus
            )
        }
        .overlay(alignment: .bottomTrailing) {
            BookInterface.PageCornerFold()
        }
        .bookPaperTexture()
        .bookPage(BookTheme.pageRight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var showsRightPageLabel: Bool {
        viewModel.rightPageTab == .aiEvolution
    }

    private var learningPaneFullscreenTitle: String {
        if learningPaneFocus == .leading {
            return viewModel.displayFileName
        }
        if viewModel.rightPageTab == .readingAssistant {
            return viewModel.readingAssistantPanel.toolbarTitle
        }
        return viewModel.rightPageTab.localizedTitle
    }

    private var bookSpine: some View {
        ZStack {
            LinearGradient(
                colors: [BookTheme.spineLight, BookTheme.spineDark, BookTheme.spineLight],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(spacing: 6) {
                ForEach(0 ..< 12, id: \.self) { _ in
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 2, height: 10)
                }
            }
        }
        .frame(width: 14)
        .shadow(color: .black.opacity(0.25), radius: 4)
    }

    private func pageLabel(title: String, icon: String, subtitle: String? = nil, paneSide: HorizontalEdge? = nil) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BookTheme.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkMuted)
                    }
                }

                Spacer()

                if let paneSide {
                    learningPaneFocusButton(for: paneSide)
                }

                Rectangle()
                    .fill(BookTheme.pageEdge.opacity(0.8))
                    .frame(height: 1)
                    .frame(maxWidth: 120)
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 8)

            BookInterface.HeaderOrnament()
                .padding(.bottom, 6)
        }
    }

    private func setLearningPaneFocus(_ focus: LearningPaneFocus) {
        guard learningPaneFocus != focus else { return }
        learningPaneFocus = focus
        if focus == .both {
            WindowFullscreenHelper.setNativeFullscreen(false)
        } else {
            WindowFullscreenHelper.setNativeFullscreen(true)
        }
    }

    private func learningPaneFocusButton(for side: HorizontalEdge) -> some View {
        let isFocused = (side == .leading && learningPaneFocus == .leading)
            || (side == .trailing && learningPaneFocus == .trailing)
        let targetFocus: LearningPaneFocus = side == .leading ? .leading : .trailing

        return Button {
            setLearningPaneFocus(isFocused ? .both : targetFocus)
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
        .help(isFocused ? BookL10n.string("help.restoreSpreadFromFocus") : side == .leading ? BookL10n.string("help.leftFullscreen") : BookL10n.string("help.rightFullscreen"))
    }

    private var leftPageSaveStatus: String {
        if let message = viewModel.lastSaveMessage {
            return message
        }
        if viewModel.isEditingNotes {
            return viewModel.isDirty ? BookL10n.string("status.saving") : BookL10n.string("status.autosaved")
        }
        return viewModel.isDirty ? BookL10n.string("status.unsaved") : BookL10n.string("status.saved")
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            Task { @MainActor in
                viewModel.openDroppedFile(at: url)
            }
        }
        return true
    }

    private var directoryBrowserSheet: some View {
        DirectoryBrowserView(
            sessions: viewModel.directoryBrowserSessions,
            selectedSessionID: viewModel.selectedDirectorySessionID,
            onSelectSession: { id in
                viewModel.selectDirectorySession(id)
            },
            onAddDirectory: {
                viewModel.addDirectoryFromPanel()
            },
            onRemoveSession: { id in
                viewModel.removeDirectorySession(id)
            },
            onToggleExpanded: { sessionID, path in
                viewModel.toggleDirectoryNodeExpanded(sessionID: sessionID, path: path)
            },
            onOpen: { url, target in
                viewModel.openFileFromDirectory(at: url, target: target)
            },
            onDismiss: {
                viewModel.dismissDirectoryBrowser()
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

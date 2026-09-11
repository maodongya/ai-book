import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var learningPaneFocus: LearningPaneFocus = .both
    @AppStorage("aiBook.readingChromeVisible") private var isReadingChromeVisible = true

    private let learningSpineWidth: CGFloat = 34

    var body: some View {
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
        .alert("提示", isPresented: errorBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
                .bookStyleEnvironment(styleManager)
        }
        .sheet(isPresented: $viewModel.showBookSettings) {
            BookSettingsView()
                .bookStyleEnvironment(styleManager)
        }
        .sheet(isPresented: $viewModel.showDirectoryBrowser) {
            directoryBrowserSheet
                .bookStyleEnvironment(styleManager)
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
                Button("双页") { setLearningPaneFocus(.both) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("左全屏") { setLearningPaneFocus(.leading) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("右全屏") { setLearningPaneFocus(.trailing) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
            }
            if viewModel.canEnterReadingMode, viewModel.experienceMode == .learning {
                Button("阅读模式") {
                    viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
                }
                .keyboardShortcut(BookKeyboardShortcuts.readingMode)
            }
            if viewModel.experienceMode == .reading {
                Button("学习模式") {
                    viewModel.exitReadingMode()
                }
                .keyboardShortcut(.escape, modifiers: [])
                Button("退出阅读模式") {
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
                    BookStatusPill(title: AIBookProduct.slug, tint: Color.white.opacity(0.58))
                        .help(AIBookProduct.positioning.trimmingCharacters(in: .whitespacesAndNewlines))
                    BookStatusPill(title: AIBookProduct.tagline, tint: Color.white.opacity(0.58))
                    BookStatusPill(title: SwiftPlatform.implementationLabel, tint: Color.white.opacity(0.50))
                        .help(SwiftPlatform.runtimeDescription)
                    if viewModel.evolutionStatusLabel != nil {
                        BookStatusPill(title: SelfEvolution.capabilityLabel, icon: "arrow.triangle.2.circlepath", tint: Color.white.opacity(0.52))
                            .help(viewModel.evolutionStatusLabel ?? "")
                    }
                    if viewModel.rightPageTab == .readingAssistant {
                        BookStatusPill(
                            title: settings.isBookLLMConfigured ? settings.bookLLMDisplayLabel : "book 未配置",
                            icon: "book.closed.fill",
                            tint: Color.white.opacity(0.52)
                        )
                        .help("读书大模型（book 设置）")
                    } else if viewModel.rightPageTab == .aiEvolution {
                        BookStatusPill(
                            title: settings.isCursorRunnable
                                ? ModelTokenLimits.cursorModelLabel(settings.resolvedCursorModel)
                                : "Cursor 未就绪",
                            icon: "cursorarrow.rays",
                            tint: Color.white.opacity(0.66)
                        )
                        .help("AI 进化 Cursor 模型")
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
                BookStatusPill(title: "未保存", icon: "circle.fill", tint: Color.orange.opacity(0.95))
                    .help("有未保存的修改")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var bookLLMToolbarHelp: String {
        AppGuard.bookLLMErrorMessage(for: settings)
            ?? "配置读书助手大模型（推荐本机 Ollama）"
    }

    private var evolutionToolbarHelp: String {
        AppGuard.evolutionErrorMessage(for: settings)
            ?? (viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置")
    }

    @ViewBuilder
    private var bookLLMConfigGuideMenuItem: some View {
        if !settings.isBookLLMConfigured {
            Button {
                viewModel.openBookSettings()
            } label: {
                Text("未配置 book 大模型 · 点击设置")
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
                Text("Cursor 未就绪 · 点击进化设置")
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
            title: RightPageTab.readingAssistant.rawValue,
            isProminent: viewModel.rightPageTab == .readingAssistant,
            isCompact: true
        ) {
            viewModel.selectRightPageTab(.readingAssistant)
        }
        .help("切换到读书助手：讲解、朗读与文章翻译")
    }

    private var readingModeToolbarButton: some View {
        BookActionButton(
            title: "阅读模式",
            isProminent: false,
            isCompact: true
        ) {
            viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
        }
        .disabled(!viewModel.canEnterReadingMode || viewModel.isRunning)
        .help("进入全屏阅读：左右双页翻页 · \(BookKeyboardShortcuts.readingModeHint)")
    }

    private var bookSettingsToolbarButton: some View {
        BookActionButton(
            title: "book设置",
            isProminent: false,
            isCompact: true
        ) {
            viewModel.openBookSettings()
        }
        .help("配置读书助手大模型（推荐本机 Ollama）")
    }

    @ViewBuilder
    private var documentOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        Button {
            viewModel.newDocument()
        } label: {
            Text("新建")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.newDocument)
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openFile()
        } label: {
            Text("打开")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.openDocument)
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openDirectory()
        } label: {
            Text("打开目录")
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
        } label: {
            Text("阅读模式")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.readingMode)
        .disabled(!viewModel.canEnterReadingMode || viewModel.isRunning)

        BookToolbarMenuDivider()

        Button {
            viewModel.save()
        } label: {
            Text("保存")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.save)
        .disabled(viewModel.fileContent.isEmpty && !viewModel.isDirty)

        Button {
            viewModel.saveAs()
        } label: {
            Text("另存为")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.saveAs)
        .disabled(viewModel.fileContent.isEmpty)

        Button {
            viewModel.selectAllLeftPage()
        } label: {
            Text("原文全选")
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
        BookToolbarMenuButton(title: "原文操作") {
            documentOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : "新建、打开、保存、另存为、全选与名著补充 · \(BookKeyboardShortcuts.documentMenuSummary)")
    }

    @ViewBuilder
    private func documentToolbarOverflowMenu(includeDocumentMenu: Bool) -> some View {
        BookToolbarOverflowMenu(help: "原文、讲解、翻译与朗读等操作") {
            if isReadingToolbarContext {
                Button {
                    viewModel.openBookSettings()
                } label: {
                    Text("book设置")
                }
                BookToolbarMenuDivider()
            }

            if includeDocumentMenu {
                BookToolbarSubmenu(title: "原文操作") {
                    documentOperationsMenuContent
                }
            }

            if isReadingToolbarContext {
                if includeDocumentMenu || viewModel.readingAssistantPanel != .explanation {
                    BookToolbarSubmenu(title: "讲解操作") {
                        explanationOperationsMenuContent
                    }
                }
                if includeDocumentMenu || viewModel.readingAssistantPanel != .translation {
                    BookToolbarSubmenu(title: "翻译操作") {
                        translationOperationsMenuContent
                    }
                }
                BookToolbarSubmenu(title: "朗读功能") {
                    speechOperationsMenuContent
                }
            }
        }
    }

    private var explanationOperationsMenu: some View {
        BookToolbarMenuButton(title: "讲解操作") {
            explanationOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : "选择/全文讲解、文稿管理与朗读 · \(BookKeyboardShortcuts.explanationMenuSummary)")
    }

    @ViewBuilder
    private var explanationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        Button {
            viewModel.explainSelection()
        } label: {
            Text("选择讲解")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)
        .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

        Button {
            viewModel.explainFullText()
        } label: {
            Text("全文讲解")
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
            Text("新建")
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.openExplanationDocument()
        } label: {
            Text("打开")
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.saveExplanationDocument()
        } label: {
            Text("保存")
        }
        .disabled(!viewModel.hasExplanationContent)

        Button {
            viewModel.selectAllExplanation()
        } label: {
            Text("全选")
        }
        .disabled(!viewModel.hasExplanationContent)

        Button(role: .destructive) {
            viewModel.clearExplanation()
        } label: {
            Text("清空讲解")
        }
        .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

        BookToolbarMenuDivider()

        Button {
            viewModel.readExplanationAloud()
        } label: {
            Text(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读讲解")
        }
        .disabled(viewModel.isRunning || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation))
    }

    private var translationOperationsMenu: some View {
        BookToolbarMenuButton(title: "翻译操作") {
            translationOperationsMenuContent
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : "逐字/整段翻译、朗读与翻译文件管理 · \(BookKeyboardShortcuts.translationMenuSummary)")
    }

    @ViewBuilder
    private var translationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.generateLessonPlan()
        } label: {
            Text("逐字翻译")
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
            Text("整段翻译")
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
            Text(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译")
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
            Text("全选翻译")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        BookToolbarMenuDivider()

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.openLessonPlanFile()
        } label: {
            Text("打开翻译")
        }
        .disabled(viewModel.isRunning)

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.alignTranslationWithSource()
        } label: {
            Text("对齐原文")
        }
        .disabled(!viewModel.canAlignTranslationWithSource)

        Button {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.saveLessonPlan()
        } label: {
            Text("保存翻译")
        }
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button(role: .destructive) {
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.selectReadingAssistantPanel(.translation)
            viewModel.clearLessonPlan()
        } label: {
            Text("清空翻译")
        }
        .disabled(viewModel.isRunning || viewModel.lessonPlanContent.isEmpty)
    }

    private var speechOperationsMenu: some View {
        BookToolbarMenuButton(title: "朗读功能") {
            speechOperationsMenuContent
        }
        .help("原文、翻译与讲解的选中/全文朗读；朗读中请使用顶栏中部播控 · \(BookKeyboardShortcuts.speechMenuSummary)")
    }

    @ViewBuilder
    private var speechOperationsMenuContent: some View {
        Button {
            viewModel.readOriginalFullTextAloud()
        } label: {
            Text("朗读原文全文")
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.readOriginalSelectionAloud()
        } label: {
            Text("朗读原文选中")
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.effectiveSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
        )

        BookToolbarMenuDivider()

        Button {
            viewModel.readTranslationFullTextAloud()
        } label: {
            Text("朗读翻译全文")
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
            Text("朗读翻译选择")
        }
        .disabled(
            viewModel.isRunning
                || (viewModel.effectiveLessonPlanSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
        )

        BookToolbarMenuDivider()

        Button {
            viewModel.readExplanationFullTextAloud()
        } label: {
            Text("朗读讲解全文")
        }
        .disabled(
            viewModel.isRunning
                || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation)
        )

        Button {
            viewModel.readExplanationSelectionAloud()
        } label: {
            Text("朗读讲解选中")
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
        BookToolbarOverflowMenu(help: "讲解/翻译分栏与一键操作") {
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
                    Text("选择讲解")
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)
                .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

                Button {
                    viewModel.explainFullText()
                } label: {
                    Text("全文讲解")
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
                    Text("逐字翻译")
                }
                .disabled(
                    requiresBookLLM
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isRunning
                )

                Button {
                    viewModel.refineLessonPlan()
                } label: {
                    Text("整段翻译")
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
                title: "进化",
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.startEvolution()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : "执行下一条优化队列（\(BookKeyboardShortcuts.evolutionHint)）")

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
        BookToolbarOverflowMenu(help: "进化、分析与停止") {
            if includeEvolution {
                Button {
                    viewModel.startEvolution()
                } label: {
                    Text("进化")
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)
                .disabled(requiresEvolutionBackend || viewModel.isRunning)
            }

            Button {
                viewModel.analyzeOptimizations()
            } label: {
                Text("分析优化")
            }
            .disabled(requiresEvolutionBackend || viewModel.isRunning)

            if viewModel.isRunning {
                Button {
                    viewModel.stopCurrentRun()
                } label: {
                    Text("停止")
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
            .help("当前朗读：\(source.label)")
        } else {
            BookStatusPill(
                title: "朗读中",
                icon: "speaker.wave.2.fill",
                tint: BookTheme.goldSoft
            )
            .help("正在朗读")
        }
    }

    private var speechPauseResumeButton: some View {
        BookActionButton(
            title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
            isCompact: true,
            isDisabled: viewModel.isRunning
        ) {
            viewModel.toggleExplanationSpeechPause()
        }
        .help(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")
    }

    private var speechStopButton: some View {
        BookActionButton(
            title: "停止",
            isCompact: true,
            isDisabled: viewModel.isRunning
        ) {
            viewModel.stopExplanationSpeech()
        }
        .help("停止朗读")
    }

    @ViewBuilder
    private func speechPlaybackOverflowMenu(includeSource: Bool) -> some View {
        BookToolbarOverflowMenu(help: "朗读播控") {
            if includeSource, let source = viewModel.currentSpeechSource {
                BookToolbarMenuCaption(title: "当前朗读：\(source.label)")
            } else if includeSource {
                BookToolbarMenuCaption(title: "正在朗读")
            }
            if includeSource {
                BookToolbarMenuDivider()
            }

            Button {
                viewModel.toggleExplanationSpeechPause()
            } label: {
                Text(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")
            }
            .disabled(viewModel.isRunning)

            Button {
                viewModel.stopExplanationSpeech()
            } label: {
                Text("停止朗读")
            }
            .disabled(viewModel.isRunning)
        }
    }

    private var explanationPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: "选择讲解",
                isCompact: true,
                isDisabled: requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning
            ) {
                viewModel.explainSelection()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : "讲解左页选中文字（\(BookKeyboardShortcuts.explainSelectionHint)）")

            BookActionButton(
                title: "全文讲解",
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.explainFullText()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : "讲解左页全文（\(BookKeyboardShortcuts.explainFullTextHint)）")
        }
    }

    private var translationPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: "逐字翻译",
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.generateLessonPlan()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : "按左页原文生成逐字翻译，输出带对齐结构的 JSON")

            BookActionButton(
                title: "整段翻译",
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.refineLessonPlan()
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : "按左页原文生成整段翻译，输出按段落对齐的 JSON")
        }
    }

    private var evolutionPrimaryActionButtons: some View {
        Group {
            BookActionButton(
                title: "进化",
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.startEvolution()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : "执行下一条优化队列（\(BookKeyboardShortcuts.evolutionHint)）")

            BookActionButton(
                title: "分析优化",
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning
            ) {
                viewModel.analyzeOptimizations()
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : "AI 分析源码并写入优化队列")
        }
    }

    private var evolutionStopButton: some View {
        BookActionButton(
            title: "停止",
            isCompact: true
        ) {
            viewModel.stopCurrentRun()
        }
        .help("停止当前进化或分析任务")
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
            title: RightPageTab.aiEvolution.rawValue,
            isProminent: viewModel.rightPageTab == .aiEvolution,
            isCompact: true
        ) {
            viewModel.selectRightPageTab(.aiEvolution)
        }
        .help("切换到 AI 进化：分析优化队列并升级 ai-book")
    }

    @ViewBuilder
    private func utilityEvolutionOverflowMenu(includeTab: Bool) -> some View {
        BookToolbarOverflowMenu(
            help: requiresEvolutionBackend
                ? evolutionToolbarHelp
                : (viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置 · \(BookKeyboardShortcuts.evolutionMenuSummary)")
        ) {
            if includeTab {
                Button {
                    viewModel.selectRightPageTab(.aiEvolution)
                } label: {
                    Text(RightPageTab.aiEvolution.rawValue)
                }
                BookToolbarMenuDivider()
            }

            BookToolbarSubmenu(
                title: RightPageTab.aiEvolution.toolbarMenuTitle ?? RightPageTab.aiEvolution.rawValue
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
        .help(requiresEvolutionBackend ? evolutionToolbarHelp : (viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置 · \(BookKeyboardShortcuts.evolutionMenuSummary)"))
    }

    @ViewBuilder
    private var evolutionOperationsMenuContent: some View {
        evolutionConfigGuideMenuItem

        Button {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.startEvolution()
        } label: {
            Text("进化")
        }
        .bookMenuShortcut(BookKeyboardShortcuts.evolution)
        .disabled(requiresEvolutionBackend || viewModel.isRunning)

        Button {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.analyzeOptimizations()
        } label: {
            Text("分析优化")
        }
        .disabled(requiresEvolutionBackend || viewModel.isRunning)

        Button {
            viewModel.openSettings()
        } label: {
            Text("进化设置")
        }

        BookToolbarMenuDivider()

        Button {
            viewModel.saveEvolutionCommands()
        } label: {
            Text("保存进化命令")
        }
        .disabled(!viewModel.canSaveEvolutionCommands)

        Button {
            viewModel.openEvolutionCommands()
        } label: {
            Text("打开进化命令")
        }
        .disabled(!viewModel.canOpenEvolutionCommands)

        Button(role: .destructive) {
            viewModel.selectRightPageTab(.aiEvolution)
            viewModel.clearAIContext()
        } label: {
            Text("清空 AI 上下文")
        }
        .disabled(viewModel.isRunning || !viewModel.canClearAIContext)

        if viewModel.isRunning {
            BookToolbarMenuDivider()

            Button {
                viewModel.stopCurrentRun()
            } label: {
                Text("停止")
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
                    title: "双页",
                    isProminent: true,
                    isCompact: false,
                    isHovering: false
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("恢复左右双页布局")
            .keyboardShortcut(.escape, modifiers: [])

            VStack(alignment: .leading, spacing: 4) {
                Text(learningPaneFocus == .leading ? "原文全屏" : "右页全屏")
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text(learningPaneFocus == .leading ? viewModel.displayFileName : viewModel.rightPageTab.rawValue)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.chromeMuted)
                    .lineLimit(1)
            }
            .layoutPriority(-1)

            Spacer(minLength: 8)

            BookStatusPill(
                title: learningPaneFocus == .leading ? "原文 / 命令笔记" : viewModel.rightPageTab.rawValue,
                icon: learningPaneFocus == .leading ? "text.book.closed" : viewModel.rightPageTab.icon
            )
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
            Button("双页") { setLearningPaneFocus(.both) }
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
                title: "原文 / 命令笔记",
                icon: "text.book.closed",
                subtitle: viewModel.fileContent.isEmpty
                    ? "可直接输入，或 \(BookKeyboardShortcuts.newDocumentHint) 新建 / \(BookKeyboardShortcuts.openDocumentHint) 打开 .txt · \(BookKeyboardShortcuts.saveHint) 保存"
                    : viewModel.isEditingNotes
                        ? "可编辑 · 命令笔记自动保存 · \(BookKeyboardShortcuts.classicSupplementHint) 名著补充 · \(BookKeyboardShortcuts.explainSelectionHint) 选择讲解 · \(BookKeyboardShortcuts.explainFullTextHint) 全文讲解 · \(BookKeyboardShortcuts.readOriginalHint) 朗读原文"
                        : "可编辑 · \(BookKeyboardShortcuts.saveHint) 保存 · \(BookKeyboardShortcuts.classicSupplementHint) 名著补充 · \(BookKeyboardShortcuts.explainSelectionHint) 选择讲解 · \(BookKeyboardShortcuts.explainFullTextHint) 全文讲解 · \(BookKeyboardShortcuts.readOriginalHint) 朗读原文",
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
            Label("\(viewModel.fileContent.count) 字", systemImage: "character.cursor.ibeam")
            if !viewModel.effectiveSelectedText.isEmpty {
                Label("已选 \(viewModel.effectiveSelectedText.count) 字", systemImage: "highlighter")
            }
            Spacer()
            Button("全选") {
                viewModel.selectAllLeftPage()
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.leather)
            .disabled(viewModel.fileContent.isEmpty)
            .help("全选左页文本")
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
                    title: viewModel.rightPageTab.rawValue,
                    icon: viewModel.rightPageTab.icon,
                    subtitle: rightPageSubtitle,
                    paneSide: .trailing
                )
            }

            ExplanationChatView()
        }
        .overlay(alignment: .bottomTrailing) {
            BookInterface.PageCornerFold()
        }
        .bookPaperTexture()
        .bookPage(BookTheme.pageRight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var showsRightPageLabel: Bool {
        !(viewModel.rightPageTab == .readingAssistant && !isReadingChromeVisible)
    }

    private var rightPageSubtitle: String? {
        switch viewModel.rightPageTab {
        case .readingAssistant:
            return nil
        case .aiEvolution:
            let modelLabel = ModelTokenLimits.cursorModelLabel(settings.resolvedCursorModel)
            if let label = viewModel.evolutionStatusLabel {
                return "\(label) · \(modelLabel)"
            }
            return "\(viewModel.rightPageTab.pageSubtitle) · \(modelLabel)"
        }
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
        .help(isFocused ? "恢复双页" : side == .leading ? "原文占满桌面" : "右页占满桌面")
    }

    private var leftPageSaveStatus: String {
        if let message = viewModel.lastSaveMessage {
            return message
        }
        if viewModel.isEditingNotes {
            return viewModel.isDirty ? "保存中…" : "已自动保存"
        }
        return viewModel.isDirty ? "未保存" : "已保存"
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

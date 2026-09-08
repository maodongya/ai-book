import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()
            BookTheme.deskLampGlow
                .ignoresSafeArea()

            VStack(spacing: 0) {
                bookHeader
                openBook
            }
            .padding(24)
        }
        .alert("提示", isPresented: errorBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showBookSettings) {
            BookSettingsView()
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear {
            viewModel.onAppear()
        }
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
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.36), radius: 14, y: 8)
        }
        .padding(.bottom, 12)
    }

    private var brandBlock: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
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
                    .foregroundStyle(Color.white.opacity(0.74))
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

    private var toolbarActionRow: some View {
        GeometryReader { geometry in
            let dividerSpan = Self.toolbarDividerSpan
            let leftWidth = geometry.size.width * 2 / 5
            let remaining = max(0, geometry.size.width - leftWidth - dividerSpan * 2)
            let sideWidth = remaining / 2

            HStack(spacing: 0) {
                documentActionBar
                    .frame(width: leftWidth, alignment: .leading)

                toolbarSectionDivider

                readingActionBar
                    .frame(width: sideWidth, alignment: .center)

                toolbarSectionDivider

                utilityActionBar
                    .frame(width: sideWidth, alignment: .trailing)
            }
        }
        .frame(height: 24)
    }

    private static let toolbarDividerSpan: CGFloat = 21

    private var toolbarSectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 10)
    }

    private var documentActionBar: some View {
        HStack(spacing: 8) {
            BookActionButton(
                title: RightPageTab.readingAssistant.rawValue,
                icon: RightPageTab.readingAssistant.icon,
                isProminent: viewModel.rightPageTab == .readingAssistant,
                isCompact: true
            ) {
                viewModel.selectRightPageTab(.readingAssistant)
            }
            .help("切换到读书助手：讲解、朗读与文章翻译")

            BookActionButton(
                title: "book设置",
                icon: "slider.horizontal.3",
                isProminent: false,
                isCompact: true
            ) {
                viewModel.openBookSettings()
            }
            .help("配置读书助手大模型（推荐本机 Ollama）")

            BookToolbarMenuButton(title: "原文操作", icon: "folder.badge.plus") {
                Button {
                    viewModel.newDocument()
                } label: {
                    Label("新建", systemImage: "doc.badge.plus")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.openFile()
                } label: {
                    Label("打开", systemImage: "doc.text")
                }
                .disabled(viewModel.isRunning)

                Divider()

                Button {
                    viewModel.save()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.fileContent.isEmpty && !viewModel.isDirty)

                Button {
                    viewModel.saveAs()
                } label: {
                    Label("另存为", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(viewModel.fileContent.isEmpty)

                Button {
                    viewModel.selectAllLeftPage()
                } label: {
                    Label("原文全选", systemImage: "selection.pin.in.out")
                }
                .disabled(viewModel.fileContent.isEmpty)

                Divider()

                Button {
                    viewModel.supplementClassicLiterature()
                } label: {
                    Label(ClassicLiteratureSupplement.capabilityLabel, systemImage: "text.append")
                }
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)
            }
            .help("新建、打开、保存、另存为、全选与名著补充")

            BookToolbarMenuButton(title: "讲解操作", icon: "sparkles.text.clipboard") {
                Button {
                    viewModel.explainSelection()
                } label: {
                    Label("选择讲解", systemImage: "text.cursor")
                }
                .disabled(viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

                Button {
                    viewModel.explainFullText()
                } label: {
                    Label("全文讲解", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

                Divider()

                Button {
                    viewModel.newExplanationDocument()
                } label: {
                    Label("新建", systemImage: "doc.badge.plus")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.openExplanationDocument()
                } label: {
                    Label("打开", systemImage: "folder")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.saveExplanationDocument()
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.hasExplanationContent)

                Button {
                    viewModel.selectAllExplanation()
                } label: {
                    Label("全选", systemImage: "selection.pin.in.out")
                }
                .disabled(!viewModel.hasExplanationContent)

                Button(role: .destructive) {
                    viewModel.clearExplanation()
                } label: {
                    Label("清空讲解", systemImage: "trash")
                }
                .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

                Divider()

                Button {
                    viewModel.readExplanationAloud()
                } label: {
                    Label(
                        viewModel.isSpeakingExplanation ? "停止朗读" : "朗读讲解",
                        systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .disabled(viewModel.isRunning || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation))
            }
            .help("选择/全文讲解、文稿管理与朗读")

            BookToolbarMenuButton(title: "翻译操作", icon: "character.book.closed") {
                Button {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.generateLessonPlan()
                } label: {
                    Label("逐字翻译", systemImage: "text.magnifyingglass")
                }
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

                Button {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.refineLessonPlan()
                } label: {
                    Label("整段翻译", systemImage: "paragraphsign")
                }
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

                Button {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.readLessonPlanAloud()
                } label: {
                    Label(
                        viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译",
                        systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button {
                    viewModel.selectAllRightPage()
                } label: {
                    Label("全选翻译", systemImage: "selection.pin.in.out")
                }
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Divider()

                Button {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.openLessonPlanFile()
                } label: {
                    Label("打开翻译", systemImage: "folder")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.saveLessonPlan()
                } label: {
                    Label("保存翻译", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    viewModel.selectRightPageTab(.readingAssistant)
                    viewModel.clearLessonPlan()
                } label: {
                    Label("清空翻译", systemImage: "trash")
                }
                .disabled(viewModel.isRunning || viewModel.lessonPlanContent.isEmpty)

            }
            .help("逐字/整段翻译、朗读与翻译文件管理")

            BookToolbarMenuButton(title: "朗读功能", icon: "speaker.wave.2.fill") {
                Button {
                    viewModel.readOriginalFullTextAloud()
                } label: {
                    Label("朗读原文全文", systemImage: "text.book.closed")
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button {
                    viewModel.readOriginalSelectionAloud()
                } label: {
                    Label("朗读原文选中", systemImage: "text.cursor")
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.effectiveSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
                )

                Divider()

                Button {
                    viewModel.readTranslationFullTextAloud()
                } label: {
                    Label("朗读翻译全文", systemImage: "character.book.closed")
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button {
                    viewModel.readTranslationSelectionAloud()
                } label: {
                    Label("朗读翻译选择", systemImage: "selection.pin.in.out")
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.effectiveLessonPlanSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
                )

                Divider()

                Button {
                    viewModel.readExplanationFullTextAloud()
                } label: {
                    Label("朗读讲解全文", systemImage: "sparkles.text.clipboard")
                }
                .disabled(
                    viewModel.isRunning
                        || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation)
                )

                Button {
                    viewModel.readExplanationSelectionAloud()
                } label: {
                    Label("朗读讲解选中", systemImage: "text.quote")
                }
                .disabled(
                    viewModel.isRunning
                        || (viewModel.effectiveExplanationPanelSelectedText.isEmpty && !viewModel.isSpeakingExplanation)
                )
            }
            .help("原文、翻译与讲解的选中/全文朗读；朗读中请使用顶栏中部播控")
        }
    }

    private var readingActionBar: some View {
        HStack(spacing: 8) {
            if viewModel.isSpeakingExplanation {
                unifiedSpeechPlaybackBar
            } else {
                readingPrimaryActionButtons
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.18), value: viewModel.isSpeakingExplanation)
    }

    private var readingPrimaryActionButtons: some View {
        HStack(spacing: 8) {
            BookActionButton(
                title: "选择讲解",
                icon: "text.cursor",
                isCompact: true,
                isDisabled: viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning
            ) {
                viewModel.explainSelection()
            }
            .help("讲解左页选中文字（⌘R）")

            BookActionButton(
                title: "全文讲解",
                icon: "doc.text.magnifyingglass",
                isCompact: true,
                isDisabled: viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.explainFullText()
            }
            .help("讲解左页全文（⌘⇧R）")

            BookActionButton(
                title: "逐字翻译",
                icon: "text.magnifyingglass",
                isCompact: true,
                isDisabled: viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.generateLessonPlan()
            }
            .help("按左页原文生成逐字翻译表")

            BookActionButton(
                title: "整段翻译",
                icon: "paragraphsign",
                isCompact: true,
                isDisabled: viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.isRunning
            ) {
                viewModel.refineLessonPlan()
            }
            .help("按左页原文生成整段翻译")
        }
    }

    private var unifiedSpeechPlaybackBar: some View {
        HStack(spacing: 8) {
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

            BookActionButton(
                title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                icon: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill",
                isCompact: true,
                isDisabled: viewModel.isRunning
            ) {
                viewModel.toggleExplanationSpeechPause()
            }
            .help(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")

            BookActionButton(
                title: "停止",
                icon: "stop.fill",
                isCompact: true,
                isDisabled: viewModel.isRunning
            ) {
                viewModel.stopExplanationSpeech()
            }
            .help("停止朗读")
        }
    }

    private var utilityActionBar: some View {
        HStack(spacing: 8) {
            BookActionButton(
                title: RightPageTab.aiEvolution.rawValue,
                icon: RightPageTab.aiEvolution.icon,
                isProminent: viewModel.rightPageTab == .aiEvolution,
                isCompact: true
            ) {
                viewModel.selectRightPageTab(.aiEvolution)
            }
            .help("切换到 AI 进化：分析优化队列并升级 ai-book")

            BookToolbarMenuButton(title: "AI进化", icon: "arrow.triangle.2.circlepath") {
                Button {
                    viewModel.selectRightPageTab(.aiEvolution)
                    viewModel.startEvolution()
                } label: {
                    Label("进化", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.selectRightPageTab(.aiEvolution)
                    viewModel.analyzeOptimizations()
                } label: {
                    Label("分析优化", systemImage: "magnifyingglass")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.openSettings()
                } label: {
                    Label("进化设置", systemImage: "gearshape")
                }

                Divider()

                Button {
                    viewModel.saveEvolutionCommands()
                } label: {
                    Label("保存进化命令", systemImage: "square.and.arrow.down")
                }
                .disabled(!viewModel.canSaveEvolutionCommands)

                Button {
                    viewModel.openEvolutionCommands()
                } label: {
                    Label("打开进化命令", systemImage: "folder")
                }
                .disabled(!viewModel.canOpenEvolutionCommands)

                Button(role: .destructive) {
                    viewModel.selectRightPageTab(.aiEvolution)
                    viewModel.clearAIContext()
                } label: {
                    Label("清空 AI 上下文", systemImage: "cpu")
                }
                .disabled(viewModel.isRunning || !viewModel.canClearAIContext)

                if viewModel.isRunning {
                    Divider()

                    Button {
                        viewModel.stopCurrentRun()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                }
            }
            .help(viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置")
        }
    }

    private var openBook: some View {
        GeometryReader { geometry in
            BookInterface.SpreadShell {
                HStack(spacing: 0) {
                    leftPage
                        .frame(width: (geometry.size.width - 34) / 2)

                    ZStack(alignment: .top) {
                        bookSpine
                        BookInterface.BookmarkRibbon()
                    }

                    rightPage
                        .frame(width: (geometry.size.width - 34) / 2)
                }
            }
        }
    }

    private var leftPage: some View {
        VStack(spacing: 0) {
            pageLabel(
                title: "原文 / 命令笔记",
                icon: "text.book.closed",
                subtitle: viewModel.fileContent.isEmpty
                    ? "可直接输入，或 ⌘N 新建 / ⌘O 打开 .txt · ⌘S 保存"
                    : viewModel.isEditingNotes
                        ? "可编辑 · 命令笔记自动保存 · ⌘⇧C 名著补充 · ⌘R 选择讲解 · ⌘⇧R 全文讲解 · ⌘⌥R 朗读原文"
                        : "可编辑 · ⌘S 保存 · ⌘⇧C 名著补充 · ⌘R 选择讲解 · ⌘⇧R 全文讲解 · ⌘⌥R 朗读原文"
            )

            ZStack {
                SelectableTextView(
                    text: $viewModel.fileContent,
                    onSelectionChange: { selection, range in
                        viewModel.updateSelection(selection, range: range)
                    },
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
            pageLabel(
                title: viewModel.rightPageTab.rawValue,
                icon: viewModel.rightPageTab.icon,
                subtitle: rightPageSubtitle
            )

            ExplanationChatView()
        }
        .overlay(alignment: .bottomTrailing) {
            BookInterface.PageCornerFold()
        }
        .bookPaperTexture()
        .bookPage(BookTheme.pageRight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var rightPageSubtitle: String {
        switch viewModel.rightPageTab {
        case .readingAssistant:
            return "\(viewModel.readingAssistantPanel.rawValue) · \(settings.bookLLMDisplayLabel)"
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

    private func pageLabel(title: String, icon: String, subtitle: String? = nil) -> some View {
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

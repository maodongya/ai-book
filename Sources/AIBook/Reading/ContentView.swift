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
                    if settings.explanationSource == .llm {
                        BookStatusPill(title: LLMConnector.capabilityLabel, icon: "sparkles", tint: Color.white.opacity(0.52))
                            .help(LLMConnector.supportedSummary)
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

    /// 标签栏右侧：当前模式、未保存、大模型 / Cursor 切换。
    private var headerModeAndSourceControls: some View {
        HStack(spacing: 8) {
            BookStatusPill(
                title: settings.explanationSource == .llm && settings.isLLMConfigured
                    ? settings.llmDisplayLabel
                    : settings.explanationSource.rawValue,
                icon: settings.explanationSource == .cursor ? "cursorarrow.rays" : "cpu",
                tint: Color.white.opacity(0.66)
            )

            if viewModel.isDirty {
                BookStatusPill(title: "未保存", icon: "circle.fill", tint: Color.orange.opacity(0.95))
                    .help("有未保存的修改")
            }

            ForEach(ExplanationSource.allCases) { source in
                BookActionButton(
                    title: source.rawValue,
                    icon: source == .cursor ? "cursorarrow.rays" : "cpu",
                    isProminent: settings.explanationSource == source,
                    isCompact: true,
                    isDisabled: viewModel.isRunning
                ) {
                    viewModel.selectRightPageTab(.aiEvolution)
                    settings.explanationSource = source
                }
                .help("进化与追问使用 \(source.rawValue)")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toolbarActionRow: some View {
        HStack(spacing: 0) {
            documentActionBar
                .frame(maxWidth: .infinity, alignment: .leading)

            toolbarSectionDivider

            readingActionBar
                .frame(maxWidth: .infinity, alignment: .center)

            toolbarSectionDivider

            utilityActionBar
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 24)
    }

    private var toolbarSectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 10)
    }

    private var documentActionBar: some View {
        HStack(spacing: 8) {
            BookToolbarMenuButton(title: "核心功能", icon: "folder.badge.plus") {
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

                Divider()

                Button {
                    viewModel.supplementClassicLiterature()
                } label: {
                    Label(ClassicLiteratureSupplement.capabilityLabel, systemImage: "text.append")
                }
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)
            }
            .help("新建、打开、保存、另存为与名著补充")
        }
    }

    private var readingActionBar: some View {
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

            if viewModel.isRunning {
                BookActionButton(title: "停止", icon: "stop.fill", isCompact: true) {
                    viewModel.stopCurrentRun()
                }
                .help("停止讲解生成")
            } else if viewModel.isSpeakingExplanation {
                BookActionButton(
                    title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                    icon: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill",
                    isCompact: true
                ) {
                    viewModel.toggleExplanationSpeechPause()
                }
                .help(viewModel.isExplanationSpeechPaused ? "继续朗读讲解" : "暂停朗读讲解")

                BookActionButton(title: "停止", icon: "stop.fill", isCompact: true) {
                    viewModel.stopExplanationSpeech()
                }
                .help("停止朗读讲解")
            }

            BookToolbarMenuButton {
                Button {
                    viewModel.explainSelection()
                } label: {
                    Label("讲解", systemImage: "sparkles.text.clipboard")
                }
                .disabled(viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)

                Button {
                    viewModel.selectAllLeftPage()
                } label: {
                    Label("全选左页", systemImage: "selection.pin.in.out")
                }
                .disabled(viewModel.fileContent.isEmpty)

                Button {
                    viewModel.readSelectionAloud()
                } label: {
                    Label(
                        viewModel.isSpeakingExplanation ? "停止朗读" : "朗读",
                        systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .disabled(viewModel.isRunning || (!viewModel.canReadAloud && !viewModel.isSpeakingExplanation))

                Divider()

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

                if viewModel.isRunning || viewModel.isSpeakingExplanation {
                    Divider()

                    Button {
                        viewModel.stopCurrentRun()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                }
            }
            .help("讲解、朗读与翻译")
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
            .help("切换到 AI 进化：按左页编号命令升级 ai-book")

            BookToolbarMenuButton {
                Button {
                    viewModel.startEvolution()
                } label: {
                    Label("进化", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isRunning)

                Button {
                    viewModel.openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                if viewModel.isRunning {
                    Divider()

                    Button {
                        viewModel.stopCurrentRun()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                }
            }
            .help(viewModel.evolutionStatusLabel ?? "进化、设置与停止当前任务")
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
                        ? "可编辑 · 命令笔记自动保存 · ⌘⇧C 名著补充 · ⌘R 讲解 · ⌘⌥R 朗读"
                        : "可编辑 · ⌘S 保存 · ⌘⇧C 名著补充 · ⌘R 讲解 · ⌘⌥R 朗读"
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
            if viewModel.selectedText.isEmpty {
                return "\(viewModel.rightPageTab.pageSubtitle) · \(settings.explanationSource.rawValue)"
            }
            return "已选中 \(viewModel.selectedText.count) 字 · \(settings.explanationSource.rawValue)"
        case .aiEvolution:
            if let label = viewModel.evolutionStatusLabel {
                return "\(label) · \(settings.explanationSource.rawValue)"
            }
            return "\(viewModel.rightPageTab.pageSubtitle) · \(settings.explanationSource.rawValue)"
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

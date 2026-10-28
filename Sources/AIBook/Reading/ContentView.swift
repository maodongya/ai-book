import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 根界面：书桌、摊开的书、目录和右页助手。
struct ContentView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel  // 双页状态
    @ObservedObject private var settings = AppSettings.shared  // 语言和模型标签
    @ObservedObject private var styleManager = BookStyleManager.shared  // 字体主题
    @State private var learningPaneFocus: LearningPaneFocus = .both  // 学习模式：双栏/左全屏/右全屏
    @StateObject private var operationAssistant = OperationAssistantModel()  // 按住说话的操作助手

    private let learningSpineWidth: CGFloat = 34  // 和学习摊书脊同宽

    /// 书桌：左页原文、右页学习区、工具栏。
    var body: some View {
        let _ = settings.localizationRevision  // 语言变了整页重算文案
        let _ = bindOperationTurn()  // 松开麦克风时用当前焦点和会话
        ZStack {
            BookTheme.deskGradient  // 桌面底
                .ignoresSafeArea()  // 铺满
            BookTheme.deskLampGlow  // 台灯光
                .ignoresSafeArea()  // 铺满

            if showsLearningWorkspace {  // 学习双栏才画书桌，阅读模式由 overlay 盖
                VStack(spacing: 0) {  // 顶栏+摊开的书
                    bookHeader  // 皮条工具栏
                        .bookStyleRefreshing()  // 主题变了刷一次
                    openBook  // 左右页
                }
                .padding(24)  // 桌边
            }
        }
        .alert(BookL10n.string("alert.title.hint"), isPresented: errorBinding) {  // errorMessage 非空就弹
            Button(BookL10n.string("action.ok"), role: .cancel) {}  // 只确认
        } message: {
            Text(viewModel.errorMessage ?? "")  // 空串防守
        }
        .sheet(isPresented: $viewModel.showSettings) {  // 通用设置
            SettingsView()  // 进化/Cursor 等
                .environmentObject(viewModel)  // 共用 VM
                .bookStyleEnvironment(styleManager)  // 主题
                .bookLocalizationEnvironment()  // 语言
        }
        .sheet(isPresented: $viewModel.showBookSettings) {  // 本书设置
            BookSettingsView()  // LLM/译文语
                .environmentObject(viewModel)  // 共用 VM
                .bookStyleEnvironment(styleManager)  // 主题
                .bookLocalizationEnvironment()  // 语言
        }
        .sheet(isPresented: $viewModel.showUserManual) {  // 说明书
            BookUserManualView()  // 不依赖 VM
                .bookStyleEnvironment(styleManager)  // 主题
                .bookLocalizationEnvironment()  // 语言
        }
        .sheet(isPresented: Binding(  // 目录浏览器
            get: { viewModel.document.showDirectoryBrowser },  // 文档会话开关
            set: { viewModel.document.showDirectoryBrowser = $0 }  // 关 sheet 写回
        )) {
            directoryBrowserSheet  // 多根目录
                .bookStyleEnvironment(styleManager)  // 主题
                .bookLocalizationEnvironment()  // 语言
        }
        .sheet(isPresented: Binding(
            get: { viewModel.translation.showsTranslationProgressSheet },
            set: { presented in
                if !presented { viewModel.translation.endTranslationProgress() }
            }
        )) {
            TranslationProgressSheet()
                .environmentObject(viewModel)
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.assistant.showsExplanationProgressSheet },
            set: { presented in
                if !presented { viewModel.assistant.endExplanationProgress() }
            }
        )) {
            ExplanationProgressSheet()
                .environmentObject(viewModel)
                .bookStyleEnvironment(styleManager)
                .bookLocalizationEnvironment()
        }
        .frame(minWidth: 960, minHeight: 640)  // 双页最小
        .animation(.easeOut(duration: 0.2), value: styleManager.presetID)  // 换主题
        .animation(.easeOut(duration: 0.2), value: learningPaneFocus)  // 切全屏栏
        .onAppear {
            viewModel.onAppear()  // 自动进化若需要就串
            operationAssistant.installKeys()  // Option+空格按住说话
        }
        .onDisappear {
            operationAssistant.removeKeys()  // 离开窗口不再听按键
        }
        .alert(BookL10n.string("operation.confirm.title"), isPresented: $operationAssistant.showsConfirm) {
            Button(BookL10n.string("action.ok")) { operationAssistant.resolveConfirm(true) }  // 继续这一步
            Button(BookL10n.string("action.close"), role: .cancel) { operationAssistant.resolveConfirm(false) }  // 停掉后面的步骤
        } message: {
            Text(operationAssistant.confirmMessage)  // 听到的话和操作名
        }
        .onChange(of: settings.appLanguage) { _ in
            viewModel.document.activateBundledLanguagesForCurrentSettings()
        }
        .onChange(of: viewModel.mode.experienceMode) { mode in
            if mode == .reading, learningPaneFocus != .both {  // 进阅读前先收回全屏栏
                setLearningPaneFocus(.both)  // 避免回来还是单栏
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            if learningPaneFocus != .both {  // 退出系统全屏时收回
                learningPaneFocus = .both  // 双栏
            }
        }
        .background(learningModeKeyboardShortcuts)  // 隐形快捷键
        .overlay {
            if showsLearningPaneFullscreen {  // 学习单栏全屏
                learningPaneFullscreenOverlay  // 只画左或右
                    .bookStyleEnvironment(styleManager)  // 主题
                    .transition(.opacity)  // 淡入
                    .zIndex(1)  // 盖住书桌
            }
        }
        .overlay {
            if viewModel.mode.experienceMode == .reading {  // 阅读里 Esc 回学习
                ReadingSpreadView()  // 自己的顶栏和摊
                    .bookStyleEnvironment(styleManager)  // 主题
                    .transition(.opacity)  // 淡入
                    .zIndex(2)  // 盖过单栏 overlay
            }
        }
        .overlay(alignment: .top) {
            if viewModel.mode.experienceMode == .reading, operationAssistant.showsStatus {  // 阅读模式没有学习顶栏
                OperationStatusLine(model: operationAssistant)  // 快捷键说话时仍能看见状态
                    .padding(.top, 12)
                    .zIndex(3)
            }
        }
    }

    /// 把当前窗口状态交给操作助手。每次刷新都换一份，避免焦点过期。
    private func bindOperationTurn() -> Bool {
        operationAssistant.makeTurn = {
            OperationTurn(
                snapshot: OperationSessionBridge.snapshot(viewModel: viewModel, paneFocus: learningPaneFocus),
                state: OperationSessionBridge.runtimeState(viewModel: viewModel),
                client: BookOperationClient(llmService: viewModel.llmService, cursorService: viewModel.cursorService),
                perform: { action in
                    OperationSessionBridge.perform(
                        action,
                        viewModel: viewModel,
                        setPaneFocus: { learningPaneFocus = $0 },  // 双页/左全屏/右全屏在界面上
                        toggleReadingMode: {
                            viewModel.mode.toggleReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)
                        }
                    )
                }
            )
        }
        return true  // 给 body 里的 let _ 用，避免这句被当成没结果
    }

    /// 右页学习区展开（非全屏沉浸）时为 true。
    private var showsLearningWorkspace: Bool {
        viewModel.mode.experienceMode == .learning && learningPaneFocus == .both  // 双栏书桌
    }

    /// 学习区占满窗口、藏左页。
    private var showsLearningPaneFullscreen: Bool {
        viewModel.mode.experienceMode == .learning && learningPaneFocus != .both  // 左或右全屏
    }

    /// 学习模式快捷键，不占布局。
    private var learningModeKeyboardShortcuts: some View {
        Group {
            if viewModel.mode.experienceMode == .learning {  // 学习才绑 1/2/3
                Button(BookL10n.string("layout.spread")) { setLearningPaneFocus(.both) }  // ⌘⌥1 双栏
                    .keyboardShortcut("1", modifiers: [.command, .option])  // 和阅读双页同一套
                Button(BookL10n.string("layout.leftFullscreen")) { setLearningPaneFocus(.leading) }  // ⌘⌥2 左页满
                    .keyboardShortcut("2", modifiers: [.command, .option])  // 阅读里 2 是单页
                Button(BookL10n.string("layout.rightFullscreen")) { setLearningPaneFocus(.trailing) }  // ⌘⌥3 右页满
                    .keyboardShortcut("3", modifiers: [.command, .option])  // 学习独有
            }
            if viewModel.mode.canEnterReadingMode, viewModel.mode.experienceMode == .learning {  // 有原文才能进阅读
                Button(BookL10n.string("mode.reading")) {
                    viewModel.mode.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)  // 先按默认尺寸分页
                }
                .keyboardShortcut(BookKeyboardShortcuts.readingMode)  // 再按退出
            }
            if viewModel.mode.experienceMode == .reading {  // 阅读里 Esc 回学习
                Button(BookL10n.string("mode.learning")) {
                    viewModel.mode.exitReadingMode()  // 滚到对应原文
                }
                .keyboardShortcut(.escape, modifiers: [])  // 无修饰
                Button(BookL10n.string("mode.exitReading")) {  // 和进入同一快捷键当开关
                    viewModel.mode.exitReadingMode()  // 滚到对应原文
                }
                .keyboardShortcut(BookKeyboardShortcuts.readingMode)  // 再按退出
            }
        }
        .opacity(0)  // 不可见
        .frame(width: 0, height: 0)  // 不占位
        .allowsHitTesting(false)  // 不挡
        .accessibilityHidden(true)  // 不进辅助
    }

    /// 顶栏品牌和 LLM/进化配置入口。
    private var bookHeader: some View {
        VStack(spacing: 8) {  // 品牌+动作
            brandBlock  // 名字、模型、文件

            Divider()  // 皮条内部分隔
                .overlay(Color.white.opacity(0.12))  // 浅线

            toolbarActionRow  // 打开/保存/助手按钮
        }
        .padding(.horizontal, 18)  // 皮条
        .padding(.vertical, 10)  // 略扁
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)  // 顶栏皮
                .fill(BookTheme.leatherGradient)  // 皮色
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)  // 顶栏皮
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)  // 细边
                }
                .shadow(color: .black.opacity(0.36), radius: 14, y: 8)  // 浮在桌上
        }
        .padding(.bottom, 12)  // 和书分开
    }

    /// 产品名和 tagline。
    private var brandBlock: some View {
        HStack(spacing: 10) {  // 图标+文案
            ZStack {
                Circle()  // 书标底
                    .fill(BookTheme.chromeOverlay.opacity(0.08))  // 淡
                    .frame(width: 34, height: 34)  // 和小书标齐
                Image(systemName: "book.closed.fill")  // 合着的书
                    .font(.system(size: 18))  // 中
                    .foregroundStyle(BookTheme.goldSoft)  // 金字
            }

            VStack(alignment: .leading, spacing: 3) {  // 名+文件
                HStack(alignment: .center, spacing: 6) {  // 名和状态pill
                    Text(AIBookProduct.displayName)  // 产品名
                        .font(BookTheme.titleFont)  // 标题
                        .foregroundStyle(BookTheme.goldSoft)  // 金字
                    if viewModel.rightPageTab == .readingAssistant {  // 助手页看病书模型
                        BookStatusPill(  // 配置状态
                            title: settings.isBookLLMConfigured ? settings.bookLLMDisplayLabel : BookL10n.string("status.bookLLM.unconfigured"),  // 没配就红
                            icon: "book.closed.fill",  // 书
                            tint: Color.white.opacity(0.52)  // 浅
                        )
                        .help(BookL10n.string("help.bookLLMSettings"))  // 点设置
                    } else if viewModel.rightPageTab == .aiEvolution {  // 进化页看 Cursor
                        BookStatusPill(  // 配置状态
                            title: settings.isCursorRunnable  // 桥+Key 齐才算可跑
                                ? ModelTokenLimits.cursorModelLabel(settings.resolvedCursorModel)  // 当前模型名
                                : BookL10n.string("status.cursor.notReady"),  // 没配
                            icon: "cursorarrow.rays",  // Cursor
                            tint: Color.white.opacity(0.66)  // 略亮
                        )
                        .help(BookL10n.string("help.evolutionCursorModel"))  // 进化设置
                    }

                    Spacer(minLength: 12)  // 模式钮推右

                    headerModeAndSourceControls  // 学习/阅读、来源
                }

                Text(viewModel.document.displayFileName)  // 带脏点
                    .font(BookTheme.captionFont)  // 小字
                    .foregroundStyle(BookTheme.chromeMuted)  // 弱
                    .lineLimit(1)  // 太长截
            }
            .frame(maxWidth: .infinity, alignment: .leading)  // 占满品牌行
        }
    }

    /// 标签栏右侧：当前模式与对应模型摘要。
    private var headerModeAndSourceControls: some View {
        HStack(spacing: 8) {  // 脏标记
            if viewModel.document.isDirty {  // 未保存才露橙点
                BookStatusPill(title: BookL10n.string("status.unsaved"), icon: "circle.fill", tint: Color.orange.opacity(0.95))  // 橙点
                    .help(BookL10n.string("help.unsavedChanges"))  // 悬停说明
            }
            OperationMicButton(model: operationAssistant)  // 按住说话
            OperationStatusLine(model: operationAssistant)  // 听到的话和正在做的操作
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 书内 LLM 未配好时的工具栏提示。
    private var bookLLMToolbarHelp: String {
        AppGuard.bookLLMErrorMessage(for: settings)  // 缺 Key 的具体原因
            ?? BookL10n.string("help.configureBookLLM")  // 已配则普通帮助
    }

    /// 进化后端未就绪时的工具栏提示。
    private var evolutionToolbarHelp: String {
        AppGuard.evolutionErrorMessage(for: settings)  // Cursor/源码
            ?? (viewModel.evolution.evolutionStatusLabel ?? BookL10n.string("help.evolutionDefault"))  // 队列状态或默认
    }

    @ViewBuilder
    /// 打开书内 LLM 配置指南。
    private var bookLLMConfigGuideMenuItem: some View {
        if !settings.isBookLLMConfigured {  // 没配先指路
            Button {
                viewModel.openBookSettings()  // 先切助手再 sheet
            } label: {
                Text(BookL10n.string("guide.bookLLMSetup"))  // 引导
            }
            BookToolbarMenuDivider()  // 和正式项隔开
        }
    }

    @ViewBuilder
    /// 打开进化后端配置指南。
    private var evolutionConfigGuideMenuItem: some View {
        if !settings.isCursorRunnable {  // 桥或 Key 缺
            Button {
                viewModel.openSettings()  // 进化设置
            } label: {
                Text(BookL10n.string("guide.cursorSetup"))  // 引导
            }
            BookToolbarMenuDivider()  // 和正式项隔开
        }
    }

    /// 书内 LLM 还没配好，相关按钮先引导去配置。
    private var requiresBookLLM: Bool { !settings.isBookLLMConfigured }

    /// Cursor 进化跑不起来，相关按钮先引导去配置。
    private var requiresEvolutionBackend: Bool { !settings.isCursorRunnable }

    /// 当前工具栏按阅读而不是进化来排。
    private var isReadingToolbarContext: Bool {
        viewModel.rightPageTab == .readingAssistant  // 左栏菜单跟助手走
    }

    /// 按总宽切左/中/右三栏，窄窗压缩中栏。
    private func toolbarColumnWidths(totalWidth: CGFloat) -> (left: CGFloat, center: CGFloat, right: CGFloat) {
        let dividerSpan = Self.toolbarDividerSpan  // 两条竖线占的宽
        let dividers = dividerSpan * 2  // 左右各一条
        switch viewModel.rightPageTab {  // 助手左栏宽，进化中栏宽
        case .readingAssistant:  // 文档操作多
            let left = totalWidth * 2 / 5  // 左 40%
            let remaining = max(0, totalWidth - left - dividers)  // 扣竖线
            let side = remaining / 2  // 中右均分
            return (left, side, side)  // 左大
        case .aiEvolution:  // 中间进化按钮多
            let left = totalWidth / 5  // 文档缩
            let right = totalWidth / 5  // 工具缩
            let center = max(0, totalWidth - left - right - dividers)  // 中间吃剩下
            return (left, center, right)  // 中大
        }
    }

    /// 顶栏主操作一行。
    private var toolbarActionRow: some View {
        GeometryReader { geometry in  // 量工具栏宽
            let widths = toolbarColumnWidths(totalWidth: geometry.size.width)  // 按 Tab 切

            HStack(spacing: 0) {  // 三栏+两条竖线
                documentActionBar  // 打开/讲解/译文
                    .frame(width: widths.left, alignment: .leading)  // 左齐

                toolbarSectionDivider  // 竖线

                readingActionBar  // 中间：翻译或进化
                    .frame(width: widths.center, alignment: .center)  // 居中

                toolbarSectionDivider  // 竖线

                utilityActionBar  // 说明书/设置
                    .frame(width: widths.right, alignment: .trailing)  // 右齐
            }
        }
        .frame(height: 24)  // 一行钮
        .animation(.easeOut(duration: 0.2), value: viewModel.rightPageTab)  // 切 Tab 栏宽
        .animation(.easeOut(duration: 0.2), value: viewModel.assistant.readingAssistantPanel)  // 讲解/译文菜单换
    }

    private static let toolbarDividerSpan: CGFloat = 21  // 1+10+10

    /// 工具栏分段细线。
    private var toolbarSectionDivider: some View {
        Rectangle()  // 竖线
            .fill(BookTheme.chromeOverlay.opacity(0.14))  // 淡
            .frame(width: 1, height: 20)  // 略矮于行
            .padding(.horizontal, 10)  // 左右各 10
    }

    /// 打开/保存/目录，随宽度换三档。
    private var documentActionBar: some View {
        BookToolbarOverflowRow {  // 宽→全，窄→压，再窄→溢出
            documentActionBarFull  // 全套
        } compact: {
            documentActionBarCompact  // 收阅读/设置
        } minimal: {
            documentActionBarMinimal  // 只留 Tab+溢出
        }
    }

    /// 文档操作完整按钮。
    private var documentActionBarFull: some View {
        HStack(spacing: 8) {  // 脏标记
            readingAssistantTabButton  // 切助手页
            readingModeToolbarButton  // 进沉浸阅读
            if isReadingToolbarContext {  // 进化页不塞讲解
                bookSettingsToolbarButton  // 本书 LLM
            }
            documentOperationsMenu  // 新/开/存
            if isReadingToolbarContext, viewModel.assistant.readingAssistantPanel == .explanation {  // 在讲解栏才露讲解菜单
                explanationOperationsMenu  // 讲选区/全文
            }
            if isReadingToolbarContext, viewModel.assistant.readingAssistantPanel == .translation {  // 在译文栏
                translationOperationsMenu  // 出译文/对齐
            }
            if isReadingToolbarContext {  // 进化页不塞讲解
                speechOperationsMenu  // 各来源朗读
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 文档操作缩成图标。
    private var documentActionBarCompact: some View {
        HStack(spacing: 8) {  // 脏标记
            readingAssistantTabButton  // 切助手页
            documentOperationsMenu  // 新/开/存
            if isReadingToolbarContext, viewModel.assistant.readingAssistantPanel == .explanation {  // 在讲解栏才露讲解菜单
                explanationOperationsMenu  // 讲选区/全文
            } else if isReadingToolbarContext, viewModel.assistant.readingAssistantPanel == .translation {
                translationOperationsMenu  // 出译文/对齐
            }
            if isReadingToolbarContext {  // 进化页不塞讲解
                documentToolbarOverflowMenu(includeDocumentMenu: false)  // 文档菜单已在外面
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 文档操作收进菜单。
    private var documentActionBarMinimal: some View {
        HStack(spacing: 8) {  // 脏标记
            readingAssistantTabButton  // 切助手页
            documentToolbarOverflowMenu(includeDocumentMenu: true)  // 文档也进溢出
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 切到读书助手右页。
    private var readingAssistantTabButton: some View {
        BookActionButton(  // 胶囊钮
            title: RightPageTab.readingAssistant.localizedTitle,  // 「读书助手」
            isProminent: viewModel.rightPageTab == .readingAssistant,  // 当前页加高亮
            isCompact: true  // 工具栏矮
        ) {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
        }
        .help(BookL10n.string("help.switchReadingAssistant"))  // 提示
    }

    /// 进沉浸阅读。
    private var readingModeToolbarButton: some View {
        BookActionButton(  // 胶囊钮
            title: BookL10n.string("mode.reading"),  // 「阅读」
            isProminent: false,  // 不是当前模式
            isCompact: true  // 工具栏矮
        ) {
            viewModel.mode.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)  // 先按默认尺寸分页
        }
        .disabled(!viewModel.mode.canEnterReadingMode || viewModel.isRunning)  // 没原文或在跑
        .help(BookL10n.format("help.enterReadingMode", BookKeyboardShortcuts.readingModeHint))  // 带快捷键
    }

    /// 打开书籍设置。
    private var bookSettingsToolbarButton: some View {
        BookActionButton(  // 胶囊钮
            title: BookL10n.string("settings.book"),  // 「本书设置」
            isProminent: false,  // 不是当前模式
            isCompact: true  // 工具栏矮
        ) {
            viewModel.openBookSettings()  // 先切助手再 sheet
        }
        .help(BookL10n.string("help.configureBookLLM"))  // LLM
    }

    @ViewBuilder
    /// 文档菜单里的打开/保存/目录项。
    private var documentOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem  // 没配先插引导

        Button {
            viewModel.document.newDocument()  // 空档，脏了先问
        } label: {
            Text(BookL10n.string("action.new"))  // 新建
        }
        .bookMenuShortcut(BookKeyboardShortcuts.newDocument)  // 菜单快捷键
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.document.openFile()  // 单文件
        } label: {
            Text(BookL10n.string("action.open"))  // 打开
        }
        .bookMenuShortcut(BookKeyboardShortcuts.openDocument)  // 开档
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.document.openDirectory()  // 目录浮层
        } label: {
            Text(BookL10n.string("action.openDirectoryShort"))  // 开目录
        }
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.mode.enterReadingMode(pageContentSize: ReadingSpreadView.defaultPageContentSize)  // 先按默认尺寸分页
        } label: {
            Text(BookL10n.string("mode.reading"))  // 进阅读
        }
        .bookMenuShortcut(BookKeyboardShortcuts.readingMode)  // 和顶栏同一键
        .disabled(!viewModel.mode.canEnterReadingMode || viewModel.isRunning)  // 没原文或在跑

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.document.save()  // 有路径写文件，否则笔记
        } label: {
            Text(BookL10n.string("action.save"))  // 存讲解
        }
        .bookMenuShortcut(BookKeyboardShortcuts.save)  // 存
        .disabled(viewModel.fileContent.isEmpty && !viewModel.document.isDirty)  // 空且不脏

        Button {
            viewModel.document.saveAs()  // 另存面板
        } label: {
            Text(BookL10n.string("action.saveAs"))  // 另存
        }
        .bookMenuShortcut(BookKeyboardShortcuts.saveAs)  // 另存键
        .disabled(viewModel.fileContent.isEmpty)  // 空页

        Button {
            viewModel.document.saveAsAIBook()
        } label: {
            Text(BookL10n.string("action.saveAIBook"))
        }
        .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

        Button {
            viewModel.document.selectAllLeftPage()  // 发全选信号
        } label: {
            Text(BookL10n.string("action.selectAllSource"))  // 全选原文
        }
        .bookMenuShortcut(BookKeyboardShortcuts.selectAllLeftPage)  // 全选
        .disabled(viewModel.fileContent.isEmpty)  // 空页

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.assistant.supplementClassicLiterature()  // 补全写回左页
        } label: {
            Text(ClassicLiteratureSupplement.capabilityLabel)  // 能力名
        }
        .bookMenuShortcut(BookKeyboardShortcuts.classicSupplement)  // 补全键
        .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning || requiresBookLLM)  // 没文/在跑/没 Key
    }

    /// 文档操作下拉。
    private var documentOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.document")) {  // 「文档」
            documentOperationsMenuContent  // 同一份，避免两套
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.documentMenu", BookKeyboardShortcuts.documentMenuSummary))  // 没配先说 Key
    }

    @ViewBuilder
    /// 文档菜单装不下时进溢出。includeDocumentMenu 为假则只留空位。
    private func documentToolbarOverflowMenu(includeDocumentMenu: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.toolbarDocOverflow")) {  // … 菜单
            if isReadingToolbarContext {  // 进化页不塞讲解
                Button {
                    viewModel.openBookSettings()  // 先切助手再 sheet
                } label: {
                    Text(BookL10n.string("settings.book"))  // 本书设置
                }
                BookToolbarMenuDivider()  // 和正式项隔开
            }

            if includeDocumentMenu {  // 最小栏才把文档也塞进来
                BookToolbarSubmenu(title: BookL10n.string("menu.document")) {  // 子菜单
                    documentOperationsMenuContent  // 同一份，避免两套
                }
            }

            if isReadingToolbarContext {  // 进化页不塞讲解
                if includeDocumentMenu || viewModel.assistant.readingAssistantPanel != .explanation {  // 讲解栏外面已有则不重复
                    BookToolbarSubmenu(title: BookL10n.string("menu.explanation")) {  // 讲解
                        explanationOperationsMenuContent  // 同一份
                    }
                }
                if includeDocumentMenu || viewModel.assistant.readingAssistantPanel != .translation {  // 译文栏外面已有则不重复
                    BookToolbarSubmenu(title: BookL10n.string("menu.translation")) {  // 译文
                        translationOperationsMenuContent  // 同一份
                    }
                }
                BookToolbarSubmenu(title: BookL10n.string("menu.speech")) {  // 朗读总是进溢出
                    speechOperationsMenuContent  // 各来源
                }
            }
        }
    }

    /// 讲解操作下拉。
    private var explanationOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.explanation")) {  // 「讲解」
            explanationOperationsMenuContent  // 同一份
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explanationMenu", BookKeyboardShortcuts.explanationMenuSummary))  // 没配先说 Key
    }

    @ViewBuilder
    /// 讲解菜单：生成、朗读、清空。
    private var explanationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem  // 没配先插引导

        if viewModel.document.explanationBundle.availableToShow.count >= 2 {
            BookToolbarSubmenu(title: BookL10n.string("explanation.displayLanguage")) {
                ForEach(viewModel.document.explanationBundle.availableToShow) { language in
                    Button {
                        viewModel.document.explanationBundle.show(language)
                    } label: {
                        HStack {
                            Text(language.localizedName)
                            if viewModel.document.explanationBundle.displayed == language {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        BookToolbarSubmenu(title: BookL10n.string("explanation.target.title")) {
            ForEach(TranslationTargetLanguage.selectableTargets) { language in
                let selected = settings.explanationTargetLanguages.contains(language)
                BookToolbarMenuCheckbox(
                    title: language.localizedName,
                    isOn: selected,
                    isEnabled: !selected || settings.explanationTargetLanguages.count > 1
                ) {
                    settings.toggleExplanationTargetLanguage(language)
                }
            }
        }

        BookToolbarMenuDivider()

        Button {
            viewModel.assistant.explainSelection()  // 选区+上下文
        } label: {
            Text(BookL10n.string("action.explainSelection"))  // 讲选区
        }
        .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)  // 快捷键
        .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)  // 没选区/没 Key/在跑

        Button {
            viewModel.assistant.explainFullText()  // 全文
        } label: {
            Text(BookL10n.string("action.explainFull"))  // 讲全文
        }
        .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)  // 快捷键
        .disabled(  // 多条件
            requiresBookLLM  // 没 Key
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                || viewModel.isRunning  // 在跑
        )

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.assistant.newExplanationDocument()  // 只留欢迎
        } label: {
            Text(BookL10n.string("action.new"))  // 新建
        }
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.assistant.openExplanationDocument()  // 拆成对话
        } label: {
            Text(BookL10n.string("action.open"))  // 打开
        }
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.assistant.saveExplanationDocument()  // 带【助手】标记
        } label: {
            Text(BookL10n.string("action.save"))  // 存讲解
        }
        .disabled(!viewModel.assistant.hasExplanationContent)  // 只有欢迎

        Button {
            viewModel.assistant.selectAllExplanation()  // 信号
        } label: {
            Text(BookL10n.string("action.selectAll"))  // 全选讲解
        }
        .disabled(!viewModel.assistant.hasExplanationContent)  // 只有欢迎

        Button(role: .destructive) {  // 红字
            viewModel.assistant.clearExplanation()  // 回欢迎，不关原文
        } label: {
            Text(BookL10n.string("action.clearExplanation"))  // 清讲解
        }
        .disabled(viewModel.isRunning || !viewModel.assistant.hasExplanationContent)  // 没内容或在跑

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.assistant.readExplanationAloud()  // 正在读则停
        } label: {
            Text(viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readExplanation"))  // 同一项切换
        }
        .disabled(viewModel.isRunning || (!viewModel.assistant.hasExplanationContent && !viewModel.assistant.isSpeakingExplanation))  // 没得读且没在读
    }

    /// 翻译操作下拉。
    private var translationOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.translation")) {  // 「译文」
            translationOperationsMenuContent  // 同一份
        }
        .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.translationMenu", BookKeyboardShortcuts.translationMenuSummary))  // 没配先说 Key
    }

    @ViewBuilder
    /// 翻译菜单：译、对齐、对照表。
    private var translationOperationsMenuContent: some View {
        bookLLMConfigGuideMenuItem  // 没配先插引导

        if viewModel.document.translationLanguagesAvailableToShow.count >= 2 {
            BookToolbarSubmenu(title: BookL10n.string("translation.displayLanguage")) {
                ForEach(viewModel.document.translationLanguagesAvailableToShow) { language in
                    Button {
                        viewModel.document.showTranslationLanguage(language)
                    } label: {
                        HStack {
                            Text(language.localizedName)
                            if viewModel.document.displayedTranslationLanguage == language {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }

        BookToolbarSubmenu(title: BookL10n.string("translation.target.title")) {
            ForEach(TranslationTargetLanguage.selectableTargets) { language in
                let selected = settings.translationTargetLanguages.contains(language)
                BookToolbarMenuCheckbox(
                    title: language.localizedName,
                    isOn: selected,
                    isEnabled: !selected || settings.translationTargetLanguages.count > 1
                ) {
                    settings.toggleTranslationTargetLanguage(language)
                }
            }
        }

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.generateLessonPlan()  // 逐词，选区优先
        } label: {
            Text(BookL10n.string("action.wordTranslation"))  // 逐词译
        }
        .disabled(  // 多条件
            requiresBookLLM  // 没 Key
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                || viewModel.isRunning  // 在跑
        )

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.refineLessonPlan()  // 整段，带已有译文
        } label: {
            Text(BookL10n.string("action.paragraphTranslation"))  // 整段译
        }
        .disabled(  // 多条件
            requiresBookLLM  // 没 Key
                || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                || viewModel.isRunning  // 在跑
        )

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.assistant.readLessonPlanAloud()  // 读译文，再点停
        } label: {
            Text(viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readTranslation"))  // 同一项切换
        }
        .bookMenuShortcut(
            viewModel.assistant.isSpeakingExplanation ? nil : BookKeyboardShortcuts.readTranslationFull  // 在读时不绑快捷键，避免抢
        )
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 没译文
                    && !viewModel.assistant.isSpeakingExplanation)  // 没在读才能灰
        )

        Button {
            viewModel.translation.selectAllRightPage()  // 切译文栏再发信号
        } label: {
            Text(BookL10n.string("action.selectAllTranslation"))  // 全选译文
        }
        .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)  // 快捷键
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)  // 空译文

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.assistant.selectReadingAssistantPanel(.translation)  // 先切栏再操作
            viewModel.translation.openLessonPlanFile()  // 读入并对齐
        } label: {
            Text(BookL10n.string("action.openTranslation"))  // 打开译文
        }
        .disabled(viewModel.isRunning)  // 跑着不清

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.assistant.selectReadingAssistantPanel(.translation)  // 先切栏再操作
            viewModel.translation.alignTranslationWithSource()  // 本地启发式，锁了会拒
        } label: {
            Text(BookL10n.string("translation.alignSource"))  // 对齐原文
        }
        .disabled(!viewModel.translation.canAlignTranslationWithSource)  // 缺一边或锁了或在跑

        Button {
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.assistant.selectReadingAssistantPanel(.translation)  // 先切栏再操作
            viewModel.translation.saveLessonPlan()  // 另存面板
        } label: {
            Text(BookL10n.string("action.saveTranslation"))  // 存译文
        }
        .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)  // 空译文

        Button(role: .destructive) {  // 红字
            viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
            viewModel.assistant.selectReadingAssistantPanel(.translation)  // 先切栏再操作
            viewModel.translation.clearLessonPlan()  // 清译文和对齐
        } label: {
            Text(BookL10n.string("action.clearTranslation"))  // 清译文
        }
        .disabled(viewModel.isRunning || viewModel.lessonPlanContent.isEmpty)  // 空或在跑
    }

    /// 朗读操作下拉。
    private var speechOperationsMenu: some View {
        BookToolbarMenuButton(title: BookL10n.string("menu.speech")) {
            speechOperationsMenuContent  // 各来源
        }
        .help(BookL10n.format("help.speechMenu", BookKeyboardShortcuts.speechMenuSummary))  // 带快捷键摘要
    }

    @ViewBuilder
    /// 朗读菜单：读这篇或停。
    private var speechOperationsMenuContent: some View {
        Button {
            viewModel.assistant.readOriginalFullTextAloud()  // 左页全文
        } label: {
            Text(BookL10n.string("menu.readOriginalFull"))  // 读原文
        }
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 没原文
                    && !viewModel.assistant.isSpeakingExplanation)  // 没在读才能灰
        )

        Button {
            viewModel.assistant.readOriginalSelectionAloud()  // 左页选区
        } label: {
            Text(BookL10n.string("menu.readOriginalSelection"))  // 读选区
        }
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.effectiveSelectedText.isEmpty && !viewModel.assistant.isSpeakingExplanation)  // 没选且没在读
        )

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.assistant.readTranslationFullTextAloud()  // 译文全文
        } label: {
            Text(BookL10n.string("menu.readTranslationFull"))  // 读译文
        }
        .bookMenuShortcut(BookKeyboardShortcuts.readTranslationFull)  // 和菜单同一键
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 没译文
                    && !viewModel.assistant.isSpeakingExplanation)  // 没在读才能灰
        )

        Button {
            viewModel.assistant.readTranslationSelectionAloud()  // 译文选区
        } label: {
            Text(BookL10n.string("menu.readTranslationSelection"))  // 读译文选区
        }
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.effectiveLessonPlanSelectedText.isEmpty && !viewModel.assistant.isSpeakingExplanation)  // 没选
        )

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.assistant.readExplanationFullTextAloud()  // 讲解全文
        } label: {
            Text(BookL10n.string("menu.readExplanationFull"))  // 读讲解
        }
        .disabled(  // 多条件
            viewModel.isRunning
                || (!viewModel.assistant.hasExplanationContent && !viewModel.assistant.isSpeakingExplanation)  // 没讲解
        )

        Button {
            viewModel.assistant.readExplanationSelectionAloud()  // 讲解选区
        } label: {
            Text(BookL10n.string("menu.readExplanationSelection"))  // 读讲解选区
        }
        .disabled(  // 多条件
            viewModel.isRunning
                || (viewModel.effectiveExplanationPanelSelectedText.isEmpty && !viewModel.assistant.isSpeakingExplanation)  // 没选
        )
    }

    /// 阅读主操作条，随宽度换档。
    private var readingActionBar: some View {
        Group {
            if viewModel.assistant.isSpeakingExplanation {  // 朗读中中栏改成播放条
                BookToolbarOverflowRow {  // 宽→全，窄→压，再窄→溢出
                    unifiedSpeechPlaybackBarFull  // 来源+暂停+停
                } compact: {
                    unifiedSpeechPlaybackBarCompact  // 压
                } minimal: {
                    unifiedSpeechPlaybackBarMinimal  // 溢出
                }
            } else if isReadingToolbarContext {  // 助手：讲解/译文主按钮
                BookToolbarOverflowRow {  // 宽→全，窄→压，再窄→溢出
                    readingPrimaryActionBarFull  // 分栏+主操作
                } compact: {
                    readingPrimaryActionBarCompact  // 分栏+溢出
                } minimal: {
                    readingPrimaryActionBarMinimal  // 全进溢出
                }
            } else {  // 进化页
                BookToolbarOverflowRow {  // 宽→全，窄→压，再窄→溢出
                    evolutionPrimaryActionBarFull  // 进化+分析+停止
                } compact: {
                    evolutionPrimaryActionBarCompact  // 进化+溢出
                } minimal: {
                    evolutionPrimaryActionBarMinimal  // 全进溢出
                }
            }
        }
        .frame(maxWidth: .infinity)  // 中栏拉满
        .animation(.easeOut(duration: 0.18), value: viewModel.assistant.isSpeakingExplanation)  // 切播放条
        .animation(.easeOut(duration: 0.2), value: viewModel.rightPageTab)  // 切 Tab 栏宽
    }

    /// 阅读主操作完整按钮。
    private var readingPrimaryActionBarFull: some View {
        HStack(spacing: 8) {  // 脏标记
            readingAssistantPanelSwitcher  // 讲解/译文
            switch viewModel.assistant.readingAssistantPanel {
            case .explanation:  // 主按钮是讲选区/全文
                explanationPrimaryActionButtons  // 两个胶囊
            case .translation:  // 主按钮是逐词/整段
                translationPrimaryActionButtons  // 两个胶囊
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 阅读主操作图标档。
    private var readingPrimaryActionBarCompact: some View {
        HStack(spacing: 8) {  // 脏标记
            readingAssistantPanelSwitcher  // 讲解/译文
            readingPrimaryOverflowMenu(includePanelSwitcher: false)  // 外面已有分栏
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 阅读主操作菜单档。
    private var readingPrimaryActionBarMinimal: some View {
        HStack(spacing: 8) {  // 脏标记
            readingPrimaryOverflowMenu(includePanelSwitcher: true)  // 分栏也塞进去
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    @ViewBuilder
    /// 阅读主操作溢出。窄屏才把分栏切换塞进来。
    private func readingPrimaryOverflowMenu(includePanelSwitcher: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.panelOverflow")) {  // 中栏溢出
            if includePanelSwitcher {  // 最小栏
                ForEach(ReadingAssistantPanel.allCases) { panel in  // 讲解/译文
                    Button {
                        viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
                        viewModel.assistant.selectReadingAssistantPanel(panel)  // 切子栏
                    } label: {
                        Text(panel.toolbarTitle)  // 本地化
                    }
                }
                BookToolbarMenuDivider()  // 和正式项隔开
            }

            switch viewModel.assistant.readingAssistantPanel {
            case .explanation:  // 主按钮是讲选区/全文
                Button {
                    viewModel.assistant.explainSelection()  // 选区+上下文
                } label: {
                    Text(BookL10n.string("action.explainSelection"))  // 讲选区
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)  // 快捷键
                .disabled(requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning)  // 没选区/没 Key/在跑

                Button {
                    viewModel.assistant.explainFullText()  // 全文
                } label: {
                    Text(BookL10n.string("action.explainFull"))  // 讲全文
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)  // 快捷键
                .disabled(  // 多条件
                    requiresBookLLM  // 没 Key
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                        || viewModel.isRunning  // 在跑
                )
            case .translation:  // 主按钮是逐词/整段
                Button {
                    viewModel.generateLessonPlan()  // 逐词，选区优先
                } label: {
                    Text(BookL10n.string("action.wordTranslation"))  // 逐词译
                }
                .disabled(  // 多条件
                    requiresBookLLM  // 没 Key
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                        || viewModel.isRunning  // 在跑
                )

                Button {
                    viewModel.refineLessonPlan()  // 整段，带已有译文
                } label: {
                    Text(BookL10n.string("action.paragraphTranslation"))  // 整段译
                }
                .disabled(  // 多条件
                    requiresBookLLM  // 没 Key
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                        || viewModel.isRunning  // 在跑
                )
            }
        }
    }

    /// 讲解 / 翻译分栏切换。
    private var readingAssistantPanelSwitcher: some View {
        HStack(spacing: 8) {  // 脏标记
            ForEach(ReadingAssistantPanel.allCases) { panel in  // 讲解/译文
                BookActionButton(  // 胶囊钮
                    title: panel.toolbarTitle,
                    isProminent: viewModel.rightPageTab == .readingAssistant  // 还要在助手 Tab
                        && viewModel.assistant.readingAssistantPanel == panel,  // 当前子栏高亮
                    isCompact: true  // 工具栏矮
                ) {
                    viewModel.selectRightPageTab(.readingAssistant)  // 切 Tab，进化欢迎若需要会补
                    viewModel.assistant.selectReadingAssistantPanel(panel)  // 切子栏
                }
                .help(panel.toolbarHelp)  // 各栏帮助
            }
        }
    }

    /// 进化主操作完整按钮。
    private var evolutionPrimaryActionBarFull: some View {
        HStack(spacing: 8) {  // 脏标记
            evolutionPrimaryActionButtons  // 进化+分析
            if viewModel.isRunning {  // 跑着才露停
                evolutionStopButton  // 取消并回滚
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 进化主操作图标档。
    private var evolutionPrimaryActionBarCompact: some View {
        HStack(spacing: 8) {  // 脏标记
            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.evolve"),  // 「进化」
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning  // 没 Cursor 或在跑
            ) {
                viewModel.evolution.startEvolution()  // 下一条 pending
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.format("help.runNextEvolution", BookKeyboardShortcuts.evolutionHint))  // 没配先说原因

            evolutionPrimaryOverflowMenu(includeEvolution: false)  // 外面已有进化钮
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 进化主操作菜单档。
    private var evolutionPrimaryActionBarMinimal: some View {
        HStack(spacing: 8) {  // 脏标记
            evolutionPrimaryOverflowMenu(includeEvolution: true)  // 进化也进溢出
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    @ViewBuilder
    /// 进化主操作溢出。
    private func evolutionPrimaryOverflowMenu(includeEvolution: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.evolutionOverflow")) {  // 进化溢出
            if includeEvolution {  // 最小栏
                Button {
                    viewModel.evolution.startEvolution()  // 下一条 pending
                } label: {
                    Text(BookL10n.string("action.evolve"))  // 进化
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)  // 快捷键
                .disabled(requiresEvolutionBackend || viewModel.isRunning)  // 没配或在跑
            }

            Button {
                viewModel.evolution.analyzeOptimizations()  // 只出建议
            } label: {
                Text(BookL10n.string("action.analyze"))  // 分析
            }
            .disabled(requiresEvolutionBackend || viewModel.isRunning)  // 没配或在跑

            if viewModel.isRunning {  // 跑着才露停
                Button {
                    viewModel.stopCurrentRun()  // 取消，进化回 pending
                } label: {
                    Text(BookL10n.string("action.stop"))  // 停止
                }
            }
        }
    }

    /// 统一朗读条完整档。
    private var unifiedSpeechPlaybackBarFull: some View {
        HStack(spacing: 8) {  // 脏标记
            speechSourcePill  // 正在读哪一路
            speechPauseResumeButton  // 暂停/继续
            speechStopButton  // 立刻停
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 统一朗读条图标档。
    private var unifiedSpeechPlaybackBarCompact: some View {
        HStack(spacing: 8) {  // 脏标记
            speechSourcePill  // 正在读哪一路
            speechPlaybackOverflowMenu(includeSource: false)  // 外面已有来源 pill
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 统一朗读条菜单档。
    private var unifiedSpeechPlaybackBarMinimal: some View {
        HStack(spacing: 8) {  // 脏标记
            speechPlaybackOverflowMenu(includeSource: true)  // 来源也进溢出
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    @ViewBuilder
    /// 当前在读原文还是讲解。
    private var speechSourcePill: some View {
        if let source = viewModel.assistant.currentSpeechSource {  // 有来源用具体标签
            BookStatusPill(  // 配置状态
                title: source.label,  // 原文/译文/讲解
                icon: source.icon,  // 对应 SF Symbol
                tint: BookTheme.goldSoft  // 在读用金字
            )
            .help(BookL10n.format("help.currentSpeech", source.label))  // 哪一路
        } else {  // 进化页
            BookStatusPill(  // 配置状态
                title: BookL10n.string("status.speaking"),  // 来源丢了用泛称
                icon: "speaker.wave.2.fill",  // 喇叭
                tint: BookTheme.goldSoft  // 在读用金字
            )
            .help(BookL10n.string("help.speakingNow"))  // 正在读
        }
    }

    /// 朗读暂停或继续。
    private var speechPauseResumeButton: some View {
        BookActionButton(  // 胶囊钮
            title: viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause"),  // 暂停/继续
            isCompact: true,
            isDisabled: viewModel.isRunning  // AI 跑着不搅朗读键
        ) {
            viewModel.assistant.toggleExplanationSpeechPause()  // 合成器 pause/resume
        }
        .help(viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))  // 随状态
    }

    /// 停朗读。
    private var speechStopButton: some View {
        BookActionButton(  // 胶囊钮
            title: BookL10n.string("action.stop"),  // 停
            isCompact: true,
            isDisabled: viewModel.isRunning  // AI 跑着不搅朗读键
        ) {
            viewModel.assistant.stopExplanationSpeech()  // 清会话
        }
        .help(BookL10n.string("help.stopSpeech"))  // 立刻停
    }

    @ViewBuilder
    /// 朗读来源装不下时进溢出。
    private func speechPlaybackOverflowMenu(includeSource: Bool) -> some View {
        BookToolbarOverflowMenu(help: BookL10n.string("help.speechControls")) {  // 播放控制
            if includeSource, let source = viewModel.assistant.currentSpeechSource {  // 最小栏先写来源
                BookToolbarMenuCaption(title: BookL10n.format("help.currentSpeech", source.label))  // 不可点说明
            } else if includeSource {  // 没来源
                BookToolbarMenuCaption(title: BookL10n.string("status.speaking"))  // 泛称
            }
            if includeSource {  // 说明后面隔开
                BookToolbarMenuDivider()  // 和正式项隔开
            }

            Button {
                viewModel.assistant.toggleExplanationSpeechPause()  // 合成器 pause/resume
            } label: {
                Text(viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))  // 同一项
            }
            .disabled(viewModel.isRunning)  // 跑着不清

            Button {
                viewModel.assistant.stopExplanationSpeech()  // 清会话
            } label: {
                Text(BookL10n.string("menu.stopSpeaking"))  // 停止朗读
            }
            .disabled(viewModel.isRunning)  // 跑着不清
        }
    }

    /// 讲解主按钮（生成等）。
    private var explanationPrimaryActionButtons: some View {
        Group {
            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.explainSelection"),
                isCompact: true,
                isDisabled: requiresBookLLM || viewModel.effectiveSelectedText.isEmpty || viewModel.isRunning
            ) {
                viewModel.assistant.explainSelection()  // 选区+上下文
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainSelection", BookKeyboardShortcuts.explainSelectionHint))  // 没配说 Key

            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.explainFull"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                    || viewModel.isRunning  // 在跑
            ) {
                viewModel.assistant.explainFullText()  // 全文
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainFull", BookKeyboardShortcuts.explainFullTextHint))  // 没配说 Key
        }
    }

    /// 翻译主按钮。
    private var translationPrimaryActionButtons: some View {
        Group {
            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.wordTranslation"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                    || viewModel.isRunning  // 在跑
            ) {
                viewModel.generateLessonPlan()  // 逐词，选区优先
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.wordTranslationJSON"))  // 逐词出 JSON

            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.paragraphTranslation"),
                isCompact: true,
                isDisabled: requiresBookLLM
                    || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空页
                    || viewModel.isRunning  // 在跑
            ) {
                viewModel.refineLessonPlan()  // 整段，带已有译文
            }
            .help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.paragraphTranslationJSON"))  // 整段出 JSON
        }
    }

    /// 进化主按钮。
    private var evolutionPrimaryActionButtons: some View {
        Group {
            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.evolve"),  // 「进化」
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning  // 没 Cursor 或在跑
            ) {
                viewModel.evolution.startEvolution()  // 下一条 pending
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.format("help.runNextEvolution", BookKeyboardShortcuts.evolutionHint))  // 没配先说原因

            BookActionButton(  // 胶囊钮
                title: BookL10n.string("action.analyze"),
                isCompact: true,
                isDisabled: requiresEvolutionBackend || viewModel.isRunning  // 没 Cursor 或在跑
            ) {
                viewModel.evolution.analyzeOptimizations()  // 只出建议
            }
            .help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.string("help.analyzeSource"))  // 只读分析
        }
    }

    /// 停进化跑。
    private var evolutionStopButton: some View {
        BookActionButton(  // 胶囊钮
            title: BookL10n.string("action.stop"),  // 停
            isCompact: true  // 工具栏矮
        ) {
            viewModel.stopCurrentRun()  // 取消，进化回 pending
        }
        .help(BookL10n.string("help.stopEvolutionTask"))  // 停进化
    }

    /// 次要工具（设置、手册）。
    private var utilityActionBar: some View {
        BookToolbarOverflowRow {  // 宽→全，窄→压，再窄→溢出
            utilityActionBarFull  // 进化 Tab+菜单
        } compact: {
            utilityActionBarCompact  // Tab+溢出
        } minimal: {
            utilityActionBarMinimal  // 助手页只留 Tab
        }
    }

    /// 次要工具完整档。
    private var utilityActionBarFull: some View {
        HStack(spacing: 8) {  // 脏标记
            aiEvolutionTabButton  // 切进化
            if !isReadingToolbarContext {  // 进化页才露进化菜单
                evolutionOperationsMenu  // 分析/存命令
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 次要工具图标档。
    private var utilityActionBarCompact: some View {
        HStack(spacing: 8) {  // 脏标记
            aiEvolutionTabButton  // 切进化
            if !isReadingToolbarContext {  // 进化页才露进化菜单
                utilityEvolutionOverflowMenu(includeTab: false)  // 外面已有 Tab
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 次要工具菜单档。
    private var utilityActionBarMinimal: some View {
        HStack(spacing: 8) {  // 脏标记
            if isReadingToolbarContext {  // 进化页不塞讲解
                aiEvolutionTabButton  // 切进化
            } else {  // 进化页
                utilityEvolutionOverflowMenu(includeTab: true)  // Tab 也进溢出
            }
        }
        .fixedSize(horizontal: true, vertical: false)  // 溢出行按内容宽
    }

    /// 切到 AI 进化右页。
    private var aiEvolutionTabButton: some View {
        BookActionButton(  // 胶囊钮
            title: RightPageTab.aiEvolution.localizedTitle,  // 「AI 进化」
            isProminent: viewModel.rightPageTab == .aiEvolution,  // 当前高亮
            isCompact: true  // 工具栏矮
        ) {
            viewModel.selectRightPageTab(.aiEvolution)  // 补欢迎并强制 Cursor
        }
        .help(BookL10n.string("help.switchEvolution"))  // 切进化
    }

    @ViewBuilder
    /// 工具区进化 Tab 溢出。
    private func utilityEvolutionOverflowMenu(includeTab: Bool) -> some View {
        BookToolbarOverflowMenu(
            help: requiresEvolutionBackend
                ? evolutionToolbarHelp
                : (viewModel.evolution.evolutionStatusLabel ?? BookL10n.format("help.evolutionDefaultMenu", BookKeyboardShortcuts.evolutionMenuSummary))
        ) {
            if includeTab {
                Button {
                    viewModel.selectRightPageTab(.aiEvolution)  // 补欢迎并强制 Cursor
                } label: {
                    Text(RightPageTab.aiEvolution.localizedTitle)
                }
                BookToolbarMenuDivider()  // 和正式项隔开
            }

            BookToolbarSubmenu(
                title: RightPageTab.aiEvolution.toolbarMenuTitle ?? RightPageTab.aiEvolution.localizedTitle  // 子菜单标题
            ) {
                evolutionOperationsMenuContent  // 同一份
            }
        }
    }

    /// 进化操作下拉。
    private var evolutionOperationsMenu: some View {
        BookToolbarMenuButton(
            title: RightPageTab.aiEvolution.toolbarMenuTitle ?? RightPageTab.aiEvolution.rawValue  // 菜单钮
        ) {
            evolutionOperationsMenuContent  // 同一份
        }
        .help(requiresEvolutionBackend ? evolutionToolbarHelp : (viewModel.evolution.evolutionStatusLabel ?? BookL10n.format("help.evolutionDefaultMenu", BookKeyboardShortcuts.evolutionMenuSummary)))
    }

    @ViewBuilder
    /// 进化菜单：分析、执行、队列。
    private var evolutionOperationsMenuContent: some View {
        evolutionConfigGuideMenuItem  // 没配先引导

        Button {
            viewModel.selectRightPageTab(.aiEvolution)  // 补欢迎并强制 Cursor
            viewModel.evolution.startEvolution()  // 下一条 pending
        } label: {
            Text(BookL10n.string("action.evolve"))  // 进化
        }
        .bookMenuShortcut(BookKeyboardShortcuts.evolution)  // 快捷键
        .disabled(requiresEvolutionBackend || viewModel.isRunning)  // 没配或在跑

        Button {
            viewModel.selectRightPageTab(.aiEvolution)  // 补欢迎并强制 Cursor
            viewModel.evolution.analyzeOptimizations()  // 只出建议
        } label: {
            Text(BookL10n.string("action.analyze"))  // 分析
        }
        .disabled(requiresEvolutionBackend || viewModel.isRunning)  // 没配或在跑

        Button {
            viewModel.openSettings()  // 进化设置
        } label: {
            Text(BookL10n.string("settings.evolution"))  // 进化设置
        }

        BookToolbarMenuDivider()  // 和正式项隔开

        Button {
            viewModel.evolution.saveEvolutionCommands()  // 导出编号笔记
        } label: {
            Text(BookL10n.string("action.saveEvolutionCommands"))  // 存命令
        }
        .disabled(!viewModel.canSaveEvolutionCommands)  // 空队列

        Button {
            viewModel.evolution.openEvolutionCommands()  // 导入，覆盖先问
        } label: {
            Text(BookL10n.string("action.openEvolutionCommands"))  // 开命令
        }
        .disabled(!viewModel.canOpenEvolutionCommands)  // 在跑不能开

        Button(role: .destructive) {  // 红字
            viewModel.selectRightPageTab(.aiEvolution)  // 补欢迎并强制 Cursor
            viewModel.clearAIContext()  // 清进化对话和 token
        } label: {
            Text(BookL10n.string("action.clearAIContext"))  // 清上下文
        }
        .disabled(viewModel.isRunning || !viewModel.canClearAIContext)  // 空或在跑

        if viewModel.isRunning {  // 跑着才露停
            BookToolbarMenuDivider()  // 和正式项隔开

            Button {
                viewModel.stopCurrentRun()  // 取消，进化回 pending
            } label: {
                Text(BookL10n.string("action.stop"))  // 停止
            }
        }
    }

    /// 打开的书：左页、书脊、右页。
    private var openBook: some View {
        GeometryReader { geometry in  // 量工具栏宽
            let pageWidth = max(0, (geometry.size.width - learningSpineWidth) / 2)  // 左右均分，扣书脊

            BookInterface.SpreadShell {  // 书壳
                HStack(spacing: 0) {  // 三栏+两条竖线
                    leftPage  // 原文铺满
                        .frame(width: pageWidth)  // 半宽

                    ZStack(alignment: .top) {  // 脊上挂丝带
                        bookSpine  // 凹槽
                        BookInterface.BookmarkRibbon()  // 装饰
                    }

                    rightPage  // 助手铺满
                        .frame(width: pageWidth)  // 半宽
                }
            }
        }
    }

    /// 学习区全屏遮罩，盖住书桌。
    private var learningPaneFullscreenOverlay: some View {
        ZStack {
            BookTheme.deskGradient  // 桌面底
                .ignoresSafeArea()  // 铺满
            BookTheme.deskLampGlow  // 台灯光
                .ignoresSafeArea()  // 铺满

            VStack(spacing: 14) {
                learningPaneFullscreenHeader  // 回双栏
                Group {
                    if learningPaneFocus == .leading {  // 左全屏用文件名
                        leftPage  // 原文铺满
                    } else {  // 进化页
                        rightPage  // 助手铺满
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃剩余
            }
            .padding(24)  // 桌边
        }
        .background(learningPaneFullscreenShortcuts)  // Esc 回双栏
    }

    /// 学习区全屏顶栏。
    private var learningPaneFullscreenHeader: some View {
        HStack(spacing: 12) {
            Button(action: { setLearningPaneFocus(.both) }) {  // 回双栏并退系统全屏
                BookToolbarCapsuleLabel(
                    title: BookL10n.string("layout.spread"),  // 「双页」
                    isProminent: true,  // 主钮
                    isCompact: false,  // 顶栏够宽
                    isHovering: false  // 不跟悬停
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(BookL10n.string("help.restoreSpread"))  // 回双栏
            .keyboardShortcut(.escape, modifiers: [])  // 无修饰

            Text(learningPaneFullscreenTitle)  // 文件名或右栏标题
                .font(BookTheme.titleFont)  // 标题
                .foregroundStyle(BookTheme.goldSoft)  // 金字
                .lineLimit(1)  // 太长截
                .layoutPriority(-1)  // 先被压

            Spacer(minLength: 8)  // 右空
        }
        .padding(.horizontal, 24)  // 皮条
        .padding(.vertical, 16)  // 皮条
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BookTheme.leatherGradient)  // 皮色
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)  // 细边
                }
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)  // 浮
        }
    }

    /// 学习区全屏快捷键。
    private var learningPaneFullscreenShortcuts: some View {
        Group {
            Button(BookL10n.string("layout.spread")) { setLearningPaneFocus(.both) }  // ⌘⌥1 双栏
                .keyboardShortcut(.escape, modifiers: [])  // 无修饰
        }
        .opacity(0)  // 不可见
        .frame(width: 0, height: 0)  // 不占位
        .allowsHitTesting(false)  // 不挡
        .accessibilityHidden(true)  // 不进辅助
    }

    /// 左页原文或笔记。
    private var leftPage: some View {
        VStack(spacing: 0) {  // 顶栏+摊开的书
            pageLabel(  // 「原文」+全屏钮
                title: BookL10n.string("page.source"),  // 原文
                icon: "text.book.closed",  // 书
                paneSide: .leading  // 左栏全屏钮
            )

            ZStack {
                SelectableTextView(  // 可编辑左页
                    text: Binding(
                        get: { viewModel.fileContent },  // VM 正文
                        set: { viewModel.fileContent = $0 }  // 编辑写回，didSet 标脏
                    ),
                    onSelectionChange: { selection, range in  // 即时+提交
                        viewModel.document.updateSelection(selection, range: range)  // 空选保留 lastCommitted
                    },
                    onVisibleRangeChange: { range, _ in  // 给译文对滚
                        viewModel.handleSourceTextScroll(visibleRange: range)  // 推对齐同步
                    },
                    scrollProxy: viewModel.translation.sourceTextScrollProxy,  // 对滚/高亮
                    selectAllSignal: viewModel.document.leftSelectAllSignal  // 菜单全选
                )
                .id("leftPageTextView")  // 稳定身份，避免重建丢 IME

                if viewModel.fileContent.isEmpty && !viewModel.document.isDocumentOpen {  // 冷启动欢迎
                    BookInterface.EmptyPageWelcome {  // 点了开文件
                        viewModel.document.openFile()  // 单文件
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                BookInterface.PageCornerFold()  // 折角
            }

            leftPageFooter  // 字数和保存状态
        }
        .bookPaperTexture()  // 纸纹
        .bookPage(BookTheme.pageLeft)  // 左纸色
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // 页角
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in  // 只收文件
            handleFileDrop(providers)  // txt 当原文
        }
    }

    /// 左页页脚：保存状态。
    private var leftPageFooter: some View {
        HStack(spacing: 16) {  // 脚
            BookInterface.PageMark(label: BookInterface.leftPageMark)  // 左页标
            Label(BookL10n.format("footer.characters", viewModel.fileContent.count), systemImage: "character.cursor.ibeam")  // 字数
            if !viewModel.effectiveSelectedText.isEmpty {  // 有选区才露
                Label(BookL10n.format("footer.selected", viewModel.effectiveSelectedText.count), systemImage: "highlighter")  // 选了几个字
            }
            Spacer()  // 全屏钮推右
            Button(BookL10n.string("action.selectAll")) {  // 脚上全选
                viewModel.document.selectAllLeftPage()  // 发全选信号
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)  // 小字
            .foregroundStyle(BookTheme.leather)  // 皮色可点
            .disabled(viewModel.fileContent.isEmpty)  // 空页
            .help(BookL10n.string("help.selectAllLeftPage"))  // 提示
            Text(leftPageSaveStatus)  // 已保存/未保存/自动存
                .foregroundStyle(viewModel.document.isDirty ? Color.orange : BookTheme.inkMuted)  // 脏了橙色
        }
        .font(BookTheme.captionFont)  // 小字
        .foregroundStyle(BookTheme.inkMuted)  // 淡
        .padding(.horizontal, 28)  // 和正文齐
        .padding(.vertical, 10)  // 略扁
        .background {
            Rectangle()  // 竖线
                .fill(BookTheme.pageEdge.opacity(0.22))  // 脚底略深
                .overlay(alignment: .top) { Divider() }  // 和正文分界
        }
    }

    /// 右页讲解或进化。
    private var rightPage: some View {
        VStack(spacing: 0) {  // 顶栏+摊开的书
            if showsRightPageLabel {  // 进化页才画页眉，助手页自己有栏
                pageLabel(  // 「原文」+全屏钮
                    title: viewModel.rightPageTab.localizedTitle,  // 「AI 进化」
                    icon: viewModel.rightPageTab.icon,  // Tab 图标
                    paneSide: .trailing  // 右栏全屏钮
                )
            }

            ExplanationChatView(  // 讲解/译文/进化都在这
                learningPaneFocus: learningPaneFocus,  // 全屏时收起一些栏
                onLearningPaneFocusChange: setLearningPaneFocus  // 右页里也能切全屏
            )
        }
        .overlay(alignment: .bottomTrailing) {
            BookInterface.PageCornerFold()  // 折角
        }
        .bookPaperTexture()  // 纸纹
        .bookPage(BookTheme.pageRight)  // 右纸色略暖
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // 页角
    }

    /// 右页要不要显示栏目标题。
    private var showsRightPageLabel: Bool {
        viewModel.rightPageTab == .aiEvolution  // 助手页眉由聊天视图自己画
    }

    /// 全屏学习区标题（讲解/翻译/进化）。
    private var learningPaneFullscreenTitle: String {
        if learningPaneFocus == .leading {  // 左全屏用文件名
            return viewModel.document.displayFileName  // 带脏点
        }
        if viewModel.rightPageTab == .readingAssistant {  // 助手页看病书模型
            return viewModel.readingAssistantPanel.toolbarTitle  // 讲解或译文
        }
        return viewModel.rightPageTab.localizedTitle  // 进化
    }

    /// 中间书脊装饰。
    private var bookSpine: some View {
        ZStack {
            LinearGradient(  // 中间深
                colors: [BookTheme.spineLight, BookTheme.spineDark, BookTheme.spineLight],  // 凹槽
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(spacing: 6) {  // 假线装孔
                ForEach(0 ..< 12, id: \.self) { _ in  // 十二个
                    Capsule()  // 孔
                        .fill(Color.black.opacity(0.08))  // 浅
                        .frame(width: 2, height: 10)  // 竖点
                }
            }
        }
        .frame(width: 14)  // 比阅读脊窄，学习栏更紧
        .shadow(color: .black.opacity(0.25), radius: 4)  // 压纸
    }

    /// 页码牌。paneSide 决定左/右书口朝向。
    private func pageLabel(title: String, icon: String, subtitle: String? = nil, paneSide: HorizontalEdge? = nil) -> some View {
        VStack(spacing: 0) {  // 顶栏+摊开的书
            HStack(alignment: .center, spacing: 10) {  // 图标+标题+全屏
                Image(systemName: icon)  // 页标
                    .font(.system(size: 14, weight: .semibold))  // 小
                    .foregroundStyle(BookTheme.gold)  // 金

                VStack(alignment: .leading, spacing: 2) {  // 标题副标
                    Text(title)  // 页名
                        .font(BookTheme.labelFont)  // 标签字
                        .foregroundStyle(BookTheme.ink)  // 墨
                    if let subtitle {  // 可选
                        Text(subtitle)  // 副标
                            .font(BookTheme.captionFont)  // 小字
                            .foregroundStyle(BookTheme.inkMuted)  // 淡
                    }
                }

                Spacer()  // 全屏钮推右

                if let paneSide {  // 学习栏才有
                    learningPaneFocusButton(for: paneSide)  // 只看这边
                }

                Rectangle()  // 竖线
                    .fill(BookTheme.pageEdge.opacity(0.8))  // 短金线
                    .frame(height: 1)  // 横线
                    .frame(maxWidth: 120)  // 别拉太长
            }
            .padding(.horizontal, 28)  // 和正文齐
            .padding(.top, 22)  // 页顶
            .padding(.bottom, 8)  // 到纹样

            BookInterface.HeaderOrnament()  // 纹
                .padding(.bottom, 6)  // 到正文
        }
    }

    /// 学习模式焦点。写 session，不在按钮里另存一份。
    private func setLearningPaneFocus(_ focus: LearningPaneFocus) {
        guard learningPaneFocus != focus else { return }  // 同状态不进系统全屏 API
        learningPaneFocus = focus  // 先本地
        if focus == .both {  // 双栏退出系统全屏
            WindowFullscreenHelper.setNativeFullscreen(false)  // 退窗口全屏
        } else {  // 进化页
            WindowFullscreenHelper.setNativeFullscreen(true)  // 单栏进窗口全屏
        }
    }

    /// 左或右栏的「只看这边」按钮。
    private func learningPaneFocusButton(for side: HorizontalEdge) -> some View {
        let isFocused = (side == .leading && learningPaneFocus == .leading)  // 这一侧已经满屏
            || (side == .trailing && learningPaneFocus == .trailing)  // 或右侧
        let targetFocus: LearningPaneFocus = side == .leading ? .leading : .trailing  // 点一下看这边

        return Button {
            setLearningPaneFocus(isFocused ? .both : targetFocus)  // 再点收回
        } label: {
            Image(systemName: isFocused ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")  // 满了显示回双栏
                .font(.system(size: 11, weight: .semibold))  // 小
                .foregroundStyle(BookTheme.leather.opacity(0.72))  // 皮色
                .frame(width: 24, height: 24)  // 圆钮
                .background {
                    Circle()  // 书标底
                        .fill(BookTheme.pageEdge.opacity(0.35))  // 浅底
                }
        }
        .buttonStyle(.plain)
        .help(isFocused ? BookL10n.string("help.restoreSpreadFromFocus") : side == .leading ? BookL10n.string("help.leftFullscreen") : BookL10n.string("help.rightFullscreen"))  // 随状态
    }

    /// 左页未保存或已保存文案。
    private var leftPageSaveStatus: String {
        if let message = viewModel.document.lastSaveMessage {  // 短暂「已保存 xxx」优先
            return message  // 3 秒后空
        }
        if viewModel.document.isEditingNotes {  // 笔记档
            return viewModel.document.isDirty ? BookL10n.string("status.saving") : BookL10n.string("status.autosaved")  // 自动存中/已自动存
        }
        return viewModel.document.isDirty ? BookL10n.string("status.unsaved") : BookL10n.string("status.saved")  // 普通文件
    }

    /// 只收本地文件 URL，目录走目录浏览器。
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {  // 没有文件 URL
            return false  // 不吃这次 drop
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in  // 异步读
            guard let data = item as? Data,  // macOS 给 Data
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }  // 解不出就丢

            Task { @MainActor in  // 开文件在主线程
                viewModel.document.openDroppedFile(at: url)  // 只收 txt，脏了先问
            }
        }
        return true  // 先占住 drop，真正打开是异步
    }

    /// 目录浏览器 sheet。
    private var directoryBrowserSheet: some View {
        DirectoryBrowserView(  // 多根目录
            sessions: viewModel.document.directoryBrowserSessions,  // 已授权根
            selectedSessionID: viewModel.document.selectedDirectorySessionID,  // 当前根
            onSelectSession: { id in  // 切根
                viewModel.document.selectDirectorySession(id)  // 只记 id
            },
            onAddDirectory: {  // 再授权
                viewModel.document.addDirectoryFromPanel()  // 系统选目录
            },
            onRemoveSession: { id in  // 卸根
                viewModel.document.removeDirectorySession(id)  // 书签一起删
            },
            onToggleExpanded: { sessionID, path in  // 展开立刻落盘
                viewModel.document.toggleDirectoryNodeExpanded(sessionID: sessionID, path: path)  // 写 session
            },
            onOpen: { url, target in  // 原文/译文/讲解
                viewModel.document.openFileFromDirectory(at: url, target: target)  // 三种打开
            },
            onDismiss: {  // 关 sheet
                viewModel.document.dismissDirectoryBrowser()  // 不卸 session
            }
        )
    }

    /// 把 VM 错误串绑成 Alert 的 isPresented。
    private var errorBinding: Binding<Bool> {
        Binding(  // alert 用布尔
            get: { viewModel.errorMessage != nil },  // 有错就呈现
            set: { if !$0 { viewModel.errorMessage = nil } }  // 点 OK 清掉
        )
    }
}

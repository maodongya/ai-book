import SwiftUI

/// 全屏沉浸阅读：顶栏、快捷键与 spread 主体容器。
struct ReadingSpreadView: View {
    static let defaultPageContentSize = CGSize(width: 340, height: 520)  // 还没量到窗口时的分页尺寸

    @EnvironmentObject private var viewModel: ReadingViewModel  // 分页和退出学习模式
    @ObservedObject private var styleManager = BookStyleManager.shared  // 字体变了要重分页
    @ObservedObject private var settings = AppSettings.shared  // 语言变了刷新 picker

    @State private var pageContentSize: CGSize = .zero  // 当前页内容区，body 量到再写
    @State private var displayedSpreadIndex: Int = 0  // 正在看的摊，动画中先不动 VM
    @State private var flipProgress: CGFloat = 0  // 0 平 1 翻完
    @State private var flipDirection: BookPageTurnDirection?  // 非 nil 表示动画中
    @State private var targetSpreadIndex: Int?  // 动画要落到的摊，进度条用这个
    @State private var isDraggingTurn = false  // 手势还没松
    @State private var isRepaginating = false  // 重切页时先藏内容
    @State private var layoutMode: ReadingLayoutMode = .spread  // 双页或全屏单页
    @State private var turningPageSnapshot: BookPageTurnSnapshot?  // 3D 翻页位图
    @State private var lastPageWidth: CGFloat = defaultPageContentSize.width  // 尺寸没变不重分页
    @State private var lastSpreadHeight: CGFloat = defaultPageContentSize.height  // 同上
    @State private var pageTurnCoordinator = ReadingSpreadPageTurnCoordinator()  // 顶栏按钮调 body 里的 turnPage

    private let commitThreshold: CGFloat = 0.34  // 手势过这才落页，否则弹回
    private let spineWidth: CGFloat = 34  // 书脊占位

    /// 全屏沉浸：顶栏加 spread 容器。
    var body: some View {
        ZStack {
            BookTheme.deskGradient  // 桌面底
                .ignoresSafeArea()  // 铺满
            BookTheme.deskLampGlow  // 台灯光
                .ignoresSafeArea()  // 铺满

            VStack(spacing: 14) {  // 顶栏 + 书
                readingHeader  // 退出、进度、翻页
                    .zIndex(2)  // 盖住翻页层
                spreadBody  // 真正的摊和手势
                    .zIndex(0)  // 在顶栏下
            }
            .padding(24)  // 桌面边
        }
        .background(readingKeyboardShortcuts)  // 隐形快捷键
        .onAppear {
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex  // VM 已按原文页算过摊
            layoutMode = .spread  // 进阅读默认双页
        }
        .onChange(of: viewModel.mode.readingSpreadIndex) { newValue in
            guard flipDirection == nil, layoutMode == .spread else { return }  // 动画中不跟 VM，单页自己管下标
            displayedSpreadIndex = newValue  // 外部跳页（恢复）
        }
        .id(styleManager.revision)  // 字体变整页重建，避免残网格
    }

    /// 手势和 3D 翻页主体。
    private var spreadBody: some View {
        ReadingSpreadSpreadBody(  // 手势和 3D 都在那
            pageContentSize: $pageContentSize,
            displayedSpreadIndex: $displayedSpreadIndex,
            flipProgress: $flipProgress,
            flipDirection: $flipDirection,
            targetSpreadIndex: $targetSpreadIndex,
            isDraggingTurn: $isDraggingTurn,
            isRepaginating: $isRepaginating,
            layoutMode: $layoutMode,
            turningPageSnapshot: $turningPageSnapshot,
            lastPageWidth: $lastPageWidth,
            lastSpreadHeight: $lastSpreadHeight,
            turnCoordinator: pageTurnCoordinator,  // 顶栏共用一份
            commitThreshold: commitThreshold,  // 0.34
            spineWidth: spineWidth  // 34
        )
        .onChange(of: styleManager.revision) { _ in
            guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }  // 没量到等 body
            let sourcePage = currentSourcePageIndex()  // 保住原文位置
            viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)  // 单页和双页切法不同
            applyPosition(fromSourcePage: sourcePage)  // 落到同一原文页
        }
    }

    /// 退出、进度、翻页按钮。
    private var readingHeader: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.mode.exitReadingMode() }) {  // 回学习，滚到对应原文
                BookToolbarCapsuleLabel(  // 和学习模式同一胶囊
                    title: BookL10n.string("mode.learning"),  // 「学习」
                    isProminent: true,  // 主按钮
                    isCompact: false,  // 顶栏够宽
                    isHovering: false  // 不跟悬停
                )
            }
            .buttonStyle(.plain)  // 不要系统边
            .fixedSize()  // 不被挤
            .help(BookL10n.string("help.readingSpreadBack"))  // 提示
            .keyboardShortcut(.escape, modifiers: [])  // 和顶栏同一出口

            VStack(alignment: .leading, spacing: 4) {  // 模式名+文件名
                Text(BookL10n.string("mode.reading"))  // 「阅读」
                    .font(BookTheme.titleFont)  // 标题
                    .foregroundStyle(BookTheme.goldSoft)  // 金字
                Text(viewModel.document.displayFileName)  // 带脏点
                    .font(BookTheme.captionFont)  // 小字
                    .foregroundStyle(BookTheme.chromeMuted)  // 弱
                    .lineLimit(1)  // 太长截
            }
            .layoutPriority(-1)  // 先被压，按钮保住

            Spacer(minLength: 8)  // 把翻页推到右

            layoutModePicker  // 双页/全屏

            BookStatusPill(  // 页码
                title: progressLabel(forSpreadIndex: activeSpreadIndex),  // 动画中看目标摊
                icon: "book.pages"  // 书页标
            )
            .layoutPriority(-1)  // 先被压，按钮保住

            turnButton(systemImage: "chevron.left", enabled: canGoBackward) {  // 上一摊
                pageTurnCoordinator.turnPage?(.backward)  // 走 body 里的动画
            }
            turnButton(systemImage: "chevron.right", enabled: canGoForward) {  // 下一摊
                pageTurnCoordinator.turnPage?(.forward)  // 动画
            }
        }
        .padding(.horizontal, 24)  // 皮条内边
        .padding(.vertical, 16)  // 皮条
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)  // 顶栏皮
                .fill(BookTheme.leatherGradient)  // 皮色
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)  // 顶栏皮
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)  // 细边
                }
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)  // 浮在桌上
        }
    }

    /// 双页或全屏单页。
    private var layoutModePicker: some View {
        let _ = settings.localizationRevision  // 语言变了重算 displayName
        return HStack(spacing: 4) {  // 两个胶囊
            ForEach(ReadingLayoutMode.allCases) { mode in  // spread / fullscreen
                Button {
                    setLayoutMode(mode)  // 立刻重分页
                } label: {
                    Text(mode.displayName)  // 本地化名
                        .font(BookTheme.captionFont.weight(mode == layoutMode ? .semibold : .regular))  // 当前加粗
                        .foregroundStyle(mode == layoutMode ? BookTheme.goldSoft : BookTheme.chromeMuted)  // 当前金字
                        .padding(.horizontal, 10)  // 胶囊
                        .padding(.vertical, 6)  // 胶囊
                        .background {
                            Capsule()  // 底
                                .fill(mode == layoutMode ? BookTheme.buttonFill : Color.clear)  // 当前才填
                                .overlay {
                                    Capsule()  // 底
                                        .strokeBorder(  // 边
                                            mode == layoutMode ? BookTheme.buttonBorder : BookTheme.chromeOverlay.opacity(0.18),  // 当前金边
                                            lineWidth: 1  // 细
                                        )
                                }
                        }
                }
                .buttonStyle(.plain)  // 不要系统边
                .help(mode == .spread ? BookL10n.string("help.readingSpreadLayout") : BookL10n.string("help.readingSinglePage"))  // 两种提示
            }
        }
        .fixedSize()  // 不被挤
    }

    /// 沉浸阅读快捷键，不占布局。
    private var readingKeyboardShortcuts: some View {
        Group {
            Button(BookL10n.string("reading.prevPage")) { pageTurnCoordinator.turnPage?(.backward) }  // 左键
                .keyboardShortcut(.leftArrow, modifiers: [])  // 无修饰
            Button(BookL10n.string("reading.nextPage")) { pageTurnCoordinator.turnPage?(.forward) }  // 右键
                .keyboardShortcut(.rightArrow, modifiers: [])  // 无修饰
            Button(BookL10n.string("mode.learning")) { viewModel.mode.exitReadingMode() }  // Esc
                .keyboardShortcut(.escape, modifiers: [])  // 和顶栏同一出口
            Button(BookL10n.string("layout.spread")) { setLayoutMode(.spread) }  // ⌘⌥1
                .keyboardShortcut("1", modifiers: [.command, .option])  // 双页
            Button(BookL10n.string("layout.fullscreen")) { setLayoutMode(.fullscreen) }  // ⌘⌥2
                .keyboardShortcut("2", modifiers: [.command, .option])  // 单页
        }
        .opacity(0)  // 不可见
        .frame(width: 0, height: 0)  // 不占位
        .allowsHitTesting(false)  // 不挡手势
        .accessibilityHidden(true)  // 不进辅助
    }

    /// 页脚三角。disabled 仍占位避免跳布局。
    private func turnButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {  // 圆钮
            Image(systemName: systemImage)  // 三角
                .font(.system(size: 14, weight: .semibold))  // 小号
                .foregroundStyle(enabled ? BookTheme.goldSoft : BookTheme.chromeMuted.opacity(0.45))  // 不能翻就淡
                .frame(width: 34, height: 34)  // 和书脊接近
                .background {
                    Circle()  // 底
                        .fill(BookTheme.buttonFill)  // 钮色
                        .overlay {
                            Circle()  // 底
                                .strokeBorder(BookTheme.buttonBorder, lineWidth: 1)  // 边
                        }
                }
        }
        .buttonStyle(.plain)  // 不要系统边
        .disabled(!enabled || flipDirection != nil)  // 动画中不能连点
    }

    /// 动画中看目标摊，否则看正在显示的摊。
    private var activeSpreadIndex: Int {
        targetSpreadIndex ?? displayedSpreadIndex  // 翻着看目标，否则当前
    }

    /// 后面还有摊才能向前翻。
    private var canGoForward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadForward(from: displayedSpreadIndex)  // 不是最后一摊
        case .fullscreen:
            return displayedSpreadIndex < max(0, viewModel.mode.readingPageCount - 1)  // 单页看页数
        }
    }

    /// 前面还有摊才能向后翻。
    private var canGoBackward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadBackward(from: displayedSpreadIndex)  // 不是第一摊
        case .fullscreen:
            return displayedSpreadIndex > 0  // 单页第一页不能退
        }
    }

    /// 双页/全屏，立刻重分页。
    private func setLayoutMode(_ mode: ReadingLayoutMode) {
        guard layoutMode != mode else { return }  // 同模式不重切
        let sourcePage = currentSourcePageIndex()  // 保住原文位置
        layoutMode = mode  // 先记下
        guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }  // 没量到等 body
        viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)  // 单页和双页切法不同
        applyPosition(fromSourcePage: sourcePage)  // 落到同一原文页
    }

    /// 当前左页在全文中的页号。
    private func currentSourcePageIndex() -> Int {
        switch layoutMode {
        case .spread:
            return viewModel.mode.leftPageIndex(forSpread: displayedSpreadIndex)  // 这摊的左页
        case .fullscreen:
            return min(max(0, displayedSpreadIndex), max(0, viewModel.mode.readingPageCount - 1))  // 单页下标就是页号
        }
    }

    /// 按原文页落到对应摊。
    private func applyPosition(fromSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, viewModel.mode.readingPageCount - 1))  // 重切后页数可能变
        switch layoutMode {
        case .spread:
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex  // VM 已按原文页算过摊
        case .fullscreen:
            displayedSpreadIndex = clampedSource  // 单页直接用页号
        }
    }

    /// 「第 n / N 页」。
    private func progressLabel(forSpreadIndex spreadIndex: Int) -> String {
        switch layoutMode {
        case .spread:
            return viewModel.mode.readingProgressLabel(spreadIndex: spreadIndex)  // 「第 n–n+1 / N 页」
        case .fullscreen:
            let page = min(max(1, spreadIndex + 1), max(viewModel.mode.readingPageCount, 1))  // 1-based
            let total = max(viewModel.mode.readingPageCount, 1)  // 空书也显示 1
            return BookL10n.format("vm.page.single", page, total)  // 「第 n / N 页」
        }
    }
}

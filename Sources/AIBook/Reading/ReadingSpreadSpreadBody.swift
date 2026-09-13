import SwiftUI

/// 沉浸阅读双页/单页 spread 主体：翻页动画、页内容与手势。
struct ReadingSpreadSpreadBody: View {
    @EnvironmentObject private var viewModel: ReadingViewModel  // 分页和页文

    @Binding var pageContentSize: CGSize  // 给 paginator 的内容区
    @Binding var displayedSpreadIndex: Int  // 正在看的摊
    @Binding var flipProgress: CGFloat  // 0 平 1 翻完
    @Binding var flipDirection: BookPageTurnDirection?  // 非 nil 动画中
    @Binding var targetSpreadIndex: Int?  // 要落到的摊
    @Binding var isDraggingTurn: Bool  // 手势没松
    @Binding var isRepaginating: Bool  // 重切时先藏
    @Binding var layoutMode: ReadingLayoutMode  // 双页或全屏
    @Binding var turningPageSnapshot: BookPageTurnSnapshot?  // 3D 位图
    @Binding var lastPageWidth: CGFloat  // 按钮翻页用上次量到的宽
    @Binding var lastSpreadHeight: CGFloat  // 同上高

    let turnCoordinator: ReadingSpreadPageTurnCoordinator  // 顶栏把 turnPage 接到这
    let commitThreshold: CGFloat  // 手势过这才落页
    let spineWidth: CGFloat  // 书脊宽

    /// 摊的手势、3D 翻页和页内容。
    var body: some View {
        GeometryReader { geometry in  // 量摊的宽高
            let spreadWidth = geometry.size.width  // 整摊
            let spreadHeight = geometry.size.height  // 页高
            let pageWidth = pageWidth(forSpreadWidth: spreadWidth)  // 单页宽，双页要减书脊

            BookInterface.SpreadShell {  // 书壳
                ZStack {
                    if flipDirection != nil, let targetSpreadIndex, flipProgress > 0 {  // 翻起来才露下一摊
                        BookSpreadRevealLayer(progress: flipProgress) {  // 透明度跟进度
                            spreadRow(  // 当前摊
                                spreadIndex: targetSpreadIndex,  // 下一摊或上一摊
                                pageWidth: pageWidth,
                                spreadHeight: spreadHeight,
                                hideLeadingPage: false,  // 底下两页都画
                                hideTrailingPage: false  // 由上层 sheet 挡
                            )
                        }
                    }

                    spreadRow(  // 当前摊
                        spreadIndex: displayedSpreadIndex,  // 还没落下
                        pageWidth: pageWidth,
                        spreadHeight: spreadHeight,
                        hideLeadingPage: shouldHidePage(side: .leading),  // 被 sheet 挡住的藏掉防叠影
                        hideTrailingPage: shouldHidePage(side: .trailing)  // 向前藏右页
                    )

                    if layoutMode == .spread {  // 双页同步 VM，落盘页码
                        spreadSpine(pageWidth: pageWidth, height: spreadHeight)  // 中间一条
                    }

                    if let flipDirection {  // 动画层盖最上
                        turningSheet(  // 3D 网格
                            direction: flipDirection,  // 向前翻右页
                            pageWidth: pageWidth,
                            spreadHeight: spreadHeight
                        )
                    }
                }
            }
            .background {
                Color.clear  // 透明热区
                    .onAppear {
                        lastPageWidth = pageWidth  // 记住，按钮翻页用
                        lastSpreadHeight = spreadHeight  // 记住
                        updatePageContentSize(width: pageWidth, height: spreadHeight)  // 扣页眉页脚再分页
                    }
                    .onChange(of: geometry.size) { _ in  // 窗口拖了
                        lastPageWidth = pageWidth  // 记住，按钮翻页用
                        lastSpreadHeight = spreadHeight  // 记住
                        updatePageContentSize(width: pageWidth, height: spreadHeight)  // 扣页眉页脚再分页
                    }
            }
            .gesture(pageSwipeGesture(pageWidth: pageWidth))  // 拖页
        }
        .onAppear {
            turnCoordinator.turnPage = turnPage  // 顶栏按钮接到这
        }
        .onChange(of: viewModel.document.fileContent) { _ in
            repaginateIfNeeded()  // 按新尺寸切
        }
    }

    @ViewBuilder
    /// 一摊左右页。翻页中盖 turningSheet。
    func spreadRow(
        spreadIndex: Int,
        pageWidth: CGFloat,
        spreadHeight: CGFloat,
        hideLeadingPage: Bool,
        hideTrailingPage: Bool
    ) -> some View {
        if layoutMode == .fullscreen {  // 一页铺满
            pagePanel(  // 背面页
                text: fullscreenPageText(at: spreadIndex),  // 下标当页号
                pageNumber: fullscreenPageNumber(at: spreadIndex),  // 1-based
                pageCaption: nil,  // 全屏不标左右
                side: .leading,  // 左纸色
                width: pageWidth,  // 半宽
                height: spreadHeight,  // 整高
                usesSplitTapNavigation: true  // 左半后退右半前进
            )
            .opacity(hideLeadingPage ? 0 : 1)  // 向后翻藏左页
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)  // 居中
        } else {  // 点左页
            HStack(spacing: 0) {  // 左页空+脊+右页空，对齐真页
                pagePanel(  // 背面页
                    text: pageText(spreadIndex: spreadIndex, side: .leading),  // 左页正文
                    pageNumber: pageNumber(spreadIndex: spreadIndex, side: .leading),  // 奇数页
                    pageCaption: leadingPageCaption,  // 目前 nil
                    side: .leading,  // 左纸色
                    width: pageWidth,  // 半宽
                    height: spreadHeight
                )
                .opacity(hideLeadingPage ? 0 : 1)  // 向后翻藏左页

                Color.clear  // 透明热区
                    .frame(width: spineWidth)  // 34

                pagePanel(  // 背面页
                    text: pageText(spreadIndex: spreadIndex, side: .trailing),  // 右页，没有则空
                    pageNumber: pageNumber(spreadIndex: spreadIndex, side: .trailing),  // 没有右页 nil
                    pageCaption: trailingPageCaption,  // nil
                    side: .trailing,  // 右纸色稍暖
                    width: pageWidth,  // 半宽
                    height: spreadHeight
                )
                .opacity(hideTrailingPage ? 0 : 1)  // 向前翻藏右页
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)  // 居中
        }
    }

    @ViewBuilder
    /// 3D 翻页层，动画完回调卸掉。
    func turningSheet(
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        spreadHeight: CGFloat
    ) -> some View {
        let canvasWidth = layoutMode == .spread ? pageWidth * 2 + spineWidth : pageWidth  // 网格画布
        let pageOriginX: CGFloat = {  // 这一页在画布上的左缘
            guard layoutMode == .spread else { return 0 }  // 单页从 0
            return direction == .forward ? pageWidth + spineWidth : 0  // 向前翻右页，向后翻左页
        }()

        BookPageTurnSheet(  // SceneKit 层
            progress: flipProgress,  // 0...1
            direction: direction,
            pageWidth: pageWidth,
            height: spreadHeight,  // 整高
            canvasWidth: canvasWidth,  // 整摊
            pageOriginX: pageOriginX,  // 铰链基准
            spineOriginX: layoutMode == .spread ? pageWidth : 0,  // 书脊起点
            spineWidth: layoutMode == .spread ? spineWidth : 0,  // 单页 0
            snapshot: turningPageSnapshot  // 打图失败则空层
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)  // 居中
        .allowsHitTesting(false)  // 点按还给页
    }

    @MainActor
    /// 翻页前把当前页打成位图。失败就直接切页。
    func captureTurningPageSnapshot(
        direction: BookPageTurnDirection,
        side: HorizontalEdge,
        pageWidth: CGFloat,
        spreadHeight: CGFloat,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    ) -> BookPageTurnSnapshot? {
        let size = CGSize(width: pageWidth, height: spreadHeight)  // 和真页一样大
        let front = pagePanel(  // 正面就是正在翻的那页
            text: text,
            pageNumber: pageNumber,
            pageCaption: pageCaption,
            side: side,
            width: pageWidth,  // 半宽
            height: spreadHeight,  // 整高
            usesSplitTapNavigation: layoutMode == .fullscreen  // 打图也带分割，避免对不齐
        )
        let reverse = turningPageReverseContent(for: direction)  // 背面：下一摊露出来的那侧
        let back: AnyView = {  // 有正文用页，没有用纸色
            if let reverse {  // 双页能对上背面
                return AnyView(  // 单页或没有背面正文
                    pagePanel(  // 背面页
                        text: reverse.text,  // 目标摊那一侧
                        pageNumber: reverse.pageNumber,  // 页码
                        pageCaption: reverse.pageCaption,  // nil
                        side: reverse.side,  // 纸色
                        width: pageWidth,  // 半宽
                        height: spreadHeight,  // 整高
                        usesSplitTapNavigation: layoutMode == .fullscreen  // 打图也带分割，避免对不齐
                    )
                )
            }
            return AnyView(  // 单页或没有背面正文
                BookPageBackSurface(  // 纸色垫底
                    direction: direction,
                    width: pageWidth,  // 半宽
                    height: spreadHeight
                )
            )
        }()
        return BookPageTurnSnapshotRenderer.render(front: front, back: back, size: size)  // 失败 nil，调用方仍切页
    }

    /// 按页宽判断是否翻页，阈值太小会误触。
    func pageSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)  // 小于 18 当点按
            .onChanged { value in  // 跟手
                guard flipDirection == nil || isDraggingTurn else { return }  // 按钮动画中不接手势

                let width = max(pageWidth, 1)  // 同 onChanged
                if !isDraggingTurn {  // 还没开始，看方向
                    if value.translation.width < -12, canGoForward {  // 左滑向前
                        beginInteractiveTurn(.forward, pageWidth: width, spreadHeight: lastSpreadHeight)  // 抓快照
                    } else if value.translation.width > 12, canGoBackward {  // 右滑向后
                        beginInteractiveTurn(.backward, pageWidth: width, spreadHeight: lastSpreadHeight)  // 抓快照
                    } else {  // 点左页
                        return  // 再等
                    }
                }

                guard isDraggingTurn, flipDirection != nil else { return }  // 没真正开始
                let raw = abs(value.translation.width) / width  // 按页宽归一
                flipProgress = min(1, max(0, raw))  // 夹到 0...1，网格跟手
            }
            .onEnded { value in  // 松手
                defer { isDraggingTurn = false }  // 无论落还是弹，手势结束
                guard isDraggingTurn, flipDirection != nil else { return }  // 没真正开始
                let width = max(pageWidth, 1)  // 同 onChanged
                let progress = min(1, max(0, abs(value.translation.width) / width))  // 松手时进度
                let predicted = min(1, max(0, abs(value.predictedEndTranslation.width) / width))  // 惯性
                let shouldCommit = progress > commitThreshold || predicted > 0.55  // 过阈值或甩得够
                if shouldCommit {  // 落下
                    completeTurn()  // 动画到 1 再切摊
                } else {  // 点左页
                    cancelTurn()  // 动画回 0，摊不变
                }
            }
    }

    /// 页脚三角。disabled 仍占位避免跳布局。
    func turnButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {  // 这份 turnButton 目前没人用，顶栏那份在 SpreadView
            Image(systemName: systemImage)  // 三角
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? BookTheme.goldSoft : BookTheme.chromeMuted.opacity(0.45))
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(BookTheme.buttonFill)
                        .overlay {
                            Circle()
                                .strokeBorder(BookTheme.buttonBorder, lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled || flipDirection != nil)  // 动画中不能点
    }

    /// 单页纸面：正文+页脚。
    func pagePanel(
        text: String,
        pageNumber: Int?,
        pageCaption: String? = nil,
        side: HorizontalEdge,
        width: CGFloat,
        height: CGFloat,
        usesSplitTapNavigation: Bool = false
    ) -> some View {
        VStack(spacing: 0) {  // 眉+纹+文+脚
            HStack(spacing: 8) {  // 页眉
                if let pageCaption {  // 有才画，现在总是 nil
                    Text(pageCaption)  // 例如「译文」
                        .font(BookTheme.captionFont.weight(.semibold))  // 小字
                        .foregroundStyle(BookTheme.leather)  // 皮色
                }
                Spacer()  // 右空
            }
            .padding(.horizontal, 36)  // 页边
            .padding(.top, 10)  // 顶边

            BookInterface.HeaderOrnament()  // 纹样
                .padding(.top, pageCaption == nil ? 8 : 2)  // 没眉多留空

            Text(text)  // 这一页正文
                .font(BookTheme.readingContentFont)  // 阅读字体
                .foregroundStyle(pageCaption == BookL10n.string("page.translationCaption") && text == BookL10n.string("page.noTranslationOnPage") ? BookTheme.inkMuted : BookTheme.ink)  // 缺译文用淡墨
                .lineSpacing(BookTheme.readingLineSpacing)  // 主题行距
                .multilineTextAlignment(.leading)  // 左齐
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // 从顶铺
                .padding(.horizontal, 36)  // 页边
                .padding(.vertical, 24)  // 上下

            pageFooter(pageNumber: pageNumber, side: side, centered: usesSplitTapNavigation)  // 全屏页码居中
        }
        .frame(width: width, height: height)  // 钉死，给打图用
        .bookPaperTexture()  // 纸纹
        .bookPage(pageStyle(for: side))  // 左右纸色不同
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // 页角
        .overlay(alignment: .bottomTrailing) {  // 右页折角
            if side == .trailing, layoutMode == .spread {  // 单页不折
                BookInterface.PageCornerFold()  // 装饰
            }
        }
        .overlay {
            if usesSplitTapNavigation {  // 全屏左右点按
                HStack(spacing: 0) {  // 左页空+脊+右页空，对齐真页
                    Color.clear  // 透明热区
                        .contentShape(Rectangle())  // 整半页可点
                        .onTapGesture {  // 双页：右页向前左页向后
                            guard flipDirection == nil else { return }  // 动画中不连翻
                            turnPage(.backward)  // 向后
                        }
                    Color.clear  // 透明热区
                        .contentShape(Rectangle())  // 整半页可点
                        .onTapGesture {  // 双页：右页向前左页向后
                            guard flipDirection == nil else { return }  // 动画中不连翻
                            turnPage(.forward)  // 向前
                        }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))  // 双页整页可点
        .onTapGesture {  // 双页：右页向前左页向后
            guard flipDirection == nil, !usesSplitTapNavigation else { return }  // 全屏走上下 overlay
            if side == .trailing {  // 点右页
                turnPage(.forward)  // 向前
            } else {  // 点左页
                turnPage(.backward)  // 向后
            }
        }
    }

    /// 页码。centered 给全屏。
    func pageFooter(pageNumber: Int?, side: HorizontalEdge, centered: Bool = false) -> some View {
        HStack {
            if centered {  // 全屏：两边 spacer 把页码挤中间
                Spacer()  // 右空
            } else if side == .leading {  // 双页左页标在左
                BookInterface.PageMark(label: BookInterface.leftPageMark)  // 左页记号
            }
            Spacer()  // 右空
            if let pageNumber {  // 没有右页就不画号
                Text("\(pageNumber)")  // 1-based
                    .font(BookTheme.captionFont.monospacedDigit())  // 数字齐
                    .foregroundStyle(BookTheme.inkSecondary)  // 淡
            }
            Spacer()  // 右空
            if centered {  // 全屏：两边 spacer 把页码挤中间
                Spacer()  // 右空
            } else if side == .trailing {  // 双页右页标在右
                BookInterface.PageMark(label: BookInterface.rightPageMark)  // 右页记号
            }
        }
        .padding(.horizontal, 28)  // 脚边
        .padding(.vertical, 10)  // 脚高大约 44 扣掉用
        .background {
            Rectangle()  // 脊
                .fill(BookTheme.pageEdge.opacity(0.22))  // 略深
                .overlay(alignment: .top) { Divider() }  // 和正文分界
        }
    }

    /// 两页中间的书脊阴影。
    func spreadSpine(pageWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {  // 左页空+脊+右页空，对齐真页
            Color.clear.frame(width: pageWidth)  // 右半
            ZStack(alignment: .top) {  // 脊上挂丝带
                bookSpine  // 渐变条
                BookInterface.BookmarkRibbon()  // 装饰
            }
            Color.clear.frame(width: pageWidth)  // 右半
        }
        .frame(width: pageWidth * 2 + spineWidth, height: height)  // 和摊一样宽
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)  // 居中
        .allowsHitTesting(false)  // 点按还给页
    }

    /// 摊中间的书脊装饰。
    var bookSpine: some View {
        Rectangle()  // 脊
            .fill(
                LinearGradient(  // 中间深两边浅
                    colors: [BookTheme.spineLight, BookTheme.spineDark, BookTheme.spineLight.opacity(0.8)],  // 凹槽
                    startPoint: .leading,  // 横渐变
                    endPoint: .trailing  // 横
                )
            )
            .frame(width: spineWidth)  // 34
            .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 0)  // 压在纸上
    }

    /// 动画中看目标摊，否则看正在显示的摊。
    var activeSpreadIndex: Int {
        targetSpreadIndex ?? displayedSpreadIndex  // 翻着看目标
    }

    /// 后面还有摊或单页才能向前翻。
    var canGoForward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadForward(from: displayedSpreadIndex)  // 不是最后摊
        case .fullscreen:
            return displayedSpreadIndex < max(0, viewModel.mode.readingPageCount - 1)  // 单页
        }
    }

    /// 前面还有摊或单页才能向后翻。
    var canGoBackward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadBackward(from: displayedSpreadIndex)  // 不是第一摊
        case .fullscreen:
            return displayedSpreadIndex > 0  // 单页
        }
    }

    /// 这一摊这一侧的正文。越界空串。
    func pageText(spreadIndex: Int, side: HorizontalEdge) -> String {
        switch side {
        case .leading:
            return viewModel.mode.readingPageText(at: viewModel.mode.leftPageIndex(forSpread: spreadIndex))  // 左页下标
        case .trailing:
            if let index = viewModel.mode.rightPageIndex(forSpread: spreadIndex) {  // 最后一摊可能没有右页
                return viewModel.mode.readingPageText(at: index)  // 右页
            }
            return ""  // 空页仍占位
        }
    }

    /// 给人看的页码，从 1。没有右页回 nil。
    func pageNumber(spreadIndex: Int, side: HorizontalEdge) -> Int? {
        guard viewModel.mode.readingPageCount > 0 else { return nil }  // 空书不画号
        switch side {
        case .leading:
            return viewModel.mode.leftPageIndex(forSpread: spreadIndex) + 1  // 1-based
        case .trailing:
            guard let index = viewModel.mode.rightPageIndex(forSpread: spreadIndex) else { return nil }  // 没右页
            return index + 1  // 1-based
        }
    }

    /// 全屏第 N 页正文。
    func fullscreenPageText(at pageIndex: Int) -> String {
        viewModel.mode.readingPageText(at: min(max(0, pageIndex), max(0, viewModel.mode.readingPageCount - 1)))  // 夹进页数
    }

    /// 全屏页码。
    func fullscreenPageNumber(at pageIndex: Int) -> Int? {
        guard viewModel.mode.readingPageCount > 0 else { return nil }  // 空书不画号
        return min(max(1, pageIndex + 1), viewModel.mode.readingPageCount)  // 1...count
    }

    /// 窗口变了记下尺寸，需要时重分页。
    func updatePageContentSize(width: CGFloat, height: CGFloat) {
        let footerHeight: CGFloat = 44  // 和 pageFooter 大致一致
        let headerHeight: CGFloat = 28  // 纹样+眉
        let newSize = CGSize(  // 给 paginator 的可排字区域
            width: width,  // 单页内容宽
            height: max(120, height - footerHeight - headerHeight)  // 太矮也留 120
        )
        guard abs(newSize.width - pageContentSize.width) > 2  // 小于 2pt 当抖
            || abs(newSize.height - pageContentSize.height) > 2 else { return }  // 不重切
        pageContentSize = newSize  // 写回父
        repaginateIfNeeded()  // 按新尺寸切
    }

    /// 尺寸变过才重切。
    func repaginateIfNeeded(restoreSourcePage: Int? = nil) {
        guard !isRepaginating else { return }  // 重入直接回
        guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }  // 还没量到
        let sourcePage = restoreSourcePage ?? currentSourcePageIndex()  // 保住原文位置
        isRepaginating = true  // 藏一下避免闪旧页
        viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)  // 重切
        applyPosition(fromSourcePage: sourcePage)  // 落到同一原文页
        DispatchQueue.main.async {  // 下一拍再显示
            isRepaginating = false  // 解开
        }
    }

    /// 手势翻页开始，先抓快照。
    func beginInteractiveTurn(
        _ direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        spreadHeight: CGFloat
    ) {
        switch direction {
        case .forward:
            guard canGoForward else { return }  // 到头不抓图
            targetSpreadIndex = displayedSpreadIndex + 1  // 下一摊
        case .backward:
            guard canGoBackward else { return }  // 开头
            targetSpreadIndex = displayedSpreadIndex - 1  // 上一摊
        }

        let content = turningPageContent(for: direction)  // 正面文案
        turningPageSnapshot = captureTurningPageSnapshot(  // 打图，失败仍继续翻（无 3D）
            direction: direction,
            side: content.side,  // 哪一页在翻
            pageWidth: pageWidth,
            spreadHeight: spreadHeight,
            text: content.text,  // 正面正文
            pageNumber: content.pageNumber,  // 正面页码
            pageCaption: content.pageCaption  // nil
        )

        flipDirection = direction  // 开始动画
        isDraggingTurn = true  // 跟手
        flipProgress = 0  // 卸动画
    }

    /// 翻页正面位图用的正文。
    func turningPageContent(for direction: BookPageTurnDirection) -> (
        side: HorizontalEdge,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    ) {
        switch layoutMode {
        case .fullscreen:
            return (  // 向后：背面是上一摊右页
                .leading,  // 翻过去看见左
                fullscreenPageText(at: displayedSpreadIndex),  // 当前页文
                fullscreenPageNumber(at: displayedSpreadIndex),  // 页码
                nil  // 左页眉预留，现在不用
            )
        case .spread:
            switch direction {
            case .forward:
                return (  // 向后：背面是上一摊右页
                    .trailing,  // 翻回去看见右
                    pageText(spreadIndex: displayedSpreadIndex, side: .trailing),  // 当前右页
                    pageNumber(spreadIndex: displayedSpreadIndex, side: .trailing),  // 页码
                    trailingPageCaption  // nil
                )
            case .backward:
                return (  // 向后：背面是上一摊右页
                    .leading,  // 翻过去看见左
                    pageText(spreadIndex: displayedSpreadIndex, side: .leading),  // 当前左页
                    pageNumber(spreadIndex: displayedSpreadIndex, side: .leading),  // 页码
                    leadingPageCaption  // nil
                )
            }
        }
    }

    /// 翻页背面。
    func turningPageReverseContent(for direction: BookPageTurnDirection) -> (
        side: HorizontalEdge,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    )? {
        guard layoutMode == .spread, let targetSpreadIndex else { return nil }  // 单页背面用纸色
        switch direction {
        case .forward:
            return (  // 向后：背面是上一摊右页
                .leading,  // 翻过去看见左
                pageText(spreadIndex: targetSpreadIndex, side: .leading),  // 下一摊左
                pageNumber(spreadIndex: targetSpreadIndex, side: .leading),  // 页码
                leadingPageCaption  // nil
            )
        case .backward:
            return (  // 向后：背面是上一摊右页
                .trailing,  // 翻回去看见右
                pageText(spreadIndex: targetSpreadIndex, side: .trailing),  // 上一摊右
                pageNumber(spreadIndex: targetSpreadIndex, side: .trailing),  // 页码
                trailingPageCaption  // nil
            )
        }
    }

    /// 动画翻一页。
    func turnPage(_ direction: BookPageTurnDirection) {
        guard flipDirection == nil else { return }  // 动画中不连翻
        beginInteractiveTurn(direction, pageWidth: lastPageWidth, spreadHeight: lastSpreadHeight)  // 抓图
        guard flipDirection != nil else { return }  // 到头则 begin 没设方向

        withAnimation(.bookPageTurn) {  // 弹回
            flipProgress = 1  // 落
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {  // 等弹回
            finishTurnState()  // 切摊
        }
    }

    /// 动画结束落页。
    func completeTurn() {
        withAnimation(.bookPageTurn) {  // 弹回
            flipProgress = 1  // 落
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {  // 等弹回
            finishTurnState()  // 切摊
        }
    }

    /// 手势取消，页回到原摊。
    func cancelTurn() {
        withAnimation(.bookPageTurn) {  // 弹回
            flipProgress = 0  // 卸动画
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {  // 等弹回
            flipDirection = nil  // 允许下一翻
            targetSpreadIndex = nil  // 不切摊
            flipProgress = 0  // 卸动画
            turningPageSnapshot = nil  // 释图
        }
    }

    /// 清快照和进度。
    func finishTurnState() {
        if let targetSpreadIndex {  // 有目标才切
            displayedSpreadIndex = targetSpreadIndex  // 先本地
            if layoutMode == .spread {  // 双页同步 VM，落盘页码
                viewModel.mode.readingSpreadIndex = targetSpreadIndex  // 会话记住
            }
        }
        flipProgress = 0  // 卸动画
        flipDirection = nil  // 允许下一翻
        self.targetSpreadIndex = nil  // 进度条回当前
        isDraggingTurn = false  // 清手势
        turningPageSnapshot = nil  // 释图
    }

    /// 左页页眉；默认没有。
    var leadingPageCaption: String? { nil }

    /// 右页页眉；默认没有。
    var trailingPageCaption: String? { nil }

    /// 当前页内容宽。
    func pageWidth(forSpreadWidth spreadWidth: CGFloat) -> CGFloat {
        switch layoutMode {
        case .spread:
            return max(0, (spreadWidth - spineWidth) / 2)  // 两页均分
        case .fullscreen:
            return max(0, spreadWidth)  // 单页全宽
        }
    }

    /// 这一侧纸色。
    func pageStyle(for side: HorizontalEdge) -> Color {
        switch layoutMode {
        case .spread:
            return side == .leading ? BookTheme.pageLeft : BookTheme.pageRight  // 右页略暖
        case .fullscreen:
            return BookTheme.pageLeft  // 单页统一左纸色
        }
    }

    /// 当前左页在全文中的页号。
    func currentSourcePageIndex() -> Int {
        switch layoutMode {
        case .spread:
            return viewModel.mode.leftPageIndex(forSpread: displayedSpreadIndex)  // 这摊左页
        case .fullscreen:
            return min(max(0, displayedSpreadIndex), max(0, viewModel.mode.readingPageCount - 1))  // 单页下标即页号
        }
    }

    /// 按原文页落到对应摊。
    func applyPosition(fromSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, viewModel.mode.readingPageCount - 1))  // 重切后页数可能少
        switch layoutMode {
        case .spread:
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex  // VM 已按原文页算摊
        case .fullscreen:
            displayedSpreadIndex = clampedSource  // 单页用页号
        }
    }

    /// 翻页动画中藏被挡住的那页。
    func shouldHidePage(side: HorizontalEdge) -> Bool {
        guard flipDirection != nil else { return false }  // 没动画不藏
        switch layoutMode {
        case .spread:
            return side == .leading ? flipDirection == .backward : flipDirection == .forward  // 翻哪边藏哪边
        case .fullscreen:
            return side == .leading  // 单页只有一页，翻就藏，露底下目标
        }
    }
}

/// 顶栏翻页按钮与 spread 主体共享翻页入口。
final class ReadingSpreadPageTurnCoordinator {
    var turnPage: ((BookPageTurnDirection) -> Void)?  // onAppear 接到 body.turnPage
}

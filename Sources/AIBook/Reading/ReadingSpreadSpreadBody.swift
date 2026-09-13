import SwiftUI

/// 沉浸阅读双页/单页 spread 主体：翻页动画、页内容与手势。
struct ReadingSpreadSpreadBody: View {
    @EnvironmentObject private var viewModel: ReadingViewModel

    @Binding var pageContentSize: CGSize
    @Binding var displayedSpreadIndex: Int
    @Binding var flipProgress: CGFloat
    @Binding var flipDirection: BookPageTurnDirection?
    @Binding var targetSpreadIndex: Int?
    @Binding var isDraggingTurn: Bool
    @Binding var isRepaginating: Bool
    @Binding var layoutMode: ReadingLayoutMode
    @Binding var turningPageSnapshot: BookPageTurnSnapshot?
    @Binding var lastPageWidth: CGFloat
    @Binding var lastSpreadHeight: CGFloat

    let turnCoordinator: ReadingSpreadPageTurnCoordinator
    let commitThreshold: CGFloat
    let spineWidth: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let spreadWidth = geometry.size.width
            let spreadHeight = geometry.size.height
            let pageWidth = pageWidth(forSpreadWidth: spreadWidth)

            BookInterface.SpreadShell {
                ZStack {
                    if flipDirection != nil, let targetSpreadIndex, flipProgress > 0 {
                        BookSpreadRevealLayer(progress: flipProgress) {
                            spreadRow(
                                spreadIndex: targetSpreadIndex,
                                pageWidth: pageWidth,
                                spreadHeight: spreadHeight,
                                hideLeadingPage: false,
                                hideTrailingPage: false
                            )
                        }
                    }

                    spreadRow(
                        spreadIndex: displayedSpreadIndex,
                        pageWidth: pageWidth,
                        spreadHeight: spreadHeight,
                        hideLeadingPage: shouldHidePage(side: .leading),
                        hideTrailingPage: shouldHidePage(side: .trailing)
                    )

                    if layoutMode == .spread {
                        spreadSpine(pageWidth: pageWidth, height: spreadHeight)
                    }

                    if let flipDirection {
                        turningSheet(
                            direction: flipDirection,
                            pageWidth: pageWidth,
                            spreadHeight: spreadHeight
                        )
                    }
                }
            }
            .background {
                Color.clear
                    .onAppear {
                        lastPageWidth = pageWidth
                        lastSpreadHeight = spreadHeight
                        updatePageContentSize(width: pageWidth, height: spreadHeight)
                    }
                    .onChange(of: geometry.size) { _ in
                        lastPageWidth = pageWidth
                        lastSpreadHeight = spreadHeight
                        updatePageContentSize(width: pageWidth, height: spreadHeight)
                    }
            }
            .gesture(pageSwipeGesture(pageWidth: pageWidth))
        }
        .onAppear {
            turnCoordinator.turnPage = turnPage
        }
        .onChange(of: viewModel.document.fileContent) { _ in
            repaginateIfNeeded()
        }
    }

    @ViewBuilder
    func spreadRow(
        spreadIndex: Int,
        pageWidth: CGFloat,
        spreadHeight: CGFloat,
        hideLeadingPage: Bool,
        hideTrailingPage: Bool
    ) -> some View {
        if layoutMode == .fullscreen {
            pagePanel(
                text: fullscreenPageText(at: spreadIndex),
                pageNumber: fullscreenPageNumber(at: spreadIndex),
                pageCaption: nil,
                side: .leading,
                width: pageWidth,
                height: spreadHeight,
                usesSplitTapNavigation: true
            )
            .opacity(hideLeadingPage ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            HStack(spacing: 0) {
                pagePanel(
                    text: pageText(spreadIndex: spreadIndex, side: .leading),
                    pageNumber: pageNumber(spreadIndex: spreadIndex, side: .leading),
                    pageCaption: leadingPageCaption,
                    side: .leading,
                    width: pageWidth,
                    height: spreadHeight
                )
                .opacity(hideLeadingPage ? 0 : 1)

                Color.clear
                    .frame(width: spineWidth)

                pagePanel(
                    text: pageText(spreadIndex: spreadIndex, side: .trailing),
                    pageNumber: pageNumber(spreadIndex: spreadIndex, side: .trailing),
                    pageCaption: trailingPageCaption,
                    side: .trailing,
                    width: pageWidth,
                    height: spreadHeight
                )
                .opacity(hideTrailingPage ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    func turningSheet(
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        spreadHeight: CGFloat
    ) -> some View {
        let canvasWidth = layoutMode == .spread ? pageWidth * 2 + spineWidth : pageWidth
        let pageOriginX: CGFloat = {
            guard layoutMode == .spread else { return 0 }
            return direction == .forward ? pageWidth + spineWidth : 0
        }()

        BookPageTurnSheet(
            progress: flipProgress,
            direction: direction,
            pageWidth: pageWidth,
            height: spreadHeight,
            canvasWidth: canvasWidth,
            pageOriginX: pageOriginX,
            spineOriginX: layoutMode == .spread ? pageWidth : 0,
            spineWidth: layoutMode == .spread ? spineWidth : 0,
            snapshot: turningPageSnapshot
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }

    @MainActor
    func captureTurningPageSnapshot(
        direction: BookPageTurnDirection,
        side: HorizontalEdge,
        pageWidth: CGFloat,
        spreadHeight: CGFloat,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    ) -> BookPageTurnSnapshot? {
        let size = CGSize(width: pageWidth, height: spreadHeight)
        let front = pagePanel(
            text: text,
            pageNumber: pageNumber,
            pageCaption: pageCaption,
            side: side,
            width: pageWidth,
            height: spreadHeight,
            usesSplitTapNavigation: layoutMode == .fullscreen
        )
        let reverse = turningPageReverseContent(for: direction)
        let back: AnyView = {
            if let reverse {
                return AnyView(
                    pagePanel(
                        text: reverse.text,
                        pageNumber: reverse.pageNumber,
                        pageCaption: reverse.pageCaption,
                        side: reverse.side,
                        width: pageWidth,
                        height: spreadHeight,
                        usesSplitTapNavigation: layoutMode == .fullscreen
                    )
                )
            }
            return AnyView(
                BookPageBackSurface(
                    direction: direction,
                    width: pageWidth,
                    height: spreadHeight
                )
            )
        }()
        return BookPageTurnSnapshotRenderer.render(front: front, back: back, size: size)
    }

    func pageSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard flipDirection == nil || isDraggingTurn else { return }

                let width = max(pageWidth, 1)
                if !isDraggingTurn {
                    if value.translation.width < -12, canGoForward {
                        beginInteractiveTurn(.forward, pageWidth: width, spreadHeight: lastSpreadHeight)
                    } else if value.translation.width > 12, canGoBackward {
                        beginInteractiveTurn(.backward, pageWidth: width, spreadHeight: lastSpreadHeight)
                    } else {
                        return
                    }
                }

                guard isDraggingTurn, flipDirection != nil else { return }
                let raw = abs(value.translation.width) / width
                flipProgress = min(1, max(0, raw))
            }
            .onEnded { value in
                defer { isDraggingTurn = false }
                guard isDraggingTurn, flipDirection != nil else { return }
                let width = max(pageWidth, 1)
                let progress = min(1, max(0, abs(value.translation.width) / width))
                let predicted = min(1, max(0, abs(value.predictedEndTranslation.width) / width))
                let shouldCommit = progress > commitThreshold || predicted > 0.55
                if shouldCommit {
                    completeTurn()
                } else {
                    cancelTurn()
                }
            }
    }

    func turnButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
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
        .disabled(!enabled || flipDirection != nil)
    }

    func pagePanel(
        text: String,
        pageNumber: Int?,
        pageCaption: String? = nil,
        side: HorizontalEdge,
        width: CGFloat,
        height: CGFloat,
        usesSplitTapNavigation: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let pageCaption {
                    Text(pageCaption)
                        .font(BookTheme.captionFont.weight(.semibold))
                        .foregroundStyle(BookTheme.leather)
                }
                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)

            BookInterface.HeaderOrnament()
                .padding(.top, pageCaption == nil ? 8 : 2)

            Text(text)
                .font(BookTheme.readingContentFont)
                .foregroundStyle(pageCaption == BookL10n.string("page.translationCaption") && text == BookL10n.string("page.noTranslationOnPage") ? BookTheme.inkMuted : BookTheme.ink)
                .lineSpacing(BookTheme.readingLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 36)
                .padding(.vertical, 24)

            pageFooter(pageNumber: pageNumber, side: side, centered: usesSplitTapNavigation)
        }
        .frame(width: width, height: height)
        .bookPaperTexture()
        .bookPage(pageStyle(for: side))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if side == .trailing, layoutMode == .spread {
                BookInterface.PageCornerFold()
            }
        }
        .overlay {
            if usesSplitTapNavigation {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard flipDirection == nil else { return }
                            turnPage(.backward)
                        }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard flipDirection == nil else { return }
                            turnPage(.forward)
                        }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            guard flipDirection == nil, !usesSplitTapNavigation else { return }
            if side == .trailing {
                turnPage(.forward)
            } else {
                turnPage(.backward)
            }
        }
    }

    func pageFooter(pageNumber: Int?, side: HorizontalEdge, centered: Bool = false) -> some View {
        HStack {
            if centered {
                Spacer()
            } else if side == .leading {
                BookInterface.PageMark(label: BookInterface.leftPageMark)
            }
            Spacer()
            if let pageNumber {
                Text("\(pageNumber)")
                    .font(BookTheme.captionFont.monospacedDigit())
                    .foregroundStyle(BookTheme.inkSecondary)
            }
            Spacer()
            if centered {
                Spacer()
            } else if side == .trailing {
                BookInterface.PageMark(label: BookInterface.rightPageMark)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(BookTheme.pageEdge.opacity(0.22))
                .overlay(alignment: .top) { Divider() }
        }
    }

    func spreadSpine(pageWidth: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: pageWidth)
            ZStack(alignment: .top) {
                bookSpine
                BookInterface.BookmarkRibbon()
            }
            Color.clear.frame(width: pageWidth)
        }
        .frame(width: pageWidth * 2 + spineWidth, height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }

    var bookSpine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [BookTheme.spineLight, BookTheme.spineDark, BookTheme.spineLight.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: spineWidth)
            .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 0)
    }

    var activeSpreadIndex: Int {
        targetSpreadIndex ?? displayedSpreadIndex
    }

    var canGoForward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadForward(from: displayedSpreadIndex)
        case .fullscreen:
            return displayedSpreadIndex < max(0, viewModel.mode.readingPageCount - 1)
        }
    }

    var canGoBackward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadBackward(from: displayedSpreadIndex)
        case .fullscreen:
            return displayedSpreadIndex > 0
        }
    }

    func pageText(spreadIndex: Int, side: HorizontalEdge) -> String {
        switch side {
        case .leading:
            return viewModel.mode.readingPageText(at: viewModel.mode.leftPageIndex(forSpread: spreadIndex))
        case .trailing:
            if let index = viewModel.mode.rightPageIndex(forSpread: spreadIndex) {
                return viewModel.mode.readingPageText(at: index)
            }
            return ""
        }
    }

    func pageNumber(spreadIndex: Int, side: HorizontalEdge) -> Int? {
        guard viewModel.mode.readingPageCount > 0 else { return nil }
        switch side {
        case .leading:
            return viewModel.mode.leftPageIndex(forSpread: spreadIndex) + 1
        case .trailing:
            guard let index = viewModel.mode.rightPageIndex(forSpread: spreadIndex) else { return nil }
            return index + 1
        }
    }

    func fullscreenPageText(at pageIndex: Int) -> String {
        viewModel.mode.readingPageText(at: min(max(0, pageIndex), max(0, viewModel.mode.readingPageCount - 1)))
    }

    func fullscreenPageNumber(at pageIndex: Int) -> Int? {
        guard viewModel.mode.readingPageCount > 0 else { return nil }
        return min(max(1, pageIndex + 1), viewModel.mode.readingPageCount)
    }

    func updatePageContentSize(width: CGFloat, height: CGFloat) {
        let footerHeight: CGFloat = 44
        let headerHeight: CGFloat = 28
        let newSize = CGSize(
            width: width,
            height: max(120, height - footerHeight - headerHeight)
        )
        guard abs(newSize.width - pageContentSize.width) > 2
            || abs(newSize.height - pageContentSize.height) > 2 else { return }
        pageContentSize = newSize
        repaginateIfNeeded()
    }

    func repaginateIfNeeded(restoreSourcePage: Int? = nil) {
        guard !isRepaginating else { return }
        guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }
        let sourcePage = restoreSourcePage ?? currentSourcePageIndex()
        isRepaginating = true
        viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)
        applyPosition(fromSourcePage: sourcePage)
        DispatchQueue.main.async {
            isRepaginating = false
        }
    }

    func beginInteractiveTurn(
        _ direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        spreadHeight: CGFloat
    ) {
        switch direction {
        case .forward:
            guard canGoForward else { return }
            targetSpreadIndex = displayedSpreadIndex + 1
        case .backward:
            guard canGoBackward else { return }
            targetSpreadIndex = displayedSpreadIndex - 1
        }

        let content = turningPageContent(for: direction)
        turningPageSnapshot = captureTurningPageSnapshot(
            direction: direction,
            side: content.side,
            pageWidth: pageWidth,
            spreadHeight: spreadHeight,
            text: content.text,
            pageNumber: content.pageNumber,
            pageCaption: content.pageCaption
        )

        flipDirection = direction
        isDraggingTurn = true
        flipProgress = 0
    }

    func turningPageContent(for direction: BookPageTurnDirection) -> (
        side: HorizontalEdge,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    ) {
        switch layoutMode {
        case .fullscreen:
            return (
                .leading,
                fullscreenPageText(at: displayedSpreadIndex),
                fullscreenPageNumber(at: displayedSpreadIndex),
                nil
            )
        case .spread:
            switch direction {
            case .forward:
                return (
                    .trailing,
                    pageText(spreadIndex: displayedSpreadIndex, side: .trailing),
                    pageNumber(spreadIndex: displayedSpreadIndex, side: .trailing),
                    trailingPageCaption
                )
            case .backward:
                return (
                    .leading,
                    pageText(spreadIndex: displayedSpreadIndex, side: .leading),
                    pageNumber(spreadIndex: displayedSpreadIndex, side: .leading),
                    leadingPageCaption
                )
            }
        }
    }

    func turningPageReverseContent(for direction: BookPageTurnDirection) -> (
        side: HorizontalEdge,
        text: String,
        pageNumber: Int?,
        pageCaption: String?
    )? {
        guard layoutMode == .spread, let targetSpreadIndex else { return nil }
        switch direction {
        case .forward:
            return (
                .leading,
                pageText(spreadIndex: targetSpreadIndex, side: .leading),
                pageNumber(spreadIndex: targetSpreadIndex, side: .leading),
                leadingPageCaption
            )
        case .backward:
            return (
                .trailing,
                pageText(spreadIndex: targetSpreadIndex, side: .trailing),
                pageNumber(spreadIndex: targetSpreadIndex, side: .trailing),
                trailingPageCaption
            )
        }
    }

    func turnPage(_ direction: BookPageTurnDirection) {
        guard flipDirection == nil else { return }
        beginInteractiveTurn(direction, pageWidth: lastPageWidth, spreadHeight: lastSpreadHeight)
        guard flipDirection != nil else { return }

        withAnimation(.bookPageTurn) {
            flipProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            finishTurnState()
        }
    }

    func completeTurn() {
        withAnimation(.bookPageTurn) {
            flipProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            finishTurnState()
        }
    }

    func cancelTurn() {
        withAnimation(.bookPageTurn) {
            flipProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            flipDirection = nil
            targetSpreadIndex = nil
            flipProgress = 0
            turningPageSnapshot = nil
        }
    }

    func finishTurnState() {
        if let targetSpreadIndex {
            displayedSpreadIndex = targetSpreadIndex
            if layoutMode == .spread {
                viewModel.mode.readingSpreadIndex = targetSpreadIndex
            }
        }
        flipProgress = 0
        flipDirection = nil
        self.targetSpreadIndex = nil
        isDraggingTurn = false
        turningPageSnapshot = nil
    }

    var leadingPageCaption: String? { nil }

    var trailingPageCaption: String? { nil }

    func pageWidth(forSpreadWidth spreadWidth: CGFloat) -> CGFloat {
        switch layoutMode {
        case .spread:
            return max(0, (spreadWidth - spineWidth) / 2)
        case .fullscreen:
            return max(0, spreadWidth)
        }
    }

    func pageStyle(for side: HorizontalEdge) -> Color {
        switch layoutMode {
        case .spread:
            return side == .leading ? BookTheme.pageLeft : BookTheme.pageRight
        case .fullscreen:
            return BookTheme.pageLeft
        }
    }

    func currentSourcePageIndex() -> Int {
        switch layoutMode {
        case .spread:
            return viewModel.mode.leftPageIndex(forSpread: displayedSpreadIndex)
        case .fullscreen:
            return min(max(0, displayedSpreadIndex), max(0, viewModel.mode.readingPageCount - 1))
        }
    }

    func applyPosition(fromSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, viewModel.mode.readingPageCount - 1))
        switch layoutMode {
        case .spread:
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex
        case .fullscreen:
            displayedSpreadIndex = clampedSource
        }
    }

    func shouldHidePage(side: HorizontalEdge) -> Bool {
        guard flipDirection != nil else { return false }
        switch layoutMode {
        case .spread:
            return side == .leading ? flipDirection == .backward : flipDirection == .forward
        case .fullscreen:
            return side == .leading
        }
    }
}

/// 顶栏翻页按钮与 spread 主体共享翻页入口。
final class ReadingSpreadPageTurnCoordinator {
    var turnPage: ((BookPageTurnDirection) -> Void)?
}

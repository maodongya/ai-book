import SwiftUI

/// Full-screen immersive reading: left/right paginated spread with page-turn animation.
struct ReadingSpreadView: View {
    static let defaultPageContentSize = CGSize(width: 340, height: 520)

    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var styleManager = BookStyleManager.shared

    @State private var pageContentSize: CGSize = .zero
    @State private var displayedSpreadIndex: Int = 0
    @State private var flipProgress: CGFloat = 0
    @State private var flipDirection: BookPageTurnDirection?
    @State private var targetSpreadIndex: Int?
    @State private var isDraggingTurn = false
    @State private var isRepaginating = false

    private let commitThreshold: CGFloat = 0.34

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()
            BookTheme.deskLampGlow
                .ignoresSafeArea()

            VStack(spacing: 14) {
                readingHeader
                    .zIndex(2)
                spreadBody
                    .zIndex(0)
            }
            .padding(24)
        }
        .background(readingKeyboardShortcuts)
        .onAppear {
            displayedSpreadIndex = viewModel.readingSpreadIndex
            repaginateIfNeeded()
        }
        .onChange(of: viewModel.fileContent) { _ in
            repaginateIfNeeded()
        }
        .onChange(of: viewModel.readingSpreadIndex) { newValue in
            guard flipDirection == nil else { return }
            displayedSpreadIndex = newValue
        }
        .onChange(of: styleManager.revision) { _ in
            repaginateIfNeeded()
        }
        .onChange(of: viewModel.readingComparisonEnabled) { _ in
            repaginateIfNeeded()
        }
        .id(styleManager.revision)
    }

    private var readingHeader: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.exitReadingMode() }) {
                BookToolbarCapsuleLabel(
                    title: "学习模式",
                    isProminent: true,
                    isCompact: false,
                    isHovering: false
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("返回学习模式：讲解、翻译与 AI 助手")
            .keyboardShortcut(.escape, modifiers: [])

            VStack(alignment: .leading, spacing: 4) {
                Text("阅读模式")
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text(viewModel.displayFileName)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.chromeMuted)
                    .lineLimit(1)
            }
            .layoutPriority(-1)

            Spacer(minLength: 8)

            if viewModel.showsReadingComparisonToggle {
                Toggle("对照翻页", isOn: $viewModel.readingComparisonEnabled)
                    .toggleStyle(.switch)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.chromeMuted)
                    .disabled(!viewModel.canUseReadingComparison)
                    .help(viewModel.readingComparisonHelp)
                    .fixedSize()
            }

            BookStatusPill(
                title: viewModel.readingProgressLabel(spreadIndex: activeSpreadIndex),
                icon: "book.pages"
            )
            .layoutPriority(-1)

            turnButton(systemImage: "chevron.left", enabled: canGoBackward) {
                turnPage(.backward)
            }
            turnButton(systemImage: "chevron.right", enabled: canGoForward) {
                turnPage(.forward)
            }
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

    private var spreadBody: some View {
        GeometryReader { geometry in
            let spreadWidth = geometry.size.width
            let spreadHeight = geometry.size.height
            let pageWidth = max(0, (spreadWidth - 34) / 2)

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
                        hideLeadingPage: flipDirection == .backward && flipProgress > 0,
                        hideTrailingPage: flipDirection == .forward && flipProgress > 0
                    )

                    if let flipDirection, flipProgress > 0 {
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
                        updatePageContentSize(width: pageWidth, height: spreadHeight)
                    }
                    .onChange(of: geometry.size) { _ in
                        updatePageContentSize(width: pageWidth, height: spreadHeight)
                    }
            }
            .gesture(pageSwipeGesture(pageWidth: pageWidth))
        }
    }

    @ViewBuilder
    private func spreadRow(
        spreadIndex: Int,
        pageWidth: CGFloat,
        spreadHeight: CGFloat,
        hideLeadingPage: Bool,
        hideTrailingPage: Bool
    ) -> some View {
        HStack(spacing: 0) {
            pagePanel(
                text: pageText(spreadIndex: spreadIndex, side: .leading),
                pageNumber: pageNumber(spreadIndex: spreadIndex, side: .leading),
                pageCaption: viewModel.readingComparisonEnabled ? "原文" : nil,
                side: .leading,
                width: pageWidth,
                height: spreadHeight
            )
            .opacity(hideLeadingPage ? 0 : 1)

            ZStack(alignment: .top) {
                bookSpine
                BookInterface.BookmarkRibbon()
            }

            pagePanel(
                text: pageText(spreadIndex: spreadIndex, side: .trailing),
                pageNumber: pageNumber(spreadIndex: spreadIndex, side: .trailing),
                pageCaption: viewModel.readingComparisonEnabled ? "译文" : nil,
                side: .trailing,
                width: pageWidth,
                height: spreadHeight
            )
            .opacity(hideTrailingPage ? 0 : 1)
        }
    }

    @ViewBuilder
    private func turningSheet(
        direction: BookPageTurnDirection,
        pageWidth: CGFloat,
        spreadHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            if direction == .backward {
                BookPageTurnSheet(
                    progress: flipProgress,
                    direction: direction,
                    width: pageWidth,
                    height: spreadHeight
                ) {
                    pagePanel(
                        text: pageText(spreadIndex: displayedSpreadIndex, side: .leading),
                        pageNumber: pageNumber(spreadIndex: displayedSpreadIndex, side: .leading),
                        side: .leading,
                        width: pageWidth,
                        height: spreadHeight
                    )
                }
            } else {
                Color.clear.frame(width: pageWidth)
            }

            Color.clear.frame(width: 34)

            if direction == .forward {
                BookPageTurnSheet(
                    progress: flipProgress,
                    direction: direction,
                    width: pageWidth,
                    height: spreadHeight
                ) {
                    pagePanel(
                        text: pageText(spreadIndex: displayedSpreadIndex, side: .trailing),
                        pageNumber: pageNumber(spreadIndex: displayedSpreadIndex, side: .trailing),
                        side: .trailing,
                        width: pageWidth,
                        height: spreadHeight
                    )
                }
            } else {
                Color.clear.frame(width: pageWidth)
            }
        }
        .allowsHitTesting(false)
    }

    private var readingKeyboardShortcuts: some View {
        Group {
            Button("上一页") { turnPage(.backward) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("下一页") { turnPage(.forward) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button("学习模式") { viewModel.exitReadingMode() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pageSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard flipDirection == nil || isDraggingTurn else { return }

                let width = max(pageWidth, 1)
                if !isDraggingTurn {
                    if value.translation.width < -12, canGoForward {
                        beginInteractiveTurn(.forward)
                    } else if value.translation.width > 12, canGoBackward {
                        beginInteractiveTurn(.backward)
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

    private func turnButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
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

    private func pagePanel(
        text: String,
        pageNumber: Int?,
        pageCaption: String? = nil,
        side: HorizontalEdge,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
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
                .font(readingFont)
                .foregroundStyle(pageCaption == "译文" && text == "本页暂无译文" ? BookTheme.inkMuted : BookTheme.ink)
                .lineSpacing(BookTheme.tokens.typography.readingLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 36)
                .padding(.vertical, 24)

            pageFooter(pageNumber: pageNumber, side: side)
        }
        .frame(width: width, height: height)
        .bookPaperTexture()
        .bookPage(side == .leading ? BookTheme.pageLeft : BookTheme.pageRight)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if side == .trailing {
                BookInterface.PageCornerFold()
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            guard flipDirection == nil else { return }
            if side == .trailing {
                turnPage(.forward)
            } else {
                turnPage(.backward)
            }
        }
    }

    private func pageFooter(pageNumber: Int?, side: HorizontalEdge) -> some View {
        HStack {
            if side == .leading {
                BookInterface.PageMark(label: BookInterface.leftPageMark)
            }
            Spacer()
            if let pageNumber {
                Text("\(pageNumber)")
                    .font(BookTheme.captionFont.monospacedDigit())
                    .foregroundStyle(BookTheme.inkSecondary)
            }
            if side == .trailing {
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

    private var bookSpine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [BookTheme.spineLight, BookTheme.spineDark, BookTheme.spineLight.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 34)
            .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 0)
    }

    private var readingFont: Font {
        let typography = BookTheme.tokens.typography
        if let name = typography.preferredFontNames.first {
            return .custom(name, size: typography.readingSize)
        }
        return .system(size: typography.readingSize)
    }

    private var activeSpreadIndex: Int {
        targetSpreadIndex ?? displayedSpreadIndex
    }

    private var canGoForward: Bool {
        viewModel.canTurnReadingSpreadForward(from: displayedSpreadIndex)
    }

    private var canGoBackward: Bool {
        viewModel.canTurnReadingSpreadBackward(from: displayedSpreadIndex)
    }

    private func pageText(spreadIndex: Int, side: HorizontalEdge) -> String {
        switch side {
        case .leading:
            return viewModel.readingPageText(at: viewModel.leftPageIndex(forSpread: spreadIndex))
        case .trailing:
            if viewModel.readingComparisonEnabled {
                return viewModel.comparisonTranslationPageText(forSpread: spreadIndex)
            }
            if let index = viewModel.rightPageIndex(forSpread: spreadIndex) {
                return viewModel.readingPageText(at: index)
            }
            return ""
        }
    }

    private func pageNumber(spreadIndex: Int, side: HorizontalEdge) -> Int? {
        guard viewModel.readingPageCount > 0 else { return nil }
        switch side {
        case .leading:
            return viewModel.leftPageIndex(forSpread: spreadIndex) + 1
        case .trailing:
            if viewModel.readingComparisonEnabled {
                return viewModel.comparisonTranslationPageNumber(forSpread: spreadIndex)
            }
            guard let index = viewModel.rightPageIndex(forSpread: spreadIndex) else { return nil }
            return index + 1
        }
    }

    private func updatePageContentSize(width: CGFloat, height: CGFloat) {
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

    private func repaginateIfNeeded() {
        guard !isRepaginating else { return }
        guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }
        isRepaginating = true
        viewModel.repaginateForReading(pageContentSize: pageContentSize)
        displayedSpreadIndex = viewModel.readingSpreadIndex
        DispatchQueue.main.async {
            isRepaginating = false
        }
    }

    private func beginInteractiveTurn(_ direction: BookPageTurnDirection) {
        switch direction {
        case .forward:
            guard canGoForward else { return }
            targetSpreadIndex = displayedSpreadIndex + 1
        case .backward:
            guard canGoBackward else { return }
            targetSpreadIndex = displayedSpreadIndex - 1
        }
        flipDirection = direction
        isDraggingTurn = true
        flipProgress = 0
    }

    private func turnPage(_ direction: BookPageTurnDirection) {
        guard flipDirection == nil else { return }
        beginInteractiveTurn(direction)
        guard flipDirection != nil else { return }

        withAnimation(.bookPageTurn) {
            flipProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            finishTurnState()
        }
    }

    private func completeTurn() {
        withAnimation(.bookPageTurn) {
            flipProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            finishTurnState()
        }
    }

    private func cancelTurn() {
        withAnimation(.bookPageTurn) {
            flipProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            flipDirection = nil
            targetSpreadIndex = nil
            flipProgress = 0
        }
    }

    private func finishTurnState() {
        if let targetSpreadIndex {
            displayedSpreadIndex = targetSpreadIndex
            viewModel.readingSpreadIndex = targetSpreadIndex
        }
        flipProgress = 0
        flipDirection = nil
        self.targetSpreadIndex = nil
        isDraggingTurn = false
    }
}

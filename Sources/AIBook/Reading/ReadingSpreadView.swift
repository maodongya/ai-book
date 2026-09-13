import SwiftUI

/// 全屏沉浸阅读：顶栏、快捷键与 spread 主体容器。
struct ReadingSpreadView: View {
    static let defaultPageContentSize = CGSize(width: 340, height: 520)

    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var pageContentSize: CGSize = .zero
    @State private var displayedSpreadIndex: Int = 0
    @State private var flipProgress: CGFloat = 0
    @State private var flipDirection: BookPageTurnDirection?
    @State private var targetSpreadIndex: Int?
    @State private var isDraggingTurn = false
    @State private var isRepaginating = false
    @State private var layoutMode: ReadingLayoutMode = .spread
    @State private var turningPageSnapshot: BookPageTurnSnapshot?
    @State private var lastPageWidth: CGFloat = defaultPageContentSize.width
    @State private var lastSpreadHeight: CGFloat = defaultPageContentSize.height
    @State private var pageTurnCoordinator = ReadingSpreadPageTurnCoordinator()

    private let commitThreshold: CGFloat = 0.34
    private let spineWidth: CGFloat = 34

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
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex
            layoutMode = .spread
        }
        .onChange(of: viewModel.mode.readingSpreadIndex) { newValue in
            guard flipDirection == nil, layoutMode == .spread else { return }
            displayedSpreadIndex = newValue
        }
        .id(styleManager.revision)
    }

    private var spreadBody: some View {
        ReadingSpreadSpreadBody(
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
            turnCoordinator: pageTurnCoordinator,
            commitThreshold: commitThreshold,
            spineWidth: spineWidth
        )
        .onChange(of: styleManager.revision) { _ in
            guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }
            let sourcePage = currentSourcePageIndex()
            viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)
            applyPosition(fromSourcePage: sourcePage)
        }
    }

    private var readingHeader: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.mode.exitReadingMode() }) {
                BookToolbarCapsuleLabel(
                    title: BookL10n.string("mode.learning"),
                    isProminent: true,
                    isCompact: false,
                    isHovering: false
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(BookL10n.string("help.readingSpreadBack"))
            .keyboardShortcut(.escape, modifiers: [])

            VStack(alignment: .leading, spacing: 4) {
                Text(BookL10n.string("mode.reading"))
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text(viewModel.document.displayFileName)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.chromeMuted)
                    .lineLimit(1)
            }
            .layoutPriority(-1)

            Spacer(minLength: 8)

            layoutModePicker

            BookStatusPill(
                title: progressLabel(forSpreadIndex: activeSpreadIndex),
                icon: "book.pages"
            )
            .layoutPriority(-1)

            turnButton(systemImage: "chevron.left", enabled: canGoBackward) {
                pageTurnCoordinator.turnPage?(.backward)
            }
            turnButton(systemImage: "chevron.right", enabled: canGoForward) {
                pageTurnCoordinator.turnPage?(.forward)
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

    private var layoutModePicker: some View {
        let _ = settings.localizationRevision
        return HStack(spacing: 4) {
            ForEach(ReadingLayoutMode.allCases) { mode in
                Button {
                    setLayoutMode(mode)
                } label: {
                    Text(mode.displayName)
                        .font(BookTheme.captionFont.weight(mode == layoutMode ? .semibold : .regular))
                        .foregroundStyle(mode == layoutMode ? BookTheme.goldSoft : BookTheme.chromeMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(mode == layoutMode ? BookTheme.buttonFill : Color.clear)
                                .overlay {
                                    Capsule()
                                        .strokeBorder(
                                            mode == layoutMode ? BookTheme.buttonBorder : BookTheme.chromeOverlay.opacity(0.18),
                                            lineWidth: 1
                                        )
                                }
                        }
                }
                .buttonStyle(.plain)
                .help(mode == .spread ? BookL10n.string("help.readingSpreadLayout") : BookL10n.string("help.readingSinglePage"))
            }
        }
        .fixedSize()
    }

    private var readingKeyboardShortcuts: some View {
        Group {
            Button(BookL10n.string("reading.prevPage")) { pageTurnCoordinator.turnPage?(.backward) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button(BookL10n.string("reading.nextPage")) { pageTurnCoordinator.turnPage?(.forward) }
                .keyboardShortcut(.rightArrow, modifiers: [])
            Button(BookL10n.string("mode.learning")) { viewModel.mode.exitReadingMode() }
                .keyboardShortcut(.escape, modifiers: [])
            Button(BookL10n.string("layout.spread")) { setLayoutMode(.spread) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button(BookL10n.string("layout.fullscreen")) { setLayoutMode(.fullscreen) }
                .keyboardShortcut("2", modifiers: [.command, .option])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

    private var activeSpreadIndex: Int {
        targetSpreadIndex ?? displayedSpreadIndex
    }

    private var canGoForward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadForward(from: displayedSpreadIndex)
        case .fullscreen:
            return displayedSpreadIndex < max(0, viewModel.mode.readingPageCount - 1)
        }
    }

    private var canGoBackward: Bool {
        switch layoutMode {
        case .spread:
            return viewModel.mode.canTurnReadingSpreadBackward(from: displayedSpreadIndex)
        case .fullscreen:
            return displayedSpreadIndex > 0
        }
    }

    private func setLayoutMode(_ mode: ReadingLayoutMode) {
        guard layoutMode != mode else { return }
        let sourcePage = currentSourcePageIndex()
        layoutMode = mode
        guard pageContentSize.width > 0, pageContentSize.height > 0 else { return }
        viewModel.mode.repaginateForReading(pageContentSize: pageContentSize)
        applyPosition(fromSourcePage: sourcePage)
    }

    private func currentSourcePageIndex() -> Int {
        switch layoutMode {
        case .spread:
            return viewModel.mode.leftPageIndex(forSpread: displayedSpreadIndex)
        case .fullscreen:
            return min(max(0, displayedSpreadIndex), max(0, viewModel.mode.readingPageCount - 1))
        }
    }

    private func applyPosition(fromSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, viewModel.mode.readingPageCount - 1))
        switch layoutMode {
        case .spread:
            displayedSpreadIndex = viewModel.mode.readingSpreadIndex
        case .fullscreen:
            displayedSpreadIndex = clampedSource
        }
    }

    private func progressLabel(forSpreadIndex spreadIndex: Int) -> String {
        switch layoutMode {
        case .spread:
            return viewModel.mode.readingProgressLabel(spreadIndex: spreadIndex)
        case .fullscreen:
            let page = min(max(1, spreadIndex + 1), max(viewModel.mode.readingPageCount, 1))
            let total = max(viewModel.mode.readingPageCount, 1)
            return BookL10n.format("vm.page.single", page, total)
        }
    }
}

import SwiftUI

/// 沉浸阅读。点左右或滑动翻页，没有讲解和翻译。
struct IOSReadingPage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var voice: IOSVoiceController
    @ObservedObject private var styleManager = BookStyleManager.shared // 阅读页跟 Mac 阅读字号
    @State private var drag: CGFloat = 0
    @State private var chromeVisible = true
    @State private var chromeHideTask: Task<Void, Never>?

    var body: some View {
        let _ = styleManager.revision // 切预设时阅读页墨色与字体一起变
        GeometryReader { geo in
            let layoutPages = paginatedPages(in: geo)
            let count = max(layoutPages.count, 1)
            let index = resolvedIndex(in: layoutPages)
            ZStack {
                IOSPaper.page.ignoresSafeArea()
                if chromeVisible {
                    VStack(spacing: 0) {
                        topBar() // 独占顶行，正文从其下开始
                        pageLayer(
                            layoutPages: layoutPages,
                            index: index,
                            geo: geo,
                            pageCount: count
                        )
                        footerLabel(index: index, count: count)
                            .padding(.bottom, 12)
                    }
                    .transition(.opacity)
                } else {
                    pageLayer(
                        layoutPages: layoutPages,
                        index: index,
                        geo: geo,
                        pageCount: count
                    )
                }
            }
            .onAppear { scheduleChromeHide() }
            .onChange(of: styleManager.revision) { _, _ in
                syncIndexAfterRepagination(layoutPages)
            }
            .onChange(of: geo.size) { _, _ in
                syncIndexAfterRepagination(layoutPages)
            }
        }
    }

    @ViewBuilder
    private func pageLayer(
        layoutPages: [IOSBookPaginator.Page],
        index: Int,
        geo: GeometryProxy,
        pageCount: Int
    ) -> some View {
        readingBody(
            pages: layoutPages,
            index: index,
            reservesTopChrome: chromeVisible
        )
        .offset(x: drag)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture(pageWidth: geo.size.width, pageCount: pageCount, index: index, pages: layoutPages))
        .onTapGesture { location in
            handleTap(
                location.x,
                width: geo.size.width,
                pageCount: pageCount,
                index: index,
                pages: layoutPages
            )
        }
    }

    private func footerLabel(index: Int, count: Int) -> some View {
        Text(footer(index: index, count: count))
            .font(.footnote)
            .foregroundStyle(IOSPaper.inkMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(IOSPaper.panel, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(IOSPaper.panelBorder, lineWidth: 1)
            )
    }

    @ViewBuilder
    private func readingBody(
        pages: [IOSBookPaginator.Page],
        index: Int,
        reservesTopChrome: Bool
    ) -> some View {
        let edge = IOSLayout.readingTextPadding
        let top = reservesTopChrome ? edge : edge + 6
        let bottom = edge + 4
        singlePageText(pages, index: index)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, edge)
            .padding(.top, top)
            .padding(.bottom, bottom)
    }

    private func singlePageText(_ pages: [IOSBookPaginator.Page], index: Int) -> some View {
        Text(pageText(pages, index: index))
            .font(IOSPaper.readingFont)
            .foregroundStyle(IOSPaper.ink)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 沉浸阅读顶栏：左退出，右麦克风；单页全屏。
    private func topBar() -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                shell.exitReading() // 回到进入阅读前的那一页
            } label: {
                Label(BookL10n.string("action.close"), systemImage: "xmark")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            Spacer(minLength: 8)
            IOSMicButton(voice: voice, presentation: .readingChrome)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .iosPanelChrome(edge: .bottom)
    }

    private func paginatedPages(in geo: GeometryProxy) -> [IOSBookPaginator.Page] {
        let typography = styleManager.tokens.typography
        let contentSize = IOSReadingMetrics.paginationContentSize(in: geo)
        let pages = IOSBookPaginator.paginate(text: document.source, contentSize: contentSize, typography: typography)
        if pages.isEmpty {
            return [IOSBookPaginator.Page(text: "", range: NSRange(location: 0, length: 0))]
        }
        return pages
    }

    private func resolvedIndex(in pages: [IOSBookPaginator.Page]) -> Int {
        let anchor = min(document.readingCharacterAnchor, (document.source as NSString).length)
        if let match = pages.firstIndex(where: { NSLocationInRange(anchor, $0.range) }) {
            return match
        }
        return min(document.readingIndex, max(pages.count - 1, 0))
    }

    private func syncIndexAfterRepagination(_ pages: [IOSBookPaginator.Page]) {
        let index = resolvedIndex(in: pages)
        document.readingIndex = index
        if pages.indices.contains(index) {
            document.readingCharacterAnchor = pages[index].range.location
        }
    }

    private func pageText(_ pages: [IOSBookPaginator.Page], index: Int) -> String {
        guard pages.indices.contains(index) else { return "" }
        return pages[index].text
    }

    private func footer(index: Int, count: Int) -> String {
        BookL10n.format("vm.page.single", index + 1, count)
    }

    private func dragGesture(
        pageWidth: CGFloat,
        pageCount: Int,
        index: Int,
        pages: [IOSBookPaginator.Page]
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation.width // 跟手
            }
            .onEnded { value in
                let delta = IOSReadingTurn.pageDelta(translation: value.translation.width, pageWidth: pageWidth)
                apply(delta, pageCount: pageCount, index: index, pages: pages)
                drag = 0
            }
    }

    private func handleTap(
        _ x: CGFloat,
        width: CGFloat,
        pageCount: Int,
        index: Int,
        pages: [IOSBookPaginator.Page]
    ) {
        let edge = width / 5
        if x > edge, x < width - edge {
            withAnimation(.easeInOut(duration: 0.2)) {
                chromeVisible.toggle()
            }
            if chromeVisible { scheduleChromeHide() }
            return
        }
        let delta = x < width / 2 ? -1 : 1
        apply(delta, pageCount: pageCount, index: index, pages: pages)
        withAnimation { chromeVisible = false }
    }

    private func scheduleChromeHide() {
        chromeHideTask?.cancel()
        chromeHideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, chromeVisible else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) { chromeVisible = false }
            }
        }
    }

    private func apply(
        _ delta: Int,
        pageCount: Int,
        index: Int,
        pages: [IOSBookPaginator.Page]
    ) {
        let next = min(max(index + delta, 0), pageCount - 1) // 首页再向右留在首页
        let anchor = pages.indices.contains(next) ? pages[next].range.location : document.readingCharacterAnchor
        document.rememberReading(pageIndex: next, characterAnchor: anchor)
    }
}
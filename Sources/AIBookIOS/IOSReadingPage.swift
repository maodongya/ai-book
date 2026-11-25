import SwiftUI

/// 沉浸阅读。点左右或滑动翻页，没有讲解和翻译。
struct IOSReadingPage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var voice: IOSVoiceController
    @ObservedObject private var styleManager = BookStyleManager.shared // 阅读页跟 Mac 阅读字号
    @State private var drag: CGFloat = 0

    var body: some View {
        let _ = styleManager.revision // 切预设时阅读页墨色与字体一起变
        GeometryReader { geo in
            let pages = pages(in: geo.size) // 按当前纸面粗分，旋转后重算
            let index = min(document.readingIndex, max(pages.count - 1, 0)) // 字号变了也不越界
            ZStack {
                IOSPaper.page.ignoresSafeArea()
                Text(pages[index])
                    .font(IOSPaper.readingFont)
                    .foregroundStyle(IOSPaper.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(28)
                    .offset(x: drag) // 跟手
                    .gesture(dragGesture(pageWidth: geo.size.width, pageCount: pages.count, index: index))
                    .onTapGesture { location in
                        turnByTap(location.x, width: geo.size.width, pageCount: pages.count, index: index) // 左上一页，右下一页
                    }
                VStack {
                    topBar // 轻触阅读时仍留返回和麦克风
                    Spacer()
                    Text(footer(index: index, count: pages.count))
                        .font(.footnote)
                        .foregroundStyle(IOSPaper.inkMuted)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    /// 返回、页式说明、麦克风。不提供讲解。
    private var topBar: some View {
        HStack {
            Button(BookL10n.string("action.close")) {
                shell.exitReading() // 回到进入阅读前的那一页
            }
            Spacer()
            IOSMicButton(voice: voice)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 按纸面大约能放下的字数切开。不是 Mac 的分页器。
    private func pages(in size: CGSize) -> [String] {
        let pageSize = max(Int(size.width * size.height / 480), 200) // 粗略按面积，保证短文也有一页
        return IOSReadingPages.slices(of: document.source, pageSize: pageSize)
    }

    /// 页脚只留第几页。
    private func footer(index: Int, count: Int) -> String {
        "\(index + 1) / \(count)" // 目录里没有这条短格式，页码用数字即可
    }

    /// 跟手滑动。松手超过三分之一才翻完。
    private func dragGesture(pageWidth: CGFloat, pageCount: Int, index: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation.width // 跟手
            }
            .onEnded { value in
                let delta = IOSReadingTurn.pageDelta(translation: value.translation.width, pageWidth: pageWidth)
                apply(delta, pageCount: pageCount, index: index) // 不够就弹回
                drag = 0
            }
    }

    /// 点左半上一页，点右半下一页。
    private func turnByTap(_ x: CGFloat, width: CGFloat, pageCount: Int, index: Int) {
        let delta = x < width / 2 ? -1 : 1 // 左退右进
        apply(delta, pageCount: pageCount, index: index)
    }

    /// 夹在第一页和最后一页之间。
    private func apply(_ delta: Int, pageCount: Int, index: Int) {
        let next = min(max(index + delta, 0), pageCount - 1) // 首页再向右留在首页
        document.readingIndex = next
        document.rememberReading() // 每本书记住读到哪里
    }
}

/// 把正文切成阅读页。页大小由纸面传入。
enum IOSReadingPages {
    /// 空文本也有一页，避免阅读页空白崩溃。
    static func slices(of text: String, pageSize: Int) -> [String] {
        guard pageSize > 0 else { return [text] } // 非法页长就整篇一页
        if text.isEmpty { return [""] } // 阅读页仍能显示页码
        var pages: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: pageSize, limitedBy: text.endIndex) ?? text.endIndex // 最后一页不足一页也收下
            pages.append(String(text[index..<end]))
            index = end
        }
        return pages
    }
}

struct IOSMicButton: View {
    @ObservedObject var voice: IOSVoiceController

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Image(systemName: voice.holding ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundStyle(IOSPaper.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !voice.holding { voice.beginHold() } // 按住期间只开始一次
                        }
                        .onEnded { _ in voice.endHold() } // 松开后匹配口令
                )
                .accessibilityLabel(BookL10n.string("operation.mic.help"))
            if voice.holding || !voice.heard.isEmpty {
                Text(voice.holding ? BookL10n.string("operation.listening") : voice.heard)
                    .font(.caption)
                    .foregroundStyle(IOSPaper.ink)
                    .lineLimit(2)
            }
        }
    }
}

import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 阅读模式会话：学习/阅读体验切换、分页与 spread 索引持久化。
final class ReadingModeSession: ObservableObject {
    unowned var host: ReadingViewModel! // 装配后才有，方法里当已连接

    @Published var experienceMode: ReadingExperienceMode = .learning
    @Published var readingPageTexts: [String] = []
    @Published var readingSourcePageRanges: [NSRange] = [] // 相对 trimmed 全文，回学习模式要对回 fileContent
    @Published var readingSpreadIndex: Int = 0 {
        didSet {
            guard readingSpreadIndex != oldValue else { return }
            persistReadingSpreadIndex()
        }
    }
    private var pendingReadingSourcePage: Int? // 恢复分页前先记下要停在第几页
    private var lastReadingPageContentSize: CGSize?
    private let readingPositionKeyPrefix = "aiBook.reading.spread." // 键只在这里拼
    private let readingSourcePageKeyPrefix = "aiBook.reading.sourcePage."

    /// 有分页文本才能进沉浸阅读。
    var canEnterReadingMode: Bool {
        !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 双页一摊；单页也算一摊。
    var readingSpreadCount: Int { max(1, (readingPageTexts.count + 1) / 2) } // 单页也算一摊
    /// 当前分页后的页数。
    var readingPageCount: Int { readingPageTexts.count }

    /// 这一页正文。越界空串。
    func readingPageText(at index: Int) -> String {
        guard readingPageTexts.indices.contains(index) else { return "" }
        return readingPageTexts[index]
    }

    /// 这一摊的左页下标。
    func leftPageIndex(forSpread spreadIndex: Int) -> Int {
        spreadIndex * 2
    }

    /// 最后一摊可能没有右页。
    func rightPageIndex(forSpread spreadIndex: Int) -> Int? {
        let index = spreadIndex * 2 + 1
        return readingPageTexts.indices.contains(index) ? index : nil
    }

    /// 当前左页在全文中的页号。
    func currentVisibleSourcePageIndex() -> Int {
        leftPageIndex(forSpread: readingSpreadIndex)
    }

    /// 「第 3–4 / 20 页」。只有左页走 single。
    func readingProgressLabel(spreadIndex: Int) -> String {
        let left = leftPageIndex(forSpread: spreadIndex) + 1 // 给人看从 1 起
        let total = max(readingPageCount, 1)
        if let rightIndex = rightPageIndex(forSpread: spreadIndex) {
            return BookL10n.format("vm.page.range", left, rightIndex + 1, total)
        }
        return BookL10n.format("vm.page.single", left, total)
    }

    /// 窗口变了重切页，尽量停在同一原文页。
    func repaginateForReading(pageContentSize: CGSize) {
        let keepSourcePage = pendingReadingSourcePage ?? currentVisibleSourcePageIndex()
        pendingReadingSourcePage = nil
        lastReadingPageContentSize = pageContentSize
        let pages = BookPaginator.paginateWithRanges(text: host.document.fileContent, pageSize: pageContentSize)
        readingPageTexts = pages.map(\.text)
        readingSourcePageRanges = pages.map(\.range)
        applyReadingSpread(forSourcePage: keepSourcePage)
    }

    /// 按原文页落到对应摊。
    private func applyReadingSpread(forSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, readingPageTexts.count - 1))
        let target = clampedSource / 2
        let maxSpread = max(0, readingSpreadCount - 1)
        readingSpreadIndex = min(max(0, target), maxSpread)
    }

    /// 退出阅读模式后滚回学习左页对应位置。立刻滚失败则 80ms 再试一次。
    private func restoreLearningScrollPositionFromReadingSpread() {
        let sourcePage = currentVisibleSourcePageIndex()
        guard readingSourcePageRanges.indices.contains(sourcePage) else { return }
        let trimmedRange = readingSourcePageRanges[sourcePage]
        guard trimmedRange.length > 0,
              let range = fileContentRange(fromTrimmedRange: trimmedRange) else { return }
        guard experienceMode == .learning else { return }
        if host.translation.sourceTextScrollProxy.scrollToCharacterRange(range, anchor: .top) { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.experienceMode == .learning else { return }
            _ = self.host.translation.sourceTextScrollProxy.scrollToCharacterRange(range, anchor: .top)
        }
    }

    /// 分页 range 相对 trimmed，这里加回原文前导空白。
    private func fileContentRange(fromTrimmedRange range: NSRange) -> NSRange? {
        let ns = host.document.fileContent as NSString
        let trimmed = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let found = ns.range(of: trimmed)
        guard found.location != NSNotFound else { return nil }
        let location = found.location + range.location
        guard location < ns.length else { return nil }
        let length = min(range.length, ns.length - location)
        return NSRange(location: location, length: max(0, length))
    }

    /// 切沉浸阅读并恢复页码。
    func enterReadingMode(pageContentSize: CGSize) {
        guard canEnterReadingMode else { return }
        restoreReadingSpreadIndex()
        repaginateForReading(pageContentSize: pageContentSize)
        experienceMode = .reading
    }

    /// 回学习模式，滚到对应原文。
    func exitReadingMode() {
        guard experienceMode == .reading else { return }
        experienceMode = .learning
        persistReadingSpreadIndex()
        DispatchQueue.main.async { [weak self] in
            self?.restoreLearningScrollPositionFromReadingSpread() // 等布局切回学习栏再滚
        }
    }

    /// 学习和阅读互切。
    func toggleReadingMode(pageContentSize: CGSize) {
        if experienceMode == .reading {
            exitReadingMode()
        } else {
            enterReadingMode(pageContentSize: pageContentSize)
        }
    }

    /// 不是最后一摊才能向前。
    func canTurnReadingSpreadForward(from spreadIndex: Int) -> Bool {
        spreadIndex < readingSpreadCount - 1
    }

    /// 不是第一摊才能向后。
    func canTurnReadingSpreadBackward(from spreadIndex: Int) -> Bool {
        spreadIndex > 0
    }

    /// 后一摊。
    func turnReadingSpreadForward() {
        guard canTurnReadingSpreadForward(from: readingSpreadIndex) else { return }
        readingSpreadIndex += 1
    }

    /// 前一摊。
    func turnReadingSpreadBackward() {
        guard canTurnReadingSpreadBackward(from: readingSpreadIndex) else { return }
        readingSpreadIndex -= 1
    }

    /// 已保存文件用路径；未命名草稿用 draft:文件名。未打开回 nil。
    private func readingPositionStorageKey() -> String? {
        if let path = host.document.currentFileURL?.path {
            return readingPositionKeyPrefix + path
        }
        if host.document.isDocumentOpen, host.document.fileName != ReadingViewModel.untitledMarker {
            return readingPositionKeyPrefix + "draft:" + host.document.fileName
        }
        return nil
    }

    /// 按文件路径记页码的键。
    private func readingSourcePageStorageKey() -> String? {
        if let path = host.document.currentFileURL?.path {
            return readingSourcePageKeyPrefix + path
        }
        if host.document.isDocumentOpen, host.document.fileName != ReadingViewModel.untitledMarker {
            return readingSourcePageKeyPrefix + "draft:" + host.document.fileName
        }
        return nil
    }

    /// 优先恢复具体页；旧数据只有 spread 则 ×2。
    private func restoreReadingSpreadIndex() {
        if let sourceKey = readingSourcePageStorageKey(),
           UserDefaults.standard.object(forKey: sourceKey) != nil {
            pendingReadingSourcePage = max(0, UserDefaults.standard.integer(forKey: sourceKey))
        } else if let spreadKey = readingPositionStorageKey() {
            let saved = UserDefaults.standard.integer(forKey: spreadKey)
            pendingReadingSourcePage = max(0, saved) * 2
        }
        if let sourcePage = pendingReadingSourcePage {
            readingSpreadIndex = sourcePage / 2
        }
    }

    /// 页码和摊号一起落盘。
    private func persistReadingSpreadIndex() {
        let sourcePage = currentVisibleSourcePageIndex()
        if let sourceKey = readingSourcePageStorageKey() {
            UserDefaults.standard.set(sourcePage, forKey: sourceKey)
        }
        if let spreadKey = readingPositionStorageKey() {
            UserDefaults.standard.set(sourcePage / 2, forKey: spreadKey)
        }
    }
}

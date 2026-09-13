import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 阅读模式会话：学习/阅读体验切换、分页与 spread 索引持久化。
final class ReadingModeSession: ObservableObject {
    unowned var host: ReadingViewModel!


    @Published var experienceMode: ReadingExperienceMode = .learning
    @Published var readingPageTexts: [String] = []
    @Published var readingSourcePageRanges: [NSRange] = []
    @Published var readingSpreadIndex: Int = 0 {
        didSet {
            guard readingSpreadIndex != oldValue else { return }
            persistReadingSpreadIndex()
        }
    }
    private var pendingReadingSourcePage: Int?
    private var lastReadingPageContentSize: CGSize?
    private let readingPositionKeyPrefix = "aiBook.reading.spread."
    private let readingSourcePageKeyPrefix = "aiBook.reading.sourcePage."

    var canEnterReadingMode: Bool {
        !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var readingSpreadCount: Int { max(1, (readingPageTexts.count + 1) / 2) }
    var readingPageCount: Int { readingPageTexts.count }



    func readingPageText(at index: Int) -> String {
        guard readingPageTexts.indices.contains(index) else { return "" }
        return readingPageTexts[index]
    }


    func leftPageIndex(forSpread spreadIndex: Int) -> Int {
        spreadIndex * 2
    }


    func rightPageIndex(forSpread spreadIndex: Int) -> Int? {
        let index = spreadIndex * 2 + 1
        return readingPageTexts.indices.contains(index) ? index : nil
    }


    func currentVisibleSourcePageIndex() -> Int {
        leftPageIndex(forSpread: readingSpreadIndex)
    }


    func readingProgressLabel(spreadIndex: Int) -> String {
        let left = leftPageIndex(forSpread: spreadIndex) + 1
        let total = max(readingPageCount, 1)
        if let rightIndex = rightPageIndex(forSpread: spreadIndex) {
            return BookL10n.format("vm.page.range", left, rightIndex + 1, total)
        }
        return BookL10n.format("vm.page.single", left, total)
    }

    func repaginateForReading(pageContentSize: CGSize) {
        let keepSourcePage = pendingReadingSourcePage ?? currentVisibleSourcePageIndex()
        pendingReadingSourcePage = nil
        lastReadingPageContentSize = pageContentSize
        let pages = BookPaginator.paginateWithRanges(text: host.document.fileContent, pageSize: pageContentSize)
        readingPageTexts = pages.map(\.text)
        readingSourcePageRanges = pages.map(\.range)
        applyReadingSpread(forSourcePage: keepSourcePage)
    }


    private func applyReadingSpread(forSourcePage sourcePage: Int) {
        let clampedSource = min(max(0, sourcePage), max(0, readingPageTexts.count - 1))
        let target = clampedSource / 2
        let maxSpread = max(0, readingSpreadCount - 1)
        readingSpreadIndex = min(max(0, target), maxSpread)
    }


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


    func enterReadingMode(pageContentSize: CGSize) {
        guard canEnterReadingMode else { return }
        restoreReadingSpreadIndex()
        repaginateForReading(pageContentSize: pageContentSize)
        experienceMode = .reading
    }


    func exitReadingMode() {
        guard experienceMode == .reading else { return }
        experienceMode = .learning
        persistReadingSpreadIndex()
        DispatchQueue.main.async { [weak self] in
            self?.restoreLearningScrollPositionFromReadingSpread()
        }
    }


    func toggleReadingMode(pageContentSize: CGSize) {
        if experienceMode == .reading {
            exitReadingMode()
        } else {
            enterReadingMode(pageContentSize: pageContentSize)
        }
    }


    func canTurnReadingSpreadForward(from spreadIndex: Int) -> Bool {
        spreadIndex < readingSpreadCount - 1
    }


    func canTurnReadingSpreadBackward(from spreadIndex: Int) -> Bool {
        spreadIndex > 0
    }


    func turnReadingSpreadForward() {
        guard canTurnReadingSpreadForward(from: readingSpreadIndex) else { return }
        readingSpreadIndex += 1
    }


    func turnReadingSpreadBackward() {
        guard canTurnReadingSpreadBackward(from: readingSpreadIndex) else { return }
        readingSpreadIndex -= 1
    }


    private func readingPositionStorageKey() -> String? {
        if let path = host.document.currentFileURL?.path {
            return readingPositionKeyPrefix + path
        }
        if host.document.isDocumentOpen, host.document.fileName != ReadingViewModel.untitledMarker {
            return readingPositionKeyPrefix + "draft:" + host.document.fileName
        }
        return nil
    }


    private func readingSourcePageStorageKey() -> String? {
        if let path = host.document.currentFileURL?.path {
            return readingSourcePageKeyPrefix + path
        }
        if host.document.isDocumentOpen, host.document.fileName != ReadingViewModel.untitledMarker {
            return readingSourcePageKeyPrefix + "draft:" + host.document.fileName
        }
        return nil
    }


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

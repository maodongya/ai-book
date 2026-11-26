import UIKit

/// iOS 阅读分页。按阅读字体、行距与纸面内边距排版，对齐 `IOSReadingPage` 的 padding。
enum IOSBookPaginator {
    static let contentInset = UIEdgeInsets(top: 28, left: 28, bottom: 48, right: 28)
    static let paragraphSpacing: CGFloat = 14

    struct Page: Equatable {
        let text: String
        let range: NSRange
    }

    static func paginate(text: String, pageSize: CGSize, typography: BookStyleTypography) -> [Page] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [Page(text: "", range: NSRange(location: 0, length: 0))] }

        let contentWidth = max(1, pageSize.width - contentInset.left - contentInset.right)
        let contentHeight = max(1, pageSize.height - contentInset.top - contentInset.bottom)
        let containerSize = CGSize(width: contentWidth, height: contentHeight)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.readingLineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing

        let font = typography.uiFont(size: typography.readingSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]

        let storage = NSTextStorage(string: trimmed, attributes: attributes)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pages: [Page] = []
        var glyphIndex = 0
        let totalGlyphs = layoutManager.numberOfGlyphs

        while glyphIndex < totalGlyphs {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }

            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let pageText = (trimmed as NSString).substring(with: characterRange)
            pages.append(Page(text: pageText, range: characterRange))

            glyphIndex = NSMaxRange(glyphRange)
        }

        if pages.isEmpty {
            let range = NSRange(location: 0, length: (trimmed as NSString).length)
            return [Page(text: trimmed, range: range)]
        }
        return pages
    }
}
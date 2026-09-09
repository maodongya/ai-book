import AppKit
import Foundation

/// Splits book text into fixed-size pages using the same typography as the left-page reader.
enum BookPaginator {
    static let textContainerInset = NSSize(width: 36, height: 32)
    static let paragraphSpacing: CGFloat = 14

    static func paginate(
        text: String,
        pageSize: CGSize,
        typography: BookStyleTypography = BookTheme.tokens.typography
    ) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let contentWidth = max(1, pageSize.width - textContainerInset.width * 2)
        let contentHeight = max(1, pageSize.height - textContainerInset.height * 2)
        let containerSize = CGSize(width: contentWidth, height: contentHeight)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = typography.readingLineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: typography.readingNSFont,
            .foregroundColor: NSColor(BookTheme.ink),
            .paragraphStyle: paragraphStyle,
        ]

        let storage = NSTextStorage(string: trimmed, attributes: attributes)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var pages: [String] = []
        var glyphIndex = 0
        let totalGlyphs = layoutManager.numberOfGlyphs

        while glyphIndex < totalGlyphs {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }

            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            let page = (trimmed as NSString).substring(with: characterRange)
            pages.append(page)

            glyphIndex = NSMaxRange(glyphRange)
            if glyphRange.length == 0 { break }
        }

        return pages.isEmpty ? [trimmed] : pages
    }
}

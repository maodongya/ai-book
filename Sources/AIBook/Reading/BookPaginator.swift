import AppKit
import Foundation

/// 按左页同一套字体把全文切成固定页。
enum BookPaginator {
    /// 一页排好的正文范围。Equatable 用来判断是否要重绘。
struct PaginatedPage: Equatable {
        let text: String // 这一页可见的正文
        let range: NSRange // 相对 trimmed 全文，用来对齐选区
    }

    static let textContainerInset = NSSize(width: 36, height: 32) // 必须和左页 NSTextView inset 一致，否则页对不齐
    static let paragraphSpacing: CGFloat = 14 // 段间距，和阅读页排版锁死

    /// 只要每页字符串。需要 range 走 paginateWithRanges。
    static func paginate(
        text: String,
        pageSize: CGSize, // 整页尺寸，内部再扣 inset
        typography: BookStyleTypography = BookTheme.tokens.typography // 默认当前主题，预览可另传
    ) -> [String] {
        paginateWithRanges(text: text, pageSize: pageSize, typography: typography).map(\.text)
    }

    /// 空文回空数组。排不出 glyph 时整篇当一页，避免空白书。
    static func paginateWithRanges(
        text: String, // 全书正文，内部会先 trim
        pageSize: CGSize, // 整页尺寸，内部再扣 inset
        typography: BookStyleTypography = BookTheme.tokens.typography
    ) -> [PaginatedPage] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines) // 去掉首尾空白再量，避免空页
        guard !trimmed.isEmpty else { return [] } // 没正文就不要造一页空纸

        let contentWidth = max(1, pageSize.width - textContainerInset.width * 2) // 扣左右 inset；至少 1，避免 0 宽崩布局
        let contentHeight = max(1, pageSize.height - textContainerInset.height * 2) // 扣上下 inset
        let containerSize = CGSize(width: contentWidth, height: contentHeight) // 每个 NSTextContainer 同一尺寸

        let paragraphStyle = NSMutableParagraphStyle() // 行距/段距跟阅读页一致
        paragraphStyle.lineSpacing = typography.readingLineSpacing // 跟左页同一行距
        paragraphStyle.paragraphSpacing = paragraphSpacing // 跟常量锁死，禁止各页各调

        let attributes: [NSAttributedString.Key: Any] = [ // 量页只用阅读字体和墨色
            .font: typography.readingNSFont, // AppKit 字体，SwiftUI Font 量不准
            .foregroundColor: NSColor(BookTheme.ink), // 颜色不影响分页，只为 attributed 完整
            .paragraphStyle: paragraphStyle,
        ]

        let storage = NSTextStorage(string: trimmed, attributes: attributes) // 一份 storage 挂多个 container
        let layoutManager = NSLayoutManager() // 一份 manager 挂多个 container，一页一个
        storage.addLayoutManager(layoutManager)

        var pages: [PaginatedPage] = []
        var glyphIndex = 0 // 已消费的 glyph，用来判断何时结束
        let totalGlyphs = layoutManager.numberOfGlyphs // 排完才准，前面 ensureLayout 保证

        while glyphIndex < totalGlyphs { // 一页一个 container，吃掉一段 glyph
            let container = NSTextContainer(size: containerSize) // 本页盒子，加到 manager 后才有 glyph
            container.lineFragmentPadding = 0 // 不要额外 padding，否则和 inset 叠两次
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container) // 立刻排，才能读 glyphRange

            let glyphRange = layoutManager.glyphRange(for: container) // 这一页吃掉的 glyph
            guard glyphRange.length > 0 else { break } // 排不出字就停，防死循环

            let characterRange = layoutManager.characterRange( // glyph 转字符，给选区对齐
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            let page = (trimmed as NSString).substring(with: characterRange) // UTF-16 下标，和 NSRange 一致
            pages.append(PaginatedPage(text: page, range: characterRange))

            glyphIndex = NSMaxRange(glyphRange) // 下一页从这段之后开始
            if glyphRange.length == 0 { break } // 双保险
        }

        if pages.isEmpty { // 有字却 0 页：整篇塞进一页
            let range = NSRange(location: 0, length: (trimmed as NSString).length) // 整篇当一页
            return [PaginatedPage(text: trimmed, range: range)]
        }
        return pages
    }
}

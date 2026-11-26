import Foundation

/// 旧版按字数切页，仅单测保留。
enum IOSReadingPages {
    static func slices(of text: String, pageSize: Int) -> [String] {
        guard pageSize > 0 else { return [text] }
        if text.isEmpty { return [""] }
        var pages: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: pageSize, limitedBy: text.endIndex) ?? text.endIndex
            pages.append(String(text[index..<end]))
            index = end
        }
        return pages
    }
}
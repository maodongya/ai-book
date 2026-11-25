import Foundation

/// 把原文和译文或讲解按行配成上下对照。行数不同时，多出来的一边留空。
enum IOSParagraphPairs {
    /// 空行丢掉，避免对照表里出现空白块。
    static func paragraphs(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 第 n 行原文配第 n 行另一侧。
    static func pairs(source: String, other: String) -> [(source: String, other: String)] {
        let left = paragraphs(source)
        let right = paragraphs(other)
        let count = max(left.count, right.count)
        guard count > 0 else { return [] }
        return (0 ..< count).map { index in
            (
                source: index < left.count ? left[index] : "",
                other: index < right.count ? right[index] : ""
            )
        }
    }
}

import Foundation

/// 按行分段把译文或讲解收成 `TranslationAlignment`。不调模型，对齐 Mac 本地对齐入口的轻量版。
enum IOSAlignmentSync {
    /// 用于标记是否需因改原文而 stale。
    static func sourceFingerprint(_ source: String) -> String {
        "\(source.utf8.count):\(source.hashValue)" // 长度 + 哈希，改原文即可判 stale
    }

    /// 原文与对照正文按空行配对后写入块表。
    static func alignParagraphs(source: String, companion: String) -> TranslationAlignment? {
        let pairs = IOSParagraphPairs.pairs(source: source, other: companion) // 按段落拆对
        guard !pairs.isEmpty else { return nil } // 无可对齐段落
        let nsSource = source as NSString // 在原文里定位每段 range
        var searchStart = 0 // 顺序查找起点，避免重复匹配
        var blocks: [TranslationBlock] = []
        for (order, pair) in pairs.enumerated() {
            guard !pair.source.isEmpty || !pair.other.isEmpty else { continue } // 跳过空对
            let range: NSRange
            if !pair.source.isEmpty {
                let found = nsSource.range(
                    of: pair.source,
                    options: [],
                    range: NSRange(location: searchStart, length: max(0, nsSource.length - searchStart))
                )
                if found.location != NSNotFound {
                    range = found
                    searchStart = found.location + found.length // 下一段从这里往后找
                } else {
                    range = NSRange(location: 0, length: 0) // 找不到就占位空 range
                }
            } else {
                range = NSRange(location: 0, length: 0)
            }
            blocks.append(
                TranslationBlock(
                    sourceRange: range,
                    sourceText: pair.source,
                    translationText: pair.other,
                    level: .paragraph,
                    order: order
                )
            )
        }
        guard !blocks.isEmpty else { return nil }
        return TranslationAlignment(
            mode: .paragraph,
            blocks: blocks,
            sourceContentHash: sourceFingerprint(source),
            createdAt: Date(),
            isStale: false,
            strictParagraphValidated: false,
            provenance: .realignedHeuristic
        )
    }
}
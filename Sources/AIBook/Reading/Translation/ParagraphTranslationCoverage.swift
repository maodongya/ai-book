import Foundation

/// 整段译文一条：index 对 `SourceParagraphIndex`，不负责锚点。
struct ParagraphTranslationItem: Equatable {
    var index: Int
    var translationText: String
    var notes: String?
}

/// 整段覆盖算法：分批、缺段、合并、拼 JSON。不发网络请求。
enum ParagraphTranslationCoverage {
    /// 单次请求段数上限，避免后段被模型截掉。
    static let defaultBatchSize = 10
    /// 补译轮数上限，防止死循环。
    static let maxFillRounds = 2

    /// 把 0..<count 切成不重叠的批。
    static func batches(count: Int, size: Int = defaultBatchSize) -> [Range<Int>] {
        guard count > 0, size > 0 else { return [] }  // 没段或批大小非法
        return stride(from: 0, to: count, by: size).map { start in
            start..<min(start + size, count)  // 最后一批可以不足
        }
    }

    /// 缺号或译文空白的下标，按原文顺序。
    static func missingIndices(
        in items: [ParagraphTranslationItem],
        expectedCount: Int
    ) -> [Int] {
        guard expectedCount > 0 else { return [] }  // 原文没有段
        var filled = Set<Int>()  // 已有非空译文的 index
        for item in items {
            let text = item.translationText.trimmingCharacters(in: .whitespacesAndNewlines)  // 空白当没译
            if !text.isEmpty {
                filled.insert(item.index)  // 只收有效译文
            }
        }
        return (0..<expectedCount).filter { !filled.contains($0) }  // 0…n-1 里没填上的
    }

    /// 同号后到的非空译文覆盖旧值；空译文不覆盖已有。
    static func merge(
        _ existing: [ParagraphTranslationItem],
        with incoming: [ParagraphTranslationItem]
    ) -> [ParagraphTranslationItem] {
        var byIndex: [Int: ParagraphTranslationItem] = [:]  // 按下标收最后有效值
        for item in existing {
            byIndex[item.index] = item  // 先铺已有
        }
        for item in incoming {
            let text = item.translationText.trimmingCharacters(in: .whitespacesAndNewlines)  // 空白当没译
            if text.isEmpty { continue }  // 空结果不冲掉旧译
            byIndex[item.index] = item  // 同号用新的
        }
        return byIndex.values.sorted { $0.index < $1.index }  // 按原文顺序
    }

    /// 段数齐且每段非空。
    static func isComplete(
        _ items: [ParagraphTranslationItem],
        expectedCount: Int
    ) -> Bool {
        missingIndices(in: items, expectedCount: expectedCount).isEmpty  // 没有缺段
    }

    /// 拼回严格验收用的 translations JSON。
    static func encodedJSON(_ items: [ParagraphTranslationItem]) -> String {
        let payload: [String: Any] = [
            "mode": "paragraph",  // 和 Prompt / 解析器约定
            "translations": items.map { item -> [String: Any] in
                var row: [String: Any] = [
                    "index": item.index,  // 对应原文段
                    "translationText": item.translationText,  // 这一段译文
                ]
                if let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !notes.isEmpty {
                    row["notes"] = notes  // 有注才写
                } else {
                    row["notes"] = NSNull()  // 与模型输出同形
                }
                return row  // 一段
            },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"mode":"paragraph","translations":[]}"#  // 编码失败给空数组，验收会拦
        }
        return text  // 给 buildStrictParagraph
    }
}

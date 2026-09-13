import Foundation

/// 本地把译文重切成和原文段数一致。模型 JSON 失败时的退路。
enum TranslationParagraphSegmenter {
    /// 本地切出的一段译文，可选注。
    struct Segment {
        var text: String
        var note: String?
    }

    /// 段数相等直接 zip；多了合并；少了按原文权重切开。
    static func resegment(
        translation: String,
        targetCount: Int, // 原文段数
        sourceWeights: [Int], // 每段原文长度，切开时按比例
        notes: [String?] = []
    ) -> [Segment] {
        guard targetCount > 0 else { return [] }
        let body = TranslationParagraphText.prepareTranslationBody(translation)
        guard !body.isEmpty else { return [] }

        let paragraphs = TranslationParagraphText.contentParagraphs(in: body)
        if paragraphs.isEmpty {
            return proportionalSegments(
                in: body,
                targetCount: targetCount,
                sourceWeights: sourceWeights
            ) // 模型连空行都没留，按字数切
        }

        if paragraphs.count == targetCount {
            return zipSegments(paragraphs, notes: notes, targetCount: targetCount)
        }
        if paragraphs.count > targetCount {
            return mergeSegments(paragraphs, notes: notes, targetCount: targetCount)
        }
        return expandSegments(
            paragraphs,
            notes: notes,
            targetCount: targetCount,
            sourceWeights: sourceWeights
        )
    }

    /// 按空行切段。
    static func splitParagraphs(_ text: String) -> [String] {
        TranslationParagraphText.contentParagraphs(in: text)
    }

    /// 去掉【标题】再去围栏。
    static func stripDisplayChrome(_ text: String) -> String {
        TranslationParagraphText.stripDisplayTitle(text)
    }

    /// 原文段和译文段按最短长度对齐。
    private static func zipSegments(
        _ paragraphs: [String],
        notes: [String?],
        targetCount: Int
    ) -> [Segment] {
        (0..<targetCount).map { index in
            Segment(
                text: paragraphs[index],
                note: index < notes.count ? notes[index] : nil // 注比段少就空着
            )
        }
    }

    /// 译文段多于原文：均匀合并。注跟合并后第一段走。
    private static func mergeSegments(
        _ paragraphs: [String],
        notes: [String?],
        targetCount: Int
    ) -> [Segment] {
        guard targetCount > 0 else { return [] }
        var result: [Segment] = []
        let chunkSize = Double(paragraphs.count) / Double(targetCount)
        var cursor = 0.0

        for index in 0..<targetCount {
            let end = index == targetCount - 1
                ? Double(paragraphs.count) // 最后一段吃掉余数
                : min(Double(paragraphs.count), ((Double(index + 1) * chunkSize).rounded()))
            let startIndex = Int(cursor.rounded())
            let endIndex = Int(end.rounded())
            let slice = paragraphs[startIndex..<min(max(startIndex, endIndex), paragraphs.count)]
            let merged = slice.joined(separator: "\n\n")
            let note = notes.indices.contains(startIndex) ? notes[startIndex] : nil
            result.append(Segment(text: merged, note: note))
            cursor = end
        }
        return result.filter { !$0.text.isEmpty }
    }

    /// 译文段不够：拼回去再按权重切开。
    private static func expandSegments(
        _ paragraphs: [String],
        notes: [String?],
        targetCount: Int,
        sourceWeights: [Int]
    ) -> [Segment] {
        let joined = paragraphs.joined(separator: "\n\n")
        return proportionalSegments(
            in: joined,
            targetCount: targetCount,
            sourceWeights: sourceWeights,
            seedNotes: notes
        )
    }

    /// 按原文每段长度占比切译文，并尽量落在句号上。
    private static func proportionalSegments(
        in text: String,
        targetCount: Int,
        sourceWeights: [Int],
        seedNotes: [String?] = []
    ) -> [Segment] {
        let prepared = TranslationParagraphText.collapsedBlankLines(text)
        let ns = prepared as NSString
        let totalLength = ns.length
        guard totalLength > 0, targetCount > 0 else { return [] }

        let weights = (0..<targetCount).map { index in
            index < sourceWeights.count ? max(sourceWeights[index], 1) : 1 // 缺权重当 1，避免除零
        }

        var segments: [Segment] = []
        var start = 0

        for index in 0..<targetCount {
            let end: Int
            if index == targetCount - 1 {
                end = totalLength // 最后一段吃到结尾
            } else {
                let shareWeight = weights[index...].reduce(0, +)
                let share = max(1, Int((Double(totalLength - start) * Double(weights[index]) / Double(max(shareWeight, 1))).rounded()))
                let preferred = min(totalLength, start + share)
                end = snapToSentenceBoundary(in: ns, start: start, preferredEnd: preferred, isLast: false)
            }

            let range = NSRange(location: start, length: max(0, end - start))
            let chunk = TranslationParagraphText.trimParagraphContent(ns.substring(with: range))
            if !chunk.isEmpty {
                segments.append(
                    Segment(
                        text: chunk,
                        note: index < seedNotes.count ? seedNotes[index] : nil
                    )
                )
            }
            start = end
        }

        return segments
    }

    /// 先向后 120 字找句号，找不到再向前 80。都没有就硬切。
    private static func snapToSentenceBoundary(
        in text: NSString,
        start: Int,
        preferredEnd: Int,
        isLast: Bool
    ) -> Int {
        guard preferredEnd < text.length else { return text.length }
        if isLast { return text.length }

        let searchEnd = min(text.length, preferredEnd + 120)
        let searchRange = NSRange(location: preferredEnd, length: max(0, searchEnd - preferredEnd))
        let delimiters = ["。", "！", "？", "!", "?", "；", ";", "\n"]
        for delimiter in delimiters {
            let found = text.range(of: delimiter, options: [], range: searchRange)
            if found.location != NSNotFound {
                return found.location + (delimiter as NSString).length
            }
        }

        let backStart = max(start + 1, preferredEnd - 80)
        let backRange = NSRange(location: backStart, length: max(0, preferredEnd - backStart))
        for delimiter in delimiters {
            let found = text.range(of: delimiter, options: .backwards, range: backRange)
            if found.location != NSNotFound {
                return found.location + (delimiter as NSString).length
            }
        }
        return preferredEnd
    }
}

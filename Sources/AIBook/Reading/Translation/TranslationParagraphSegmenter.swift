import Foundation

/// Resplit translated prose to match source paragraph count for local alignment.
enum TranslationParagraphSegmenter {
    struct Segment {
        var text: String
        var note: String?
    }

    static func resegment(
        translation: String,
        targetCount: Int,
        sourceWeights: [Int],
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
            )
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

    static func splitParagraphs(_ text: String) -> [String] {
        TranslationParagraphText.contentParagraphs(in: text)
    }

    static func stripDisplayChrome(_ text: String) -> String {
        TranslationParagraphText.stripDisplayTitle(text)
    }

    private static func zipSegments(
        _ paragraphs: [String],
        notes: [String?],
        targetCount: Int
    ) -> [Segment] {
        (0..<targetCount).map { index in
            Segment(
                text: paragraphs[index],
                note: index < notes.count ? notes[index] : nil
            )
        }
    }

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
                ? Double(paragraphs.count)
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
            index < sourceWeights.count ? max(sourceWeights[index], 1) : 1
        }

        var segments: [Segment] = []
        var start = 0

        for index in 0..<targetCount {
            let end: Int
            if index == targetCount - 1 {
                end = totalLength
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

import Foundation

enum SpeechTextSanitizer {
    enum SpeechPauseKind: Equatable {
        case brief
        case comma
        case clause
        case sentence
    }

    struct SpeechUnit: Equatable {
        let spoken: String
        let pauseAfter: SpeechPauseKind
    }

    struct Configuration {
        let maxSpeechLength: Int
        let maxChunkLength: Int
        let codePlaceholder: String
        let normalizeAcronyms: Bool
    }
    private static let cacheLimit = 160
    private static var normalizedCache: [String: String] = [:]
    private static var chunkCache: [String: [String]] = [:]
    private static var unitCache: [String: [SpeechUnit]] = [:]
    private static var normalizedOrder: [String] = []
    private static var chunkOrder: [String] = []
    private static var unitOrder: [String] = []

    static func configuration(for mode: SpeechLanguageMode) -> Configuration {
        switch mode {
        case .efficient:
            return Configuration(
                maxSpeechLength: 4_000,
                maxChunkLength: 120,
                codePlaceholder: "这里有一段代码。",
                normalizeAcronyms: false
            )
        case .balanced:
            return Configuration(
                maxSpeechLength: 6_000,
                maxChunkLength: 120,
                codePlaceholder: "这里有一段代码示例。",
                normalizeAcronyms: true
            )
        case .deep:
            return Configuration(
                maxSpeechLength: 8_000,
                maxChunkLength: 72,
                codePlaceholder: "这里有一段代码示例，可在屏幕中查看细节。",
                normalizeAcronyms: true
            )
        }
    }

    /// Converts assistant markdown into plain text suitable for TTS.
    static func plainTextForSpeech(_ text: String, mode: SpeechLanguageMode = .balanced) -> String {
        let cacheKey = makeCacheKey(prefix: "norm", text: text, mode: mode)
        if let cached = normalizedCache[cacheKey] {
            return cached
        }

        let config = configuration(for: mode)
        var result = text

        result = result.replacingOccurrences(
            of: "```[\\s\\S]*?```",
            with: " \(config.codePlaceholder) ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "`([^`]+)`",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^\\)]+\\)",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "(https?://|www\\.)\\S+",
            with: "链接地址",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[*_~>|#]",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "^[\\s\\-•*]+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\s*([。！？!?；;，,：:])\\s*",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[\\t ]+",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{2,}",
            with: "。 ",
            options: .regularExpression
        )
        if config.normalizeAcronyms {
            result = normalizeAcronyms(in: result)
        }
        result = result.replacingOccurrences(of: "->", with: "到")
        result = result.replacingOccurrences(of: "=>", with: "表示")
        result = result.replacingOccurrences(of: ":", with: "：")
        result = result.replacingOccurrences(of: ";", with: "；")
        result = result.replacingOccurrences(of: ",", with: "，")
        result = result.replacingOccurrences(of: ".", with: "。")
        if mode == .deep {
            result = enrichProsodyHints(result)
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized: String
        if trimmed.count > config.maxSpeechLength {
            let end = trimmed.index(trimmed.startIndex, offsetBy: config.maxSpeechLength)
            normalized = String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            normalized = trimmed
        }

        cacheNormalized(normalized, for: cacheKey)
        return normalized
    }

    /// 按标点切分朗读单元：正文不含符号，停顿类型由标点决定。
    static func speechUnits(for text: String, mode: SpeechLanguageMode = .balanced) -> [SpeechUnit] {
        let cacheKey = makeCacheKey(prefix: "unit", text: text, mode: mode)
        if let cached = unitCache[cacheKey] {
            return cached
        }

        let config = configuration(for: mode)
        let normalized = plainTextForSpeech(text, mode: mode)
        let units = splitIntoSpeechUnits(normalized, maxChunkLength: config.maxChunkLength)
        cacheUnits(units, for: cacheKey)
        return units
    }

    /// 在线 / 本地 TTS 句间停顿时长（纳秒）。
    static func pauseNanoseconds(after kind: SpeechPauseKind, engineMode: SpeechEngineMode) -> UInt64 {
        let base: UInt64
        switch engineMode {
        case .fastLocal:
            base = 12_000_000
        case .balancedNeural:
            base = 40_000_000
        case .neuralQuality:
            base = 70_000_000
        case .studioBeauty:
            base = 110_000_000
        }

        switch kind {
        case .brief:
            return base + 35_000_000
        case .comma:
            return base + 75_000_000
        case .clause:
            return base + 120_000_000
        case .sentence:
            return base + 200_000_000
        }
    }

    /// Splits speech text into short, readable chunks.
    static func sentenceChunks(for text: String, mode: SpeechLanguageMode = .balanced) -> [String] {
        speechUnits(for: text, mode: mode).map(\.spoken)
    }

    private static func splitIntoSpeechUnits(_ normalized: String, maxChunkLength: Int) -> [SpeechUnit] {
        guard !normalized.isEmpty else { return [] }

        let delimiters: Set<Character> = [
            "。", "！", "？", "!", "?", "；", ";", "，", ",", "：", ":", "、", "\n", "…",
        ]
        var units: [SpeechUnit] = []
        var buffer = ""

        func flush(with pause: SpeechPauseKind) {
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = ""
            guard !text.isEmpty else { return }
            appendSpeechUnits(from: text, pauseAfter: pause, maxChunkLength: maxChunkLength, to: &units)
        }

        for character in normalized {
            if delimiters.contains(character) {
                flush(with: pauseKind(for: character))
            } else {
                buffer.append(character)
            }
        }
        flush(with: .sentence)
        return units
    }

    private static func appendSpeechUnits(
        from text: String,
        pauseAfter: SpeechPauseKind,
        maxChunkLength: Int,
        to units: inout [SpeechUnit]
    ) {
        if text.count <= maxChunkLength {
            appendUnit(spokenForm(from: text), pauseAfter: pauseAfter, to: &units)
            return
        }

        var remainder = text
        while remainder.count > maxChunkLength {
            let splitAt = splitIndex(in: remainder, maxChunkLength: maxChunkLength)
            let piece = String(remainder[..<splitAt]).trimmingCharacters(in: .whitespacesAndNewlines)
            appendUnit(spokenForm(from: piece), pauseAfter: .comma, to: &units)
            remainder = String(remainder[splitAt...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        appendUnit(spokenForm(from: remainder), pauseAfter: pauseAfter, to: &units)
    }

    private static func appendUnit(_ spoken: String, pauseAfter: SpeechPauseKind, to units: inout [SpeechUnit]) {
        let trimmed = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        units.append(SpeechUnit(spoken: trimmed, pauseAfter: pauseAfter))
    }

    private static func pauseKind(for delimiter: Character) -> SpeechPauseKind {
        switch delimiter {
        case "。", "！", "？", "!", "?", "…", "\n":
            return .sentence
        case "；", ";":
            return .clause
        case "，", ",", "：", ":":
            return .comma
        case "、":
            return .brief
        default:
            return .comma
        }
    }

    /// 送入 TTS 的最终文本：去掉会被读出来的标点与表达符号，保留可读正文。
    static func spokenForm(from chunk: String) -> String {
        var text = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        let wrapperPatterns: [(String, String)] = [
            (#"【([^】]+)】"#, "$1"),
            (#"「([^」]+)」"#, "$1"),
            (#"《([^》]+)》"#, "$1"),
            (#"『([^』]+)』"#, "$1"),
            (#"\(([^)]+)\)"#, "$1"),
            (#"（([^）]+)）"#, "$1"),
            (#"\[([^\]]+)\]"#, "$1"),
        ]
        for (pattern, template) in wrapperPatterns {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }

        text = stripExpressionSymbols(text)
        text = text.replacingOccurrences(
            of: "[\\t ]+",
            with: " ",
            options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripExpressionSymbols(_ text: String) -> String {
        text.replacingOccurrences(
            of: """
            [。！？!?；;，,：:、.…—–\\-~·•●○◆◇★☆※#@$%^&*_+=|\\\\/<>\\[\\]{}「」『』【】《》〈〉"'‘’“”`]+
            """,
            with: "",
            options: .regularExpression
        )
    }

    private static func appendChunk(_ raw: String, to chunks: inout [String], maxChunkLength: Int) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if text.count <= maxChunkLength {
            chunks.append(text)
            return
        }

        var remainder = text
        while remainder.count > maxChunkLength {
            let preferred = splitIndex(in: remainder, maxChunkLength: maxChunkLength)
            let piece = String(remainder[..<preferred]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty {
                chunks.append(piece)
            }
            remainder = String(remainder[preferred...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !remainder.isEmpty {
            chunks.append(remainder)
        }
    }

    private static func enrichProsodyHints(_ text: String) -> String {
        var enriched = text
        enriched = enriched.replacingOccurrences(of: "——", with: "，")
        enriched = enriched.replacingOccurrences(of: "--", with: "，")
        enriched = enriched.replacingOccurrences(of: "…", with: "。")
        enriched = enriched.replacingOccurrences(of: "（", with: "，")
        enriched = enriched.replacingOccurrences(of: "）", with: "，")
        enriched = enriched.replacingOccurrences(of: "(", with: "，")
        enriched = enriched.replacingOccurrences(of: ")", with: "，")
        enriched = enriched.replacingOccurrences(of: "、", with: "，")
        enriched = enriched.replacingOccurrences(
            of: "([。！？!?；;])",
            with: "$1 ",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([一二三四五六七八九十]+)[、.]",
            with: "第 $1 点，",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([0-9]{4})年",
            with: "$1 年",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([A-Za-z]+)([0-9]+)",
            with: "$1 $2",
            options: .regularExpression
        )
        return enriched
    }

    private static func normalizeAcronyms(in text: String) -> String {
        var result = text
        let replacements = [
            ("\\bAI\\b", "A I"),
            ("\\bAPI\\b", "A P I"),
            ("\\bTTS\\b", "T T S"),
            ("\\bLLM\\b", "L L M"),
            ("\\bSDK\\b", "S D K"),
            ("\\bURL\\b", "U R L"),
            ("\\bJSON\\b", "J S O N"),
            ("\\bHTTP\\b", "H T T P"),
            ("\\bHTTPS\\b", "H T T P S"),
            ("\\bSwiftUI\\b", "Swift U I"),
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }

    private static func splitIndex(in text: String, maxChunkLength: Int) -> String.Index {
        let hardEnd = text.index(text.startIndex, offsetBy: maxChunkLength, limitedBy: text.endIndex) ?? text.endIndex
        let searchRange = text.startIndex..<hardEnd
        let preferredDelimiters: [Character] = ["，", "：", "、", " "]

        for delimiter in preferredDelimiters {
            if let index = text[..<hardEnd].lastIndex(of: delimiter), index > text.startIndex {
                return text.index(after: index)
            }
        }

        if let index = text.range(of: "[A-Za-z0-9]+$", options: .regularExpression, range: searchRange)?.lowerBound,
           index > text.startIndex {
            return index
        }

        return hardEnd
    }

    private static func makeCacheKey(prefix: String, text: String, mode: SpeechLanguageMode) -> String {
        var hasher = Hasher()
        hasher.combine(mode.rawValue)
        hasher.combine(text)
        return "\(prefix)#\(mode.rawValue)#\(text.count)#\(hasher.finalize())"
    }

    private static func cacheNormalized(_ value: String, for key: String) {
        normalizedCache[key] = value
        normalizedOrder.append(key)
        trimCacheIfNeeded(store: &normalizedCache, order: &normalizedOrder)
    }

    private static func cacheUnits(_ value: [SpeechUnit], for key: String) {
        unitCache[key] = value
        unitOrder.append(key)
        trimCacheIfNeeded(store: &unitCache, order: &unitOrder)
    }

    private static func cacheChunks(_ value: [String], for key: String) {
        chunkCache[key] = value
        chunkOrder.append(key)
        trimCacheIfNeeded(store: &chunkCache, order: &chunkOrder)
    }

    private static func trimCacheIfNeeded<T>(store: inout [String: T], order: inout [String]) {
        while order.count > cacheLimit {
            let key = order.removeFirst()
            store.removeValue(forKey: key)
        }
    }
}

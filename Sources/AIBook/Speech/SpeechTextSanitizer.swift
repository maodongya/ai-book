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
                maxChunkLength: 96,
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
        } else if mode == .balanced {
            result = enrichBalancedProsodyHints(result)
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
        let units = splitIntoSpeechUnits(normalized, maxChunkLength: config.maxChunkLength, languageMode: mode)
        cacheUnits(units, for: cacheKey)
        return units
    }

    /// Splits speech text into short, readable chunks.
    static func sentenceChunks(for text: String, mode: SpeechLanguageMode = .balanced) -> [String] {
        speechUnits(for: text, mode: mode).map(\.spoken)
    }

    private static func splitIntoSpeechUnits(
        _ normalized: String,
        maxChunkLength: Int,
        languageMode: SpeechLanguageMode
    ) -> [SpeechUnit] {
        guard !normalized.isEmpty else { return [] }

        let delimiters: Set<Character> = [
            "。", "！", "？", "!", "?", "；", ";", "，", ",", "：", ":", "、", "\n", "…",
        ]
        var units: [SpeechUnit] = []
        var buffer = ""

        func flush(with pause: SpeechPauseKind, delimiter: Character? = nil) {
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = ""
            guard !text.isEmpty else { return }
            appendSpeechUnits(
                from: text,
                pauseAfter: pause,
                trailingDelimiter: delimiter,
                maxChunkLength: maxChunkLength,
                languageMode: languageMode,
                to: &units
            )
        }

        for character in normalized {
            if delimiters.contains(character) {
                flush(with: pauseKind(for: character), delimiter: character)
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
        trailingDelimiter: Character? = nil,
        maxChunkLength: Int,
        languageMode: SpeechLanguageMode,
        to units: inout [SpeechUnit]
    ) {
        if text.count <= maxChunkLength {
            appendUnit(
                spokenForm(from: text, trailingDelimiter: trailingDelimiter, languageMode: languageMode),
                pauseAfter: pauseAfter,
                to: &units
            )
            return
        }

        var remainder = text
        while remainder.count > maxChunkLength {
            let splitAt = splitIndex(in: remainder, maxChunkLength: maxChunkLength)
            let piece = String(remainder[..<splitAt]).trimmingCharacters(in: .whitespacesAndNewlines)
            appendUnit(
                spokenForm(from: piece, trailingDelimiter: "，", languageMode: languageMode),
                pauseAfter: .comma,
                to: &units
            )
            remainder = String(remainder[splitAt...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        appendUnit(
            spokenForm(from: remainder, trailingDelimiter: trailingDelimiter, languageMode: languageMode),
            pauseAfter: pauseAfter,
            to: &units
        )
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

    /// 送入 TTS 的最终文本：保留中文韵律标点，去掉会被误读的装饰符号。
    static func spokenForm(
        from chunk: String,
        trailingDelimiter: Character? = nil,
        languageMode: SpeechLanguageMode = .balanced
    ) -> String {
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
        text = softenLongHanRuns(text, maxRun: maxHanRun(for: languageMode))
        text = disambiguateCommonReadings(text)
        text = text.replacingOccurrences(
            of: "[\\t ]+",
            with: " ",
            options: .regularExpression
        )
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trailingDelimiter {
            text += normalizedDelimiter(trailingDelimiter)
        }
        return text
    }

    /// 去掉装饰符号，但保留中文韵律标点，供系统 TTS 把握停顿与咬字。
    private static func stripExpressionSymbols(_ text: String) -> String {
        text.replacingOccurrences(
            of: """
            [.…—–\\-~·•●○◆◇★☆※#@$%^&*_+=|\\\\/<>\\[\\]{}「」『』【】《》〈〉"'‘’“”`]+
            """,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(of: ",", with: "，")
        .replacingOccurrences(of: ";", with: "；")
        .replacingOccurrences(of: ":", with: "：")
        .replacingOccurrences(of: "!", with: "！")
        .replacingOccurrences(of: "?", with: "？")
    }

    private static func normalizedDelimiter(_ character: Character) -> String {
        switch character {
        case ",", ";":
            return "，"
        case ":", ".":
            return "："
        case "!", "?":
            return "！"
        case "\n", "…":
            return "。"
        default:
            return String(character)
        }
    }

    /// 连续汉字过长时插入轻停顿，避免 TTS 连读吞字。
    private static func softenLongHanRuns(_ text: String, maxRun: Int = 10) -> String {
        guard text.count > maxRun else { return text }

        let particles: Set<Character> = [
            "的", "了", "着", "过", "地", "与", "及", "而", "且", "并", "将", "把", "被",
            "向", "从", "以", "于", "在", "是", "也", "就", "都", "还", "又", "或", "如",
            "若", "则", "其", "所", "为", "之", "乎", "哉", "矣", "焉",
        ]
        let prosodyMarks: Set<Character> = ["，", "。", "！", "？", "；", "：", "、"]

        var result = ""
        var run = 0

        for character in text {
            if prosodyMarks.contains(character) {
                run = 0
                result.append(character)
                continue
            }

            if !isCJK(character) {
                run = 0
                result.append(character)
                continue
            }

            run += 1
            result.append(character)

            if run > maxRun {
                if particles.contains(character) || run >= maxRun + 4 {
                    result.append("，")
                    run = 0
                }
            }
        }
        return result
    }

    /// 常见多音字歧义：在易读错的词组中插入轻分隔，帮助 TTS 选对读音。
    private static func disambiguateCommonReadings(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("一行", "一 行"),
            ("两行", "两 行"),
            ("银行", "银 行"),
            ("行业", "行 业"),
            ("行走", "行 走"),
            ("行为", "行 为"),
            ("重要", "重 要"),
            ("重复", "重 复"),
            ("重新", "重 新"),
            ("长期", "长 期"),
            ("成长", "成 长"),
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        return result
    }

    private static func maxHanRun(for mode: SpeechLanguageMode) -> Int {
        switch mode {
        case .efficient:
            return 16
        case .balanced:
            return 14
        case .deep:
            return 12
        }
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value) || (0x3400...0x4DBF).contains(value)
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

    private static func enrichBalancedProsodyHints(_ text: String) -> String {
        var enriched = text
        enriched = enriched.replacingOccurrences(of: "…", with: "。")
        enriched = enriched.replacingOccurrences(of: "、", with: "，")
        enriched = enriched.replacingOccurrences(
            of: "([0-9]{4})年",
            with: "$1 年",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([0-9]+)([年月日])",
            with: "$1 $2",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([\\u4e00-\\u9fff])([A-Za-z])",
            with: "$1 $2",
            options: .regularExpression
        )
        enriched = enriched.replacingOccurrences(
            of: "([A-Za-z])([\\u4e00-\\u9fff])",
            with: "$1 $2",
            options: .regularExpression
        )
        return enriched
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

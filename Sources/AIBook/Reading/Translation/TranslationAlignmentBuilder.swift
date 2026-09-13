import Foundation

/// 把模型 JSON 收成 TranslationAlignment。坏 JSON 失败，不猜。
enum TranslationAlignmentBuilder {
    /// 整段 AI 结果：只接受 JSON，验收不过不降级纯文本。
    static func buildStrictParagraph(
        from llmText: String,
        source: String
    ) -> Result<TranslationAlignment, ParagraphAlignmentValidationFailure> {
        let index = SourceParagraphIndex.build(from: source)
        guard index.count > 0 else {
            return .failure(.countMismatch(expected: 0, actual: 0))
        }

        let trimmed = llmText.trimmingCharacters(in: .whitespacesAndNewlines)  // 去首尾空白，空则直接 empty
        guard !trimmed.isEmpty else {
            return .failure(.countMismatch(expected: index.count, actual: 0))
        }

        let sourceHash = TranslationSourceHasher.hash(source)  // 本地切段也打指纹
        if let translations = decodeParagraphTranslationsJSON(from: trimmed),
           !translations.isEmpty {
            let blocks = blocksFromTranslationItems(translations, index: index)
            switch ParagraphAlignmentValidator.validate(blocks: blocks, index: index, requireSourceTextMatch: false) {
            case .success:
                return .success(
                    makeAlignment(
                        mode: .paragraph,
                        blocks: blocks,
                        sourceHash: sourceHash,
                        strictParagraphValidated: true,
                        provenance: .aiParagraphJSON
                    )
                )
            case .failure(let error):
                return .failure(error)
            }
        }

        guard let payload = decodeParagraphJSON(from: trimmed),
              let jsonBlocks = payload.blocks,
              !jsonBlocks.isEmpty else {
            return .failure(.countMismatch(expected: index.count, actual: 0))
        }

        guard jsonBlocks.count == index.count else {
            return .failure(.countMismatch(expected: index.count, actual: jsonBlocks.count))
        }

        let blocks = zip(jsonBlocks.indices, jsonBlocks).map { order, item in
            let slice = index.slices[order]
            return TranslationBlock(  // 注原样带上
                sourceRange: slice.range,
                sourceText: slice.text,
                translationText: item.translationText,
                note: nonemptyNote(item.notes),
                level: .paragraph,
                order: order
            )
        }

        switch ParagraphAlignmentValidator.validate(blocks: blocks, index: index, requireSourceTextMatch: true) {
        case .success:
            return .success(
                makeAlignment(
                    mode: .paragraph,
                    blocks: blocks,
                    sourceHash: sourceHash,
                    strictParagraphValidated: true,
                    provenance: .aiParagraphJSON
                )
            )
        case .failure(let error):
            return .failure(error)
        }
    }

    /// index-only 译文数组 JSON。
    private struct ParagraphTranslationsJSON: Decodable {
        /// 一段：index + 译文 + 可选注。
        struct Item: Decodable {
            let index: Int
            let translationText: String  // 这一段译文
            let notes: String?  // 可空；空白会在 nonemptyNote 里丢掉
        }

        let mode: String?  // 模型自报的模式，解析不依赖它
        let translations: [Item]?
    }

    /// 从模型原文抠 translations 数组。先围栏后整段，解过的不再解。
    private static func decodeParagraphTranslationsJSON(
        from text: String
    ) -> [ParagraphTranslationsJSON.Item]? {
        var seen = Set<String>()  // 同一候选不解两次
        var candidates: [String] = []  // 围栏抽出、原文、截断修补
        if let extracted = extractJSONText(from: text) {  // 优先 ```json 或最外层 {}
            candidates.append(extracted)  // 抽出的比整段更干净
        }
        candidates.append(text)  // 模型有时整段就是 JSON

        for candidate in candidates {  // 先完整后修补
            guard seen.insert(candidate).inserted else { continue }  // 去重
            if let payload = try? JSONDecoder().decode(ParagraphTranslationsJSON.self, from: Data(candidate.utf8)),
               let items = payload.translations,
               !items.isEmpty {
                return items  // 注仍是 nil
            }
        }
        return nil  // 抠不出任何 JSON
    }

    /// 按原文段序铺块；缺译文的段 translationText 留空。
    private static func blocksFromTranslationItems(
        _ items: [ParagraphTranslationsJSON.Item],
        index: SourceParagraphIndex
    ) -> [TranslationBlock] {
        var byIndex: [Int: ParagraphTranslationsJSON.Item] = [:]
        for item in items {  // 逐段看译文是不是又包了一层 JSON
            byIndex[item.index] = item
        }
        return (0..<index.count).map { order in
            let slice = index.slices[order]
            let item = byIndex[order]
            return TranslationBlock(  // 注原样带上
                sourceRange: slice.range,
                sourceText: slice.text,
                translationText: item?.translationText ?? "",
                note: nonemptyNote(item?.notes),
                level: .paragraph,
                order: order
            )
        }
    }

    /// 先 JSON，失败再纯文本。空输入回 empty。整段 AI 请用 buildStrictParagraph。
    static func build(
        from llmText: String,
        source: String,
        mode: TranslationAlignmentMode
    ) -> TranslationAlignment {
        let sourceHash = TranslationSourceHasher.hash(source)  // 本地切段也打指纹
        let trimmed = llmText.trimmingCharacters(in: .whitespacesAndNewlines)  // 去首尾空白，空则直接 empty
        guard !trimmed.isEmpty else {
            return .empty(mode: mode, sourceHash: sourceHash)  // 没正文可对，保留 mode 和哈希
        }

        if looksLikeJSON(trimmed) || extractJSONText(from: trimmed) != nil,  // 像 JSON 或能抠出 {} 才走解析
           let alignment = parseJSON(trimmed, source: source, mode: mode, sourceHash: sourceHash) {
            return alignment  // JSON 解析成功，不再降级纯文本
        }

        return buildFromPlainText(trimmed, source: source, mode: mode, sourceHash: sourceHash)  // JSON 失败才按旧版纯文本收
    }

    // MARK: - JSON

    /// 整段模式的 JSON 根。
    private struct ParagraphJSON: Decodable {
        /// 一段原文/译文/注。
        struct Block: Decodable {
            let sourceText: String  // 模型声称对应的原文
            let translationText: String  // 这一段译文
            let notes: String?  // 可空；空白会在 nonemptyNote 里丢掉
        }

        let mode: String?  // 模型自报的模式，解析不依赖它
        let blocks: [Block]?  // 整段数组；空或缺则当解析失败
    }

    /// 逐词模式的 JSON 根。
    private struct WordByWordJSON: Decodable {
        /// 一个词条。
        struct Entry: Decodable {
            let source: String  // 词条原文
            let translation: String  // 词条译文
            let note: String?  // 词条注，可空
        }

        let mode: String?  // 模型自报的模式，解析不依赖它
        let entries: [Entry]?  // 逐词条；空则只可能留下摘要
        let summary: String?  // 总译，挂全文 range
        let hardPoints: [String]?  // 难点列表，拼成一块摘要
    }

    /// 按 mode 解。坏 JSON 回 nil 以便走纯文本。
    private static func parseJSON(
        _ jsonText: String,
        source: String,
        mode: TranslationAlignmentMode,
        sourceHash: String
    ) -> TranslationAlignment? {
        switch mode {
        case .paragraph:  // 整段：blocks 不能空
            guard let payload = decodeParagraphJSON(from: jsonText),  // 围栏/原文/截断修补都试过
                  let blocks = payload.blocks,
                  !blocks.isEmpty else { return nil }
            let items = normalizeParagraphItems(  // 和 JSON 路径同一套规范化
                blocks.map {
                    (
                        sourceText: $0.sourceText,
                        translationText: $0.translationText,
                        note: nonemptyNote($0.notes)
                    )
                },
                source: source
            )
            guard !items.isEmpty else { return nil }  // 规范化后没剩段，当失败走纯文本
            return makeAlignment(  // 逐词纯文本回退
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash
            )
        case .wordByWord:  // 逐词：entries + 可选摘要
            guard let jsonBlob = extractJSONText(from: jsonText) ?? (looksLikeJSON(jsonText) ? stripJSONFences(jsonText) : nil),  // 先抠围栏，再去 fence
                  let payload = try? JSONDecoder().decode(WordByWordJSON.self, from: Data(jsonBlob.utf8)) else {
                return nil  // 抠不出任何 JSON
            }
            var blocks = anchorWordBlocks(payload.entries ?? [], in: source)  // 按原文顺序钉词；找不到 range=0
            appendSummaryBlocks(  // 总译和难点挂在全文上
                summary: payload.summary,
                hardPoints: payload.hardPoints,
                to: &blocks,
                source: source
            )
            guard !blocks.isEmpty else { return nil }  // 词和摘要都空，当失败
            return makeAlignment(  // 逐词纯文本回退
                mode: .wordByWord,
                blocks: blocks,
                sourceHash: sourceHash,
                provenance: .aiWordByWordJSON
            )
        }
    }

    /// 多候选：围栏、原文、截断修补。
    private static func decodeParagraphJSON(from text: String) -> ParagraphJSON? {
        var seen = Set<String>()  // 同一候选不解两次
        var candidates: [String] = []  // 围栏抽出、原文、截断修补
        if let extracted = extractJSONText(from: text) {  // 优先 ```json 或最外层 {}
            candidates.append(extracted)  // 抽出的比整段更干净
        }
        candidates.append(text)  // 模型有时整段就是 JSON
        if let repairedFromFull = repairTruncatedParagraphJSON(text) {  // 流被截断时拼回完整 blocks
            candidates.append(repairedFromFull)  // 修补结果放最后试
        }

        for candidate in candidates {  // 先完整后修补
            guard seen.insert(candidate).inserted else { continue }  // 去重
            if let payload = try? JSONDecoder().decode(ParagraphJSON.self, from: Data(candidate.utf8)),  // 坏 JSON 吞掉试下一个
               let blocks = payload.blocks,
               !blocks.isEmpty {
                return payload  // 有非空 blocks 就收
            }
            if let repaired = repairTruncatedParagraphJSON(candidate),  // 当前候选本身被截断再修一次
               let payload = try? JSONDecoder().decode(ParagraphJSON.self, from: Data(repaired.utf8)),
               let blocks = payload.blocks,
               !blocks.isEmpty {
                return payload  // 有非空 blocks 就收
            }
        }
        return nil  // 抠不出任何 JSON
    }

    /// JSON 被截断时尽量保住已经完整的 blocks。
    private static func repairTruncatedParagraphJSON(_ jsonText: String) -> String? {
        guard jsonText.contains("\"blocks\""), jsonText.contains("\"sourceText\"") else { return nil }  // 没有段结构就修不了
        let objects = extractCompleteJSONObjects(from: jsonText, afterKey: "\"blocks\"")  // 只收已经闭合的 {}
        guard !objects.isEmpty else { return nil }  // 一个完整对象都没有
        return #"{"mode":"paragraph","blocks":[\#(objects.joined(separator: ","))]}"#  // 重包成合法根，丢掉截断尾巴
    }

    /// 从截断 JSON 里抠完整的 {} 对象。
    private static func extractCompleteJSONObjects(from text: String, afterKey key: String) -> [String] {
        guard let keyRange = text.range(of: key),  // 从 blocks 键往后找数组
              let arrayStart = text[keyRange.upperBound...].firstIndex(of: "[") else {  // 键后面第一个 [
            return []  // 结构不对，不猜
        }

        var objects: [String] = []  // 已闭合的对象原文
        var index = text.index(after: arrayStart)  // 跳过 [，从第一个元素起
        var depth = 0  // 花括号嵌套；0 表示对象刚结束
        var objectStart: String.Index?  // 当前对象起点
        var inString = false  // 字符串里的括号不算结构
        var escaping = false  // 上一个是反斜杠

        while index < text.endIndex {  // 扫到文件尾，截断的半个对象丢弃
            let character = text[index]  // 当前字符
            if inString {  // 字符串内只处理转义和收引号
                if escaping {  // 转义只吃一个字符
                    escaping = false  // 下一个恢复普通字符
                } else if character == "\\" {  // 进入转义
                    escaping = true  // 下一个不论是什么都当字面
                } else if character == "\"" {  // 字符串结束
                    inString = false  // 后面的括号重新算结构
                }
                index = text.index(after: index)  // 步进
                continue  // 字符串内不改 depth
            }

            if character == "\"" {  // 进入字符串
                inString = true  // 后续括号忽略
            } else if character == "{" {  // 对象开始或嵌套
                if depth == 0 {  // 最外层对象起点
                    objectStart = index  // 记下 {
                }
                depth += 1  // 进入一层
            } else if character == "}" {  // 对象结束或弹出嵌套
                depth -= 1  // 弹出一层
                if depth == 0, let start = objectStart {  // 最外层对象刚闭合
                    objects.append(String(text[start...index]))  // 含首尾花括号的完整对象
                    objectStart = nil  // 等下一个 {
                }
            }
            index = text.index(after: index)  // 步进
        }
        return objects  // 半截对象不收
    }

    /// 空白注当 nil。
    private static func nonemptyNote(_ note: String?) -> String? {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // nil 和空白都当没注
        return trimmed.isEmpty ? nil : trimmed  // 空注不占格子
    }

    // MARK: - Paragraph resegment alignment

    /// 原文按空行切的 range。
    static func sourceParagraphRanges(in source: String) -> [(range: NSRange, text: String)] {
        paragraphRanges(in: source)  // 转给 ParagraphText 按空行切
    }

    /// 从 searchStart 往后找，找不到再从头。
    static func reanchorSourceText(
        _ sourceText: String,
        in source: String,
        searchStart: Int = 0
    ) -> NSRange {
        let needle = normalized(sourceText)  // 空白压成单空格再搜
        guard !needle.isEmpty else { return NSRange(location: 0, length: 0) }  // 空针钉不住

        let ns = source as NSString  // UTF-16 下标
        let start = max(0, min(searchStart, ns.length))  // 夹进全文，避免越界
        let forwardRange = NSRange(location: start, length: max(0, ns.length - start))  // 先从 searchStart 往后
        var found = ns.range(of: needle, options: [], range: forwardRange)  // 精确匹配，不模糊
        if found.location == NSNotFound {  // 后半没有再从头
            found = ns.range(of: needle, options: [], range: NSRange(location: 0, length: ns.length))  // 全文再找一次
        }
        return found.location == NSNotFound ? NSRange(location: 0, length: 0) : found  // 找不到给空 range，调用方当未锚定
    }

    /// 本地切段结果对上原文各段。
    static func buildParagraphAlignment(
        source: String,
        segments: [TranslationParagraphSegmenter.Segment]
    ) -> TranslationAlignment {
        let sourceHash = TranslationSourceHasher.hash(source)  // 本地切段也打指纹
        let sourceParagraphs = paragraphRanges(in: source)  // 原文段，按下标对译文段
        let blocks = segments.enumerated().map { order, segment in  // 下标对不上就空 range
            let sourceParagraph = sourceParagraphs.indices.contains(order) ? sourceParagraphs[order] : nil  // 译文比原文多的段钉不住
            return TranslationBlock(  // 注原样带上
                sourceRange: sourceParagraph?.range ?? NSRange(location: 0, length: 0),
                sourceText: sourceParagraph?.text ?? "",
                translationText: segment.text,
                note: segment.note,
                level: .paragraph,
                order: order
            )
        }
        return makeAlignment(mode: .paragraph, blocks: blocks, sourceHash: sourceHash)  // 本地对齐同样 isStale=false
    }

    // MARK: - Plain text fallback

    /// 旧版「词 → 译」或整段纯文本。
    private static func buildFromPlainText(
        _ text: String,
        source: String,
        mode: TranslationAlignmentMode,
        sourceHash: String
    ) -> TranslationAlignment {
        switch mode {
        case .paragraph:  // 整段：blocks 不能空
            let entries = TranslationLineParser.parseParagraphSections(stripDisplayChrome(text))  // 先剥【标题】和围栏
            let items = normalizeParagraphItems(  // 和 JSON 路径同一套规范化
                entries.map {  // JSON 字段名和解析器不一致
                    (sourceText: $0.sourceText, translationText: $0.translationText, note: $0.note)
                },
                source: source
            )
            return makeAlignment(  // 逐词纯文本回退
                mode: .paragraph,
                blocks: anchorParagraphBlocks(items, in: source),
                sourceHash: sourceHash
            )
        case .wordByWord:  // 逐词：entries + 可选摘要
            let entries = TranslationLineParser.parseWordByWordLines(text)  // 旧版「词 → 译」行
            var blocks = anchorWordEntries(entries, in: source)  // 按原文顺序钉
            if blocks.isEmpty, !text.isEmpty {  // 一行都解析不出，整篇当摘要
                blocks.append(  // sourceText 写死「难点词语」给表格标题
                    TranslationBlock(
                        sourceRange: fullSourceRange(source),
                        sourceText: source.trimmingCharacters(in: .whitespacesAndNewlines),
                        translationText: text,
                        level: .summary,
                        order: 0
                    )
                )
            }
            return makeAlignment(  // 逐词纯文本回退
                mode: .wordByWord,
                blocks: blocks,
                sourceHash: sourceHash
            )
        }
    }

    // MARK: - Anchoring

    /// 按原文顺序给每段 sourceRange。
    private static func anchorParagraphBlocks(
        _ items: [(sourceText: String, translationText: String, note: String?)],
        in source: String
    ) -> [TranslationBlock] {
        let paragraphs = paragraphRanges(in: source)  // 后面用来判断要不要再切
        return items.enumerated().map { order, item in  // 多出来的段 range 置 0
            if paragraphs.indices.contains(order) {  // 有对应原文段就用它的 range/text
                let candidate = paragraphs[order]  // 信任原文切段，不信模型 sourceText
                return TranslationBlock(  // 注原样带上
                    sourceRange: candidate.range,
                    sourceText: candidate.text,
                    translationText: item.translationText,
                    note: item.note,
                    level: .paragraph,
                    order: order
                )
            }
            return TranslationBlock(  // 注原样带上
                sourceRange: NSRange(location: 0, length: 0),
                sourceText: normalized(item.sourceText),
                translationText: item.translationText,
                note: item.note,
                level: .paragraph,
                order: order
            )
        }
    }

    /// 一段里嵌了 JSON 就拆开。
    private static func normalizeParagraphItems(
        _ items: [(sourceText: String, translationText: String, note: String?)],
        source: String
    ) -> [(sourceText: String, translationText: String, note: String?)] {
        let paragraphs = paragraphRanges(in: source)  // 后面用来判断要不要再切
        var resolved: [(sourceText: String, translationText: String, note: String?)] = []  // 展开嵌套后的段

        for item in items {  // 逐段看译文是不是又包了一层 JSON
            if looksLikeJSON(item.translationText),  // 模型有时把整份 JSON 塞进一段译文
               let nested = decodeParagraphItems(from: item.translationText),  // 至少 2 段才算嵌套成功
               nested.count > 1 {
                resolved.append(contentsOf: nested)  // 用内层段替换这一段
            } else {  // 按空行切译文再 zip
                resolved.append(  // 保留原文和注
                    (
                        sourceText: item.sourceText,
                        translationText: stripJSONFences(item.translationText),
                        note: item.note
                    )
                )
            }
        }

        if resolved.count <= 1, paragraphs.count > 1 {  // 一对多：一段译文对多段原文
            let blob = resolved.first.map(\.translationText) ?? items.first?.translationText ?? ""  // 取出那坨译文再切
            if looksLikeJSON(blob), let nested = decodeParagraphItems(from: blob), nested.count > 1 {  // blob 本身是多段 JSON
                resolved = nested  // 换成内层
            } else {  // 按空行切译文再 zip
                let translationParagraphs = paragraphRanges(in: stripJSONFences(blob)).map(\.text)  // 译文按空行切
                if translationParagraphs.count > 1 {  // 切得开才 zip，切不开保持一段
                    resolved = zipParagraphs(paragraphs.map(\.text), translationParagraphs)  // 多出的译文并进最后一段
                }
            }
        }

        return resolved.filter {  // 空译文段丢掉，避免空行占表
            !$0.translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 只看译文，原文空仍可留
        }
    }

    /// 译文多出来的并进最后一段。
    private static func zipParagraphs(
        _ sources: [String],
        _ translations: [String]
    ) -> [(sourceText: String, translationText: String, note: String?)] {
        let paired = min(sources.count, translations.count)  // 按短的对齐
        guard paired > 0 else { return [] }  // 任一侧空就没有可对的

        var items: [(sourceText: String, translationText: String, note: String?)] = (0..<paired).map { index in  // 一对一，注先空
            (sourceText: sources[index], translationText: translations[index], note: nil)  // 按下标配，不搜文本
        }
        if translations.count > paired {  // 译文比原文多
            let extra = translations[paired...].joined(separator: "\n\n")  // 多出来的用空行拼回
            items[paired - 1].translationText += "\n\n\(extra)"  // 挂在最后一段，不另开行
        }
        return items  // 注仍是 nil
    }

    /// 从嵌套 JSON 抽出段。少于 2 段当失败。
    private static func decodeParagraphItems(
        from text: String
    ) -> [(sourceText: String, translationText: String, note: String?)]? {
        guard let payload = decodeParagraphJSON(from: text),  // 复用同一套候选/修补
              let blocks = payload.blocks,
              blocks.count > 1 else {  // 只有 1 段不算嵌套，避免死循环
            return nil  // 抠不出任何 JSON
        }
        return blocks.map {  // 转成 normalize 用的三元组
            (sourceText: $0.sourceText, translationText: $0.translationText, note: nonemptyNote($0.notes))  // 空注变 nil
        }
    }

    /// 围栏、blocks、mode 任一即当 JSON。
    private static func looksLikeJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 先去空白再认标记
        return trimmed.contains("```json")  // 围栏最明确
            || trimmed.contains("\"blocks\"")  // 整段 JSON 特征
            || trimmed.contains("\"mode\"")  // 根上常有 mode
            || (trimmed.hasPrefix("{") && trimmed.contains("translationText"))  // 没围栏的裸对象
    }

    /// 去掉 ```json 围栏。
    private static func stripJSONFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 围栏前后都可能有空行
        if result.hasPrefix("```json") {  // 带语言标记
            result.removeFirst("```json".count)  // 去掉开头围栏
        } else if result.hasPrefix("```") {  // 普通围栏
            result.removeFirst(3)  // 只去三个撇
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)  // 开头围栏后常跟换行
        if result.hasSuffix("```") {  // 收尾围栏
            result.removeLast(3)  // 去掉结尾
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)  // 再清一次尾空白
    }

    /// 去掉【标题】再去围栏。
    private static func stripDisplayChrome(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)  // 保留空行，后面还要切段
        if let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),  // 首行是【标题】才剥
           first.hasPrefix("【"), first.hasSuffix("】") {  // 成对书名号
            lines.removeFirst()  // 标题不进解析
        }
        return stripJSONFences(lines.joined(separator: "\n"))  // 剥完标题再去围栏
    }

    /// JSON entries 转 ParsedEntry 再锚定。
    private static func anchorWordBlocks(
        _ entries: [WordByWordJSON.Entry],
        in source: String
    ) -> [TranslationBlock] {
        anchorWordEntries(  // 转成 ParsedEntry 再钉
            entries.map {  // JSON 字段名和解析器不一致
                TranslationLineParser.ParsedEntry(  // 和纯文本路径共用锚定
                    sourceText: $0.source,
                    translationText: $0.translation,
                    note: $0.note
                )
            },
            in: source
        )
    }

    /// 按原文顺序找词。找不到 range 为 0。
    private static func anchorWordEntries(
        _ entries: [TranslationLineParser.ParsedEntry],
        in source: String
    ) -> [TranslationBlock] {
        let ns = source as NSString  // UTF-16 下标
        var searchLocation = 0  // 只往前找，避免同一词钉两次

        return entries.enumerated().map { order, entry in  // 顺序即 order
            let needle = normalized(entry.sourceText)  // 和原文空白对齐
            let searchRange = NSRange(location: searchLocation, length: max(0, ns.length - searchLocation))  // 从上次结束处继续
            let found = ns.range(of: needle, options: [], range: searchRange)  // 精确匹配
            let range = found.location == NSNotFound ? NSRange(location: 0, length: 0) : found  // 找不到不回头搜，避免错位
            if found.location != NSNotFound {  // 钉住了才推进
                searchLocation = found.location + found.length  // 下一词从这里往后
            }
            let level: TranslationBlockLevel = needle.count >= 4 ? .phrase : .word  // 短的当词，长的当短语
            return TranslationBlock(  // 注原样带上
                sourceRange: range,
                sourceText: needle,
                translationText: entry.translationText,
                note: entry.note,
                level: level,
                order: order
            )
        }
    }

    /// 总译和难点挂在全文 range 上。
    private static func appendSummaryBlocks(
        summary: String?,
        hardPoints: [String]?,
        to blocks: inout [TranslationBlock],
        source: String
    ) {
        var order = (blocks.map(\.order).max() ?? -1) + 1  // 接在词条后面，避免和词 order 撞
        let fullRange = fullSourceRange(source)  // 摘要对整篇，滚动时滚到文首

        if let summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 空总译不占行
            blocks.append(  // sourceText 写死「难点词语」给表格标题
                TranslationBlock(
                    sourceRange: fullRange,
                    sourceText: source.trimmingCharacters(in: .whitespacesAndNewlines),
                    translationText: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    level: .summary,
                    order: order
                )
            )
            order += 1  // 难点还要用下一个号
        }

        if let hardPoints, !hardPoints.isEmpty {  // 有难点列表才拼
            let text = hardPoints  // 去空白、丢掉空项、换行拼
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }  // 每项去空白
                .filter { !$0.isEmpty }  // 空项丢掉
                .joined(separator: "\n")  // 一项一行
            guard !text.isEmpty else { return }  // 滤完可能全空
            blocks.append(  // sourceText 写死「难点词语」给表格标题
                TranslationBlock(
                    sourceRange: fullRange,
                    sourceText: "难点词语",
                    translationText: text,
                    level: .summary,
                    order: order
                )
            )
        }
    }

    /// 转给 ParagraphText。
    private static func paragraphRanges(in source: String) -> [(range: NSRange, text: String)] {
        TranslationParagraphText.contentParagraphRanges(in: source)  // 空行切，丢掉空段
    }

    /// 整篇 UTF-16 range。
    private static func fullSourceRange(_ source: String) -> NSRange {
        NSRange(location: 0, length: (source as NSString).length)  // UTF-16 全文
    }

    /// 新对齐，isStale=false。
    private static func makeAlignment(
        mode: TranslationAlignmentMode,
        blocks: [TranslationBlock],
        sourceHash: String,
        strictParagraphValidated: Bool = false,
        provenance: TranslationProvenance = .aiParagraphJSON
    ) -> TranslationAlignment {
        return TranslationAlignment(  // createdAt 现在，isStale 新对齐为假
            mode: mode,
            blocks: blocks,
            sourceContentHash: sourceHash,
            createdAt: Date(),
            isStale: false,
            strictParagraphValidated: strictParagraphValidated,
            provenance: provenance
        )
    }

    /// 优先 ```json，再任意 {}。
    private static func extractJSONText(from text: String) -> String? {
        if let fenceStart = text.range(of: "```json"),  // 优先带语言的围栏
           let fenceEnd = text[fenceStart.upperBound...].range(of: "```") {  // 同样要配对
            return String(text[fenceStart.upperBound..<fenceEnd.lowerBound])  // 不含围栏本身
                .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空白不参与比较
        }
        if let fenceStart = text.range(of: "```"),  // 普通围栏兜底
           let fenceEnd = text[fenceStart.upperBound...].range(of: "```") {  // 同样要配对
            let candidate = String(text[fenceStart.upperBound..<fenceEnd.lowerBound])  // 看是不是 JSON
                .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空白不参与比较
            if candidate.hasPrefix("{") { return candidate }  // 围栏里不是对象就忽略
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {  // 最外层一对，可能含说明文字
            return String(text[start...end])  // 含首尾花括号
        }
        return nil  // 抠不出任何 JSON
    }

    /// 空白压成单空格再比。
    private static func normalized(_ text: String) -> String {
        text  // 先去首尾再压内部空白
            .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空白不参与比较
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)  // 换行和多空格压成单空格
    }

    /// 规范化后是否同一句。
    private static func textsMatch(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalized(lhs)  // 左侧规范化
        let b = normalized(rhs)  // 右侧规范化
        if a.isEmpty || b.isEmpty { return false }  // 空对空不当相同
        if a == b { return true }  // 压空白后全等
        let shorter = a.count < b.count ? a : b  // 短的当子串
        let longer = a.count < b.count ? b : a  // 长的当容器
        guard shorter.count >= 12 else { return false }  // 太短的子串匹配不可靠
        let ratio = Double(shorter.count) / Double(max(longer.count, 1))  // 长度比，防一句对整篇
        return ratio >= 0.45 && longer.contains(shorter)  // 够长且被包含才算同一句
    }
}

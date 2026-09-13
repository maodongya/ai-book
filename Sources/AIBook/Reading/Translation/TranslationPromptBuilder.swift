import Foundation

/// 拼翻译提示。目标语元数据必须稳定，JSON 字段名不译。
enum TranslationPromptBuilder {
    /// existingPlan/instruction 空则不加那两段，避免空标题骗模型。
    static func build(
        source: String, // 左页原文，必须整篇自包含
        existingPlan: String?, // 已有译文，只作改写参考
        instruction: String?, // 用户这轮额外要求，可空
        mode: TranslationAlignmentMode, // 决定 JSON 形状，和解析器必须一致
        targetLanguage: TranslationTargetLanguage, // 调用前必须已 resolved，禁止 .followAppLanguage
        paragraphIndices: [Int]? = nil // 整段分批或补译时只带这些 index，nil 表示全部
    ) -> String {
        let paragraphCount = countParagraphs(in: source) // 整段模式用来锁 blocks 条数
        let selectedIndices = resolvedParagraphIndices(paragraphIndices, count: paragraphCount) // 非法下标丢掉
        let taskIntro: String
        let outputFormat: String

        switch mode {
        case .wordByWord:
            taskIntro = """
            请对左侧文章做逐字翻译，供原文对照与表格查阅使用。
            要求：按原文顺序逐字、逐词、短语拆解；每项给出原文、译文和必要的极简说明；不扩写成教案，不啰嗦，不重复。
            """
            outputFormat = """
            请只输出 JSON（可放在 ```json 代码块内），格式如下：
            {
              "mode": "wordByWord",
              "entries": [
                { "source": "原文词", "translation": "译文", "note": "可选说明" }
              ],
              "summary": "一句话总译",
              "hardPoints": ["难点词语说明"]
            }
            要求：entries 顺序必须与原文一致；source 必须是原文中的连续子串。
            """
        case .paragraph:
            let batchCount = selectedIndices.count // 本批必须交齐的条数
            let indexList = selectedIndices.map(String.init).joined(separator: ", ") // 给模型看的下标清单
            let batchNote: String
            if selectedIndices.count == paragraphCount {
                batchNote = "原文共 \(paragraphCount) 段，translations 必须正好 \(paragraphCount) 项，index 从 0 到 \(max(0, paragraphCount - 1))，顺序一致。"  // 一次译完全文
            } else {
                batchNote = "原文共 \(paragraphCount) 段。本批只翻译这些 index：\(indexList)。translations 必须正好 \(batchCount) 项，禁止省略其中任何一段，禁止改 index。"  // 分批或补译
            }
            taskIntro = """
            请对左侧文章做整段翻译，供原文对照与表格查阅使用。
            要求：一段原文对应一段译文；译文通顺准确；只输出翻译与少量必要注释，不写教案。
            \(batchNote)
            """
            let paragraphIndexJSON = paragraphIndexAttachment(for: source, indices: selectedIndices)
            outputFormat = """
            请只输出 JSON（可放在 ```json 代码块内），格式如下：
            {
              "mode": "paragraph",
              "translations": [
                { "index": 0, "translationText": "第一段译文", "notes": null }
              ]
            }
            要求：不要输出或修改 sourceText；只填 translationText 与可选 notes；index 必须覆盖本批每一段。
            """
            var sections = [ // 顺序：自包含声明、目标语、任务、格式、段落索引、原文
                "本请求完全自包含：不要依赖任何对话历史。即使刚清空上下文，也必须只根据下面的【左侧文章】完成翻译。",
                targetLanguageSection(for: targetLanguage), // 已 resolved 的目标语，含古文须白话
                taskIntro,
                outputFormat,
                paragraphIndexJSON,
                sourceSection(for: source, indices: selectedIndices),
            ]

            if let existingPlan, !existingPlan.isEmpty { // 有旧译文才附上，仍要求覆盖本批
                sections.append("【现有翻译内容（仅供改写参考，仍须覆盖本批全部原文）】\n\(existingPlan)")
            }
            if let instruction, !instruction.isEmpty {
                sections.append("【本次翻译要求】\n\(instruction)")
            }

            return sections.joined(separator: "\n\n")
        }

        var sections = [ // 顺序：自包含声明、目标语、任务、格式、原文
            "本请求完全自包含：不要依赖任何对话历史。即使刚清空上下文，也必须只根据下面的【左侧文章】完成翻译。",
            targetLanguageSection(for: targetLanguage), // 已 resolved 的目标语，含古文须白话
            taskIntro,
            outputFormat,
            "【左侧文章】\n\(source)",
        ]

        if let existingPlan, !existingPlan.isEmpty { // 有旧译文才附上，仍要求覆盖全文
            sections.append("【现有翻译内容（仅供改写参考，仍须覆盖全部原文）】\n\(existingPlan)")
        }
        if let instruction, !instruction.isEmpty {
            sections.append("【本次翻译要求】\n\(instruction)")
        }

        return sections.joined(separator: "\n\n")
    }

    /// 调用方必须先 resolved。followAppLanguage 直接 precondition。
    private static func targetLanguageSection(
        for targetLanguage: TranslationTargetLanguage
    ) -> String {
        precondition(targetLanguage != .followAppLanguage) // 未解析的跟随值禁止进提示
        var requirements = [
            "【目标语言】\(targetLanguage.promptLanguageName)（\(targetLanguage.bcp47Identifier)）", // 语言名+BCP-47，测试锁这两项
            "所有译文、总结、难点和注释必须使用目标语言；JSON 字段名保持不变。", // 字段名译走解析会挂
        ]
        if targetLanguage == .zhHans { // 简中还要规定古文出白话
            requirements.append(
                "输出现代简体中文；原文若为古文、文言文或古典汉语，须译成通顺准确的现代白话文，并仅保留必要的古文词义说明。"
            )
        }
        return requirements.joined(separator: "\n")
    }

    /// 丢掉越界下标；未指定则用 0…n-1。
    private static func resolvedParagraphIndices(_ requested: [Int]?, count: Int) -> [Int] {
        if let requested {
            return requested.filter { $0 >= 0 && $0 < count }  // 只留合法段号
        }
        guard count > 0 else { return [] }  // 原文没有段
        return Array(0..<count)  // 全文
    }

    /// 客户端附上的段落索引，模型只填 translations。
    private static func paragraphIndexAttachment(for source: String, indices: [Int]) -> String {
        let index = SourceParagraphIndex.build(from: source)
        let items = indices.compactMap { order -> String? in
            guard index.slices.indices.contains(order) else { return nil }  // 越界丢掉
            let slice = index.slices[order]  // 这一段原文
            return """
            {"index":\(order),"sourceText":\(jsonEscaped(slice.text))}
            """
        }
        return """
        【段落索引（勿改 sourceText，按 index 填 translationText）】
        [\(items.joined(separator: ","))]
        """
    }

    /// 分批时【左侧文章】只放本批原文，避免模型漏后段。
    private static func sourceSection(for source: String, indices: [Int]) -> String {
        let index = SourceParagraphIndex.build(from: source)
        if indices.count == index.count {
            return "【左侧文章】\n\(source)"  // 一次译完全文
        }
        let parts = indices.compactMap { order -> String? in
            guard index.slices.indices.contains(order) else { return nil }  // 越界丢掉
            return index.slices[order].text  // 只带本批
        }
        return "【左侧文章】\n\(parts.joined(separator: "\n\n"))"
    }

    /// 把原文段打进 JSON 字符串。编码失败给空串，避免提示词破形。
    private static func jsonEscaped(_ text: String) -> String {
        if let data = try? JSONEncoder().encode(text),
           let encoded = String(data: data, encoding: .utf8) {
            return encoded
        }
        return "\"\""
    }

    /// 与 SourceParagraphIndex 段数一致。
    static func countParagraphs(in source: String) -> Int {
        SourceParagraphIndex.build(from: source).count
    }
}

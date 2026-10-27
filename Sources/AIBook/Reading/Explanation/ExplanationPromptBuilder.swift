import Foundation

/// 拼全文/分批讲解提示。JSON 形状与整段翻译一致，便于严格段对齐（translationText 填讲解正文）。
enum ExplanationPromptBuilder {
    static func build(
        source: String,
        paragraphIndices: [Int]? = nil,
        optionalContext: String? = nil,
        targetLanguage: TranslationTargetLanguage
    ) -> String {
        precondition(targetLanguage != .followAppLanguage) // 未解析的跟随值禁止进提示
        let paragraphCount = SourceParagraphIndex.build(from: source).count
        let selectedIndices = resolvedParagraphIndices(paragraphIndices, count: paragraphCount)
        let batchCount = selectedIndices.count
        let indexList = selectedIndices.map(String.init).joined(separator: ", ")
        let batchNote: String
        if selectedIndices.count == paragraphCount {
            batchNote = "原文共 \(paragraphCount) 段，translations 必须正好 \(paragraphCount) 项，index 从 0 到 \(max(0, paragraphCount - 1))，顺序一致。"
        } else {
            batchNote = "原文共 \(paragraphCount) 段。本批只讲解这些 index：\(indexList)。translations 必须正好 \(batchCount) 项，禁止省略其中任何一段，禁止改 index。"
        }

        let taskIntro = """
        请对左侧文章逐段讲解，供原文与讲解对照表使用。
        要求：一段原文对应一段讲解；讲解清楚该段含义、要点或难点，不要写成教案长文，不要重复原文全文。
        \(batchNote)
        """

        let outputFormat = """
        请只输出 JSON（可放在 ```json 代码块内），格式如下：
        {
          "mode": "paragraph",
          "translations": [
            { "index": 0, "translationText": "第一段讲解", "notes": null }
          ]
        }
        要求：不要输出或修改 sourceText；只填 translationText（讲解正文）与可选 notes；index 必须覆盖本批每一段。
        """

        let paragraphIndexJSON = paragraphIndexAttachment(for: source, indices: selectedIndices)

        var sections = [
            "本请求完全自包含：不要依赖任何对话历史。即使刚清空上下文，也必须只根据下面的【左侧文章】完成讲解。",
            targetLanguageSection(for: targetLanguage),
            taskIntro,
            outputFormat,
            paragraphIndexJSON,
            sourceSection(for: source, indices: selectedIndices),
        ]
        if let optionalContext {
            let trimmed = optionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                sections.append("【上下文参考（勿改 index，讲解仍以【左侧文章】各段为准）】\n\(trimmed)")
            }
        }

        return sections.joined(separator: "\n\n")
    }

    /// 调用方必须先传入具体语言。讲解正文和注释用目标语言，JSON 字段名不译。
    private static func targetLanguageSection(
        for targetLanguage: TranslationTargetLanguage
    ) -> String {
        precondition(targetLanguage != .followAppLanguage)
        var requirements = [
            "【目标语言】\(targetLanguage.promptLanguageName)（\(targetLanguage.bcp47Identifier)）",
            "所有讲解正文和注释必须使用目标语言；JSON 字段名保持不变。",
        ]
        if targetLanguage == .zhHans {
            requirements.append(
                "输出现代简体中文；原文若为古文、文言文或古典汉语，讲解须用通顺的现代白话文。"
            )
        }
        return requirements.joined(separator: "\n")
    }

    private static func resolvedParagraphIndices(_ requested: [Int]?, count: Int) -> [Int] {
        if let requested {
            return requested.filter { $0 >= 0 && $0 < count }
        }
        guard count > 0 else { return [] }
        return Array(0..<count)
    }

    private static func paragraphIndexAttachment(for source: String, indices: [Int]) -> String {
        let index = SourceParagraphIndex.build(from: source)
        let items = indices.compactMap { order -> String? in
            guard index.slices.indices.contains(order) else { return nil }
            let slice = index.slices[order]
            return """
            {"index":\(order),"sourceText":\(jsonEscaped(slice.text))}
            """
        }
        return """
        【段落索引（勿改 sourceText，按 index 填 translationText 讲解）】
        [\(items.joined(separator: ","))]
        """
    }

    private static func sourceSection(for source: String, indices: [Int]) -> String {
        let index = SourceParagraphIndex.build(from: source)
        if indices.count == index.count {
            return "【左侧文章】\n\(source)"
        }
        let parts = indices.compactMap { order -> String? in
            guard index.slices.indices.contains(order) else { return nil }
            return index.slices[order].text
        }
        return "【左侧文章】\n\(parts.joined(separator: "\n\n"))"
    }

    private static func jsonEscaped(_ text: String) -> String {
        if let data = try? JSONEncoder().encode(text),
           let encoded = String(data: data, encoding: .utf8) {
            return encoded
        }
        return "\"\""
    }
}

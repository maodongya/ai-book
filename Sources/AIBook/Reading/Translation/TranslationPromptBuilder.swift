import Foundation

enum TranslationPromptBuilder {
    static func build(
        source: String,
        existingPlan: String?,
        instruction: String?,
        mode: TranslationAlignmentMode
    ) -> String {
        let paragraphCount = countParagraphs(in: source)
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
            taskIntro = """
            请对左侧文章做整段翻译，供原文对照与表格查阅使用。
            要求：一段原文对应一段译文；译文通顺准确；只输出翻译与少量必要注释，不写教案。
            原文共 \(paragraphCount) 段，blocks 必须正好 \(paragraphCount) 项，顺序一致。
            """
            outputFormat = """
            请只输出 JSON（可放在 ```json 代码块内），格式如下：
            {
              "mode": "paragraph",
              "blocks": [
                {
                  "sourceText": "第一段原文",
                  "translationText": "第一段译文",
                  "notes": "可选注释"
                }
              ]
            }
            要求：sourceText 必须来自原文对应段落，不要合并或拆段。
            """
        }

        var sections = [
            "本请求完全自包含：不要依赖任何对话历史。即使刚清空上下文，也必须只根据下面的【左侧文章】完成翻译。",
            taskIntro,
            outputFormat,
            "【左侧文章】\n\(source)",
        ]

        if let existingPlan, !existingPlan.isEmpty {
            sections.append("【现有翻译内容（仅供改写参考，仍须覆盖全部原文）】\n\(existingPlan)")
        }
        if let instruction, !instruction.isEmpty {
            sections.append("【本次翻译要求】\n\(instruction)")
        }

        return sections.joined(separator: "\n\n")
    }

    static func countParagraphs(in source: String) -> Int {
        source
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
}

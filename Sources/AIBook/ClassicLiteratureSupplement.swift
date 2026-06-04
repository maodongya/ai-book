import Foundation

/// 识别左页名著节选并由大模型补全为完整篇章。
enum ClassicLiteratureSupplement {
    static let capabilityLabel = "名著补充"
    static let shortcutHint = "⌘⇧C"

    static let markerStart = "<<<名著补充>>>"
    static let markerEnd = "<<<END>>>"

    static let systemPrompt = """
    你是 \(AIBookProduct.displayName) 的名著补全专家。用户左页可能只有某部中国或外国经典名著的节选、残篇或缺段文字。
    请根据原文风格与上下文，识别作品与位置，补全缺失内容，输出连贯、可阅读的完整篇章。
    要求：
    1. 保持原著叙述风格与人物称谓，不现代口语化改写
    2. 若无法确定具体版本，按通行全本/教材本常见写法补全
    3. 仅输出补全后的正文，不要解释过程
    4. 正文必须放在标记块内（见用户说明）
    """

    static func buildPrompt(source: String, isSelection: Bool) -> String {
        let scope = isSelection ? "左页选中节选" : "左页全文"
        return """
        【任务】名著补充：将下列\(scope)补全为完整、连贯的名著篇章。

        【\(scope)】
        \(source)

        请先识别「书名 / 作者 / 章节或段落」，再输出补全后的全文。
        补全正文请严格使用以下格式（标记外不要其他内容）：
        \(markerStart)
        （第一行可写：【书名】… 【作者】… 【章节】…，随后为补全正文）
        \(markerEnd)
        """
    }

    static func extractContent(from reply: String) -> String? {
        guard
            let start = reply.range(of: markerStart),
            let end = reply.range(of: markerEnd, range: start.upperBound ..< reply.endIndex)
        else { return nil }

        let content = reply[start.upperBound ..< end.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    static func stripMarkers(from text: String) -> String {
        text
            .replacingOccurrences(of: markerStart, with: "")
            .replacingOccurrences(of: markerEnd, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

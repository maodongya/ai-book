import Foundation

/// 识别左页名著节选并由大模型补全为完整篇章。
enum ClassicLiteratureSupplement {
    /// 设置/能力列表上的短名。
    static var capabilityLabel: String { BookL10n.string("classic.capabilityLabel") }

    /// 工具栏按钮文案，和 capabilityLabel 不是同一条 key。
    static var localizedCapabilityLabel: String {
        BookL10n.string("action.classicSupplement")
    }
    static let shortcutHint = BookKeyboardShortcuts.classicSupplementHint // 菜单快捷键提示，和按钮文案分开

    static let markerStart = "<<<名著补充>>>" // 模型必须把正文包进这对标记，解析只认这个
    static let markerEnd = "<<<END>>>"

    /// 补全专家人设：只出标记块内正文，不写过程。
    static let systemPrompt = """
    你是 \(AIBookProduct.displayName) 的名著补全专家。用户左页可能只有某部中国或外国经典名著的节选、残篇或缺段文字。
    请根据原文风格与上下文，识别作品与位置，补全缺失内容，输出连贯、可阅读的完整篇章。
    要求：
    1. 保持原著叙述风格与人物称谓，不现代口语化改写
    2. 若无法确定具体版本，按通行全本/教材本常见写法补全
    3. 仅输出补全后的正文，不要解释过程
    4. 正文必须放在标记块内（见用户说明）
    """

    /// isSelection 决定提示里写「选中节选」还是「全文」，避免模型补错范围。
    static func buildPrompt(source: String, isSelection: Bool) -> String {
        let scope = isSelection ? "左页选中节选" : "左页全文" // 写进提示，模型按这个范围补
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

    /// 只取标记之间。缺一头或中间空则 nil，不把闲聊当正文。
    static func extractContent(from reply: String) -> String? {
        guard
            let start = reply.range(of: markerStart), // 找不到起始标记就当模型没按规定输出
            let end = reply.range(of: markerEnd, range: start.upperBound ..< reply.endIndex)
        else { return nil }

        let content = reply[start.upperBound ..< end.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content // 空块不当成功
    }

    /// 展示给用户前去掉标记，防止「<<<名著补充>>>」出现在书页上。
    static func stripMarkers(from text: String) -> String {
        text
            .replacingOccurrences(of: markerStart, with: "")
            .replacingOccurrences(of: markerEnd, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

/// Reading-assistant persona for ai-book (command #1); branding lives in AIBookProduct.
enum ReadingAssistant {
    static var tagline: String { AIBookProduct.tagline }

    static let systemPrompt = """
    你是 \(AIBookProduct.displayName)（\(AIBookProduct.slug)）的读书助手。\(AIBookProduct.positioning)
    请用清晰、易懂的中文帮助读者理解文本，包括字面含义、上下文作用、重点与难点。
    回答简洁有条理，直接面向读者，不要无意义地重复粘贴原文。
    """

    static let welcomeMessage = """
    右页是你的读书助手：选中左页文字后点击「讲解」，模型回复完成后会用所选声音朗读；可在设置中下载在线女声。
    左页可粘贴名著节选，点击顶栏「\(ClassicLiteratureSupplement.capabilityLabel)」补全为完整篇章并自动保存。
    支持 \(LLMConnector.supportedSummary) 等大模型 API，以及 Cursor 本地对话；在顶栏右侧 AI 进化区可切换后端，顶栏胶囊显示当前模式；重启后会恢复上次的对话上下文。
    """
}

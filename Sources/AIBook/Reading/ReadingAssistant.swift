import Foundation

/// ai-book 读书助手 persona（命令 #1）；品牌文案来自 AIBookProduct。
enum ReadingAssistant { // 无实例命名空间
    /// 对外 tagline，和产品常量同一处。
    static var tagline: String { AIBookProduct.tagline } // 对外 tagline

    static let systemPrompt = """
    你是 \(AIBookProduct.displayName)（\(AIBookProduct.slug)）的读书助手。\(AIBookProduct.positioning)
    请用清晰、易懂的中文帮助读者理解文本，包括字面含义、上下文作用、重点与难点。
    回答简洁有条理，直接面向读者，不要无意义地重复粘贴原文。
    """ // 读书助手 LLM 系统提示词

    static let welcomeMessage = "" // 欢迎正文由 ReadingAssistant.welcomeMessage / L10n 注入
}

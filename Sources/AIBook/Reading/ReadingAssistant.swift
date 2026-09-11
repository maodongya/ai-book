import Foundation

/// Reading-assistant persona for ai-book (command #1); branding lives in AIBookProduct.
enum ReadingAssistant {
    static var tagline: String { AIBookProduct.tagline }

    static let systemPrompt = """
    你是 \(AIBookProduct.displayName)（\(AIBookProduct.slug)）的读书助手。\(AIBookProduct.positioning)
    请用清晰、易懂的中文帮助读者理解文本，包括字面含义、上下文作用、重点与难点。
    回答简洁有条理，直接面向读者，不要无意义地重复粘贴原文。
    """

    static let welcomeMessage = ""
}

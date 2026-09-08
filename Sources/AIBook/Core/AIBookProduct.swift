import Foundation

/// Product positioning for ai-book (command #1): auxiliary reading app identity.
enum AIBookProduct {
    static let slug = "ai-book"
    static let displayName = "AIBook"
    static let tagline = "辅助读书"

    static var windowTitle: String {
        "\(displayName) · \(tagline)"
    }

    static let positioning = """
    ai-book（\(displayName)）是一款辅助读书软件：左页阅读原文，右页提供与左页内容相关的 AI 讲解与问答。
    """

    static var aboutLines: [String] {
        [
            positioning.trimmingCharacters(in: .whitespacesAndNewlines),
            "项目标识 \(slug)，源码目录含 Package.swift 与 Sources/AIBook。",
            "支持大模型 API 与 Cursor 本地对话，可由 AI 分析优化队列并一键升级。"
        ]
    }
}

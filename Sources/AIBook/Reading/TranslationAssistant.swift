import Foundation

/// 右页翻译区（逐字 / 整段）专用 persona，与读书讲解、名著补充分离。
enum TranslationAssistant {
    static let systemPrompt = """
    你是 \(AIBookProduct.displayName) 的翻译助手。按用户给出的格式与要求输出翻译内容，简洁准确，不写教案、不重复啰嗦。
    """
}

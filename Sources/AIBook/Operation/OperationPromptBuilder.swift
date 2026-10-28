import Foundation

/// 操作模型的系统提示和用户消息。不放全文。
enum OperationPromptBuilder {
    /// 系统提示。要求只从目录点名，对不上就返回空列表。
    static let systemPrompt = """
    你是 AIBook 的操作解析器。用户说的是对软件的操作，不是要你写文章。
    只从提供的工具里选择。可以按顺序返回多步。对不上任何工具时不要调用工具，或返回 {"actions":[]}。
    不要改文件，不要解释，不要发明目录外的操作。
    讲解和翻译不接收语言参数。用户指定的语言不在快照的已勾选语言里时，不要返回讲解、翻译或切换语言。
    指定的语言已勾选时，只返回讲解或翻译，不要顺便切换语言。
    切换语言只用于查看已经生成的内容。
    """

    /// 用户消息：原话加快照 JSON。
    static func userMessage(utterance: String, snapshot: OperationContextSnapshot) -> String {
        """
        用户原话：
        \(utterance)

        界面快照：
        \(snapshot.jsonString())
        """
    }
}

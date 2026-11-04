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
    语音识别可能把「生成」听成「升腾」等同音词；用户明显在说全文讲解时，应调用 explainFullText。
    语音识别可能把「保存」听成「包存」「报存」。用户说原文保存、保存、存盘、存一下时调用 save。「保存为」但不是 AIBook 时调用 saveAs。
    按钮文字里的「原文」「翻译」「讲解」就是操作范围，原文二字在按钮开头。按听到的按钮名调用同名工具，例如原文新建、原文保存、保存讲解、逐字翻译、对齐翻译、原文朗读全文。
    语音识别可能把「AIBook」听成「AI boo」等截断；用户明显在保存 AIBook 时，应调用 saveAsAIBook。
    用户口述了保存文件名（如「保存为 AI Book1」）时，在 suggestedStem 里带上该名字（不含 .aibook）。
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

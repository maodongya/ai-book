import Foundation

/// 操作目录的工具表。模型只能点这些名字。
enum OperationCatalog {
    /// OpenAI tools 数组，和解析器认的名字一致。
    static func toolDefinitions() -> [[String: Any]] {
        names.map { tool(name: $0.name, description: $0.description, parameters: $0.parameters) }
    }

    /// 一个 function 工具。
    private static func tool(name: String, description: String, parameters: [String: Any]) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters,
            ],
        ]
    }

    /// 没有参数的对象。
    private static var emptyParameters: [String: Any] {
        ["type": "object", "properties": [String: Any](), "additionalProperties": false]
    }

    /// 一个必填字符串参数。
    private static func stringParameter(_ key: String, values: [String]) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                key: [
                    "type": "string",
                    "enum": values,
                ],
            ],
            "required": [key],
            "additionalProperties": false,
        ]
    }

    private static let languageValues = TranslationTargetLanguage.selectableTargets.map(\.rawValue)

    private struct ToolSpec {
        var name: String
        var description: String
        var parameters: [String: Any]
    }

    private static var names: [ToolSpec] {
        [
            ToolSpec(name: "explainSelection", description: "讲解左页选区", parameters: emptyParameters),
            ToolSpec(name: "explainFullText", description: "讲解左页全文", parameters: emptyParameters),
            ToolSpec(name: "translateWordByWord", description: "逐词翻译", parameters: emptyParameters),
            ToolSpec(name: "translateParagraph", description: "整段翻译", parameters: emptyParameters),
            ToolSpec(name: "readOriginalSelection", description: "原文朗读选区", parameters: emptyParameters),
            ToolSpec(name: "readOriginalFull", description: "原文朗读全文", parameters: emptyParameters),
            ToolSpec(name: "readTranslationSelection", description: "朗读译文选区", parameters: emptyParameters),
            ToolSpec(name: "readTranslationFull", description: "朗读译文全文", parameters: emptyParameters),
            ToolSpec(name: "readExplanationSelection", description: "朗读讲解选区", parameters: emptyParameters),
            ToolSpec(name: "readExplanationFull", description: "朗读讲解全文", parameters: emptyParameters),
            ToolSpec(name: "pauseSpeech", description: "暂停朗读", parameters: emptyParameters),
            ToolSpec(name: "resumeSpeech", description: "继续朗读", parameters: emptyParameters),
            ToolSpec(name: "stopSpeech", description: "停止朗读", parameters: emptyParameters),
            ToolSpec(name: "stopCurrentRun", description: "停止当前讲解或翻译", parameters: emptyParameters),
            ToolSpec(name: "toggleReadingMode", description: "在学习模式和阅读模式之间切换", parameters: emptyParameters),
            ToolSpec(name: "setPaneFocus", description: "双页、左全屏或右全屏", parameters: stringParameter("focus", values: ["both", "leading", "trailing"])),
            ToolSpec(name: "showAssistantPanel", description: "显示讲解或翻译子栏", parameters: stringParameter("panel", values: ["explanation", "translation"])),
            ToolSpec(name: "showRightPage", description: "切换读书助手或进化页，不开始进化", parameters: stringParameter("page", values: ["assistant", "evolution"])),
            ToolSpec(name: "showExplanationLanguage", description: "切换已生成的讲解语言", parameters: stringParameter("language", values: languageValues)),
            ToolSpec(name: "showTranslationLanguage", description: "切换已生成的翻译语言", parameters: stringParameter("language", values: languageValues)),
            ToolSpec(name: "openLibraryFile", description: "打开书库里唯一对上的文件", parameters: [
                "type": "object",
                "properties": ["query": ["type": "string"]],
                "required": ["query"],
                "additionalProperties": false,
            ]),
            ToolSpec(name: "openFilePanel", description: "原文打开", parameters: emptyParameters),
            ToolSpec(name: "openDirectoryPanel", description: "原文打开目录", parameters: emptyParameters),
            ToolSpec(name: "save", description: "原文保存", parameters: emptyParameters),
            ToolSpec(name: "saveAs", description: "另存为，由系统面板确认", parameters: emptyParameters),
            ToolSpec(name: "saveSelectionAs", description: "选区另存为", parameters: emptyParameters),
            ToolSpec(name: "saveAsAIBook", description: "另存为 aibook；可选 suggestedStem 作为默认文件名（不含扩展名）", parameters: [
                "type": "object",
                "properties": ["suggestedStem": ["type": "string"]],
                "additionalProperties": false,
            ]),
            ToolSpec(name: "selectAllLeft", description: "原文全选", parameters: emptyParameters),
            ToolSpec(name: "selectAllRight", description: "全选翻译", parameters: emptyParameters),
            ToolSpec(name: "supplementClassic", description: "原文补充", parameters: emptyParameters),
            ToolSpec(name: "newDocument", description: "原文新建", parameters: emptyParameters),
            ToolSpec(name: "newExplanation", description: "新建讲解", parameters: emptyParameters),
            ToolSpec(name: "openExplanation", description: "打开讲解", parameters: emptyParameters),
            ToolSpec(name: "saveExplanation", description: "保存讲解", parameters: emptyParameters),
            ToolSpec(name: "clearExplanation", description: "清空讲解", parameters: emptyParameters),
            ToolSpec(name: "selectAllExplanation", description: "全选讲解", parameters: emptyParameters),
            ToolSpec(name: "openTranslation", description: "打开翻译", parameters: emptyParameters),
            ToolSpec(name: "saveTranslation", description: "保存翻译", parameters: emptyParameters),
            ToolSpec(name: "clearTranslation", description: "清空翻译", parameters: emptyParameters),
            ToolSpec(name: "alignTranslation", description: "对齐翻译", parameters: emptyParameters),
            ToolSpec(name: "alignExplanation", description: "对齐讲解", parameters: emptyParameters),
            ToolSpec(name: "lockTranslation", description: "锁定翻译", parameters: emptyParameters),
            ToolSpec(name: "unlockTranslation", description: "解锁翻译", parameters: emptyParameters),
            ToolSpec(name: "lockExplanation", description: "锁定讲解", parameters: emptyParameters),
            ToolSpec(name: "unlockExplanation", description: "解锁讲解", parameters: emptyParameters),
            ToolSpec(name: "toggleExplanationTable", description: "讲解对照", parameters: emptyParameters),
            ToolSpec(name: "toggleTranslationTable", description: "翻译对照", parameters: emptyParameters),
            ToolSpec(name: "startEvolution", description: "开始进化，必须由软件再确认", parameters: emptyParameters),
            ToolSpec(name: "analyzeOptimizations", description: "分析优化，必须由软件再确认", parameters: emptyParameters),
        ]
    }
}

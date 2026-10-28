import Foundation

/// 把模型的 tool_calls 或 JSON 正文收成操作列表。目录外的名字丢掉。
enum OperationPlanParser {
    /// 有 tool_calls 就只用它们；否则解析正文。
    static func parse(toolCalls: [LLMToolCall], content: String = "") -> OperationPlan {
        if !toolCalls.isEmpty { // 模型已经点了工具，不再看正文
            let actions = toolCalls.compactMap(action(from:)) // 坏参数的丢掉
            return OperationPlan(actions: actions)
        }
        return parse(content: content) // 无工具时走 JSON
    }

    /// 正文里的 `{"actions":[...]}`，允许包在 markdown 代码块中。
    static func parse(content: String) -> OperationPlan {
        guard let data = jsonData(in: content), // 抽不出对象就是没对应操作
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawActions = object["actions"] as? [[String: Any]] else {
            return OperationPlan(actions: []) // 空计划，调用方显示没有对应操作
        }
        let actions = rawActions.compactMap { item -> OperationAction? in
            guard let name = item["name"] as? String else { return nil } // 没名字的项丢掉
            let arguments = item["arguments"] as? [String: Any] ?? [:] // 无参数当空对象
            return action(name: name, arguments: arguments)
        }
        return OperationPlan(actions: actions)
    }

    /// tool_call 的 arguments 是 JSON 字符串。
    private static func action(from call: LLMToolCall) -> OperationAction? {
        let arguments = (try? JSONSerialization.jsonObject(with: Data(call.arguments.utf8))) as? [String: Any] ?? [:] // 坏 JSON 当无参数
        return action(name: call.name, arguments: arguments)
    }

    /// 名字和参数都在目录里才留下。
    private static func action(name: String, arguments: [String: Any]) -> OperationAction? {
        switch name {
        case "explainSelection": return .explainSelection
        case "explainFullText": return .explainFullText
        case "translateWordByWord": return .translateWordByWord
        case "translateParagraph": return .translateParagraph
        case "readOriginalSelection": return .readOriginalSelection
        case "readOriginalFull": return .readOriginalFull
        case "readTranslationSelection": return .readTranslationSelection
        case "readTranslationFull": return .readTranslationFull
        case "readExplanationSelection": return .readExplanationSelection
        case "readExplanationFull": return .readExplanationFull
        case "pauseSpeech": return .pauseSpeech
        case "resumeSpeech": return .resumeSpeech
        case "stopSpeech": return .stopSpeech
        case "stopCurrentRun": return .stopCurrentRun
        case "toggleReadingMode": return .toggleReadingMode
        case "setPaneFocus":
            guard let focus = arguments["focus"] as? String, Self.paneFocus.contains(focus) else { return nil } // 只收三种焦点
            return .setPaneFocus(focus)
        case "showAssistantPanel":
            guard let panel = arguments["panel"] as? String, Self.panels.contains(panel) else { return nil }
            return .showAssistantPanel(panel)
        case "showRightPage":
            guard let page = arguments["page"] as? String, Self.pages.contains(page) else { return nil }
            return .showRightPage(page)
        case "showExplanationLanguage":
            guard let language = languageID(arguments) else { return nil }
            return .showExplanationLanguage(language)
        case "showTranslationLanguage":
            guard let language = languageID(arguments) else { return nil }
            return .showTranslationLanguage(language)
        case "openLibraryFile":
            guard let query = arguments["query"] as? String else { return nil }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines) // 空白查询没有意义
            guard !trimmed.isEmpty else { return nil }
            return .openLibraryFile(trimmed)
        case "openFilePanel": return .openFilePanel
        case "openDirectoryPanel": return .openDirectoryPanel
        case "save": return .save
        case "saveAs": return .saveAs
        case "saveSelectionAs": return .saveSelectionAs
        case "saveAsAIBook": return .saveAsAIBook
        case "selectAllLeft": return .selectAllLeft
        case "selectAllRight": return .selectAllRight
        case "supplementClassic": return .supplementClassic
        case "startEvolution": return .startEvolution
        case "analyzeOptimizations": return .analyzeOptimizations
        default:
            return nil // 目录外的名字不执行
        }
    }

    /// 只要八种具体语言，不要「跟随界面语言」。
    private static func languageID(_ arguments: [String: Any]) -> String? {
        guard let raw = arguments["language"] as? String,
              let language = TranslationTargetLanguage(rawValue: raw),
              language != .followAppLanguage else {
            return nil
        }
        return language.rawValue
    }

    /// 从正文里切出第一个 JSON 对象。代码块只是外壳。
    private static func jsonData(in content: String) -> Data? {
        var text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") { // Cursor 常包一层 fence
            if let newline = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: newline)...]) // 去掉 ```json 那一行
            }
            if let closing = text.range(of: "```", options: .backwards) {
                text = String(text[..<closing.lowerBound]) // 去掉收尾 fence
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil } // 没有对象
        return Data(text[start...end].utf8) // 只留 JSON
    }

    private static let paneFocus: Set<String> = ["both", "leading", "trailing"]
    private static let panels: Set<String> = ["explanation", "translation"]
    private static let pages: Set<String> = ["assistant", "evolution"]
}

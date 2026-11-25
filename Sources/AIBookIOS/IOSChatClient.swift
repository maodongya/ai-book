import Foundation

/// 拼 iOS 上要发给模型的说明。只要可读正文，不走 Mac 的 JSON 对照合同。
enum IOSReadingPrompt {
    /// 讲解。followUp 非空时接着上一份讲解追问。
    static func explain(source: String, followUp: String?) -> (system: String, user: String) {
        let system = "你是读书讲解。用读者界面语言能读的散文讲解，不要 JSON，不要重复粘贴全文。"
        var user = "请讲解下面的文字：\n\n\(source)"
        let extra = followUp?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !extra.isEmpty {
            user += "\n\n读者接着问：\(extra)" // 追问附在同一份原文后面
        }
        return (system, user)
    }

    /// 翻译。整段要连贯，逐字要按原文顺序拆开。
    static func translate(source: String, paragraph: Bool) -> (system: String, user: String) {
        let system = paragraph
            ? "你是译者。按段落给出通顺译文，不要 JSON，不要讲解。"
            : "你是译者。按原文顺序逐词对照翻译，不要 JSON，不要扩写。"
        let user = "请翻译下面的文字：\n\n\(source)"
        return (system, user)
    }

    /// 名著补全。标记和 Mac 的名著补充一致，只把标记里的正文写回原文。
    static func supplement(source: String, selection: Bool) -> (system: String, user: String) {
        let scope = selection ? "左页选中节选" : "左页全文" // 有选区只补选中的那段
        let system = """
        你是 AIBook 的名著补全专家。用户左页可能只有某部中国或外国经典名著的节选、残篇或缺段文字。
        请根据原文风格与上下文，识别作品与位置，补全缺失内容，输出连贯、可阅读的完整篇章。
        要求：
        1. 保持原著叙述风格与人物称谓，不现代口语化改写
        2. 若无法确定具体版本，按通行全本/教材本常见写法补全
        3. 仅输出补全后的正文，不要解释过程
        4. 正文必须放在标记块内（见用户说明）
        """
        let user = """
        【任务】名著补充：将下列\(scope)补全为完整、连贯的名著篇章。

        【\(scope)】
        \(source)

        请先识别「书名 / 作者 / 章节或段落」，再输出补全后的全文。
        补全正文请严格使用以下格式（标记外不要其他内容）：
        <<<名著补充>>>
        （第一行可写：【书名】… 【作者】… 【章节】…，随后为补全正文）
        <<<END>>>
        """
        return (system, user)
    }

    /// 只取 Mac 同一对标记之间的正文。没有标记就去掉标记残留。
    static func supplementBody(from reply: String) -> String {
        let startMark = "<<<名著补充>>>"
        let endMark = "<<<END>>>"
        if let start = reply.range(of: startMark),
           let end = reply.range(of: endMark, range: start.upperBound ..< reply.endIndex) {
            let content = reply[start.upperBound ..< end.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                return content // 标记内才是要写回原文的篇章
            }
        }
        return reply
            .replacingOccurrences(of: startMark, with: "")
            .replacingOccurrences(of: endMark, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 一次 OpenAI 兼容的聊天补全。不带工具，不走 Mac 的进化请求。
enum IOSChatClient {
    enum Failure: Error {
        case notConfigured
        case badURL
        case badResponse
        case http(String)
    }

    /// 发一轮 system + user，返回助手正文。
    @MainActor
    static func complete(
        system: String,
        user: String,
        settings: IOSModelSettings,
        maxTokens: Int = 8192
    ) async throws -> String {
        guard settings.isReady else { throw Failure.notConfigured } // 缺密钥时调用方应先去设置
        let root = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: root + "/chat/completions") else { throw Failure.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        let payload: [String: Any] = [
            "model": settings.model.trimmingCharacters(in: .whitespacesAndNewlines),
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "max_tokens": maxTokens, // 名著补充需要长回复，翻译也沿用同一上限
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.badResponse }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw Failure.http(body.isEmpty ? "HTTP \(http.statusCode)" : body) // 把服务端原文留给状态行
        }
        return try assistantText(from: data)
    }

    /// 从 choices[0].message.content 取出正文。
    static func assistantText(from data: Data) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else { throw Failure.badResponse }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.badResponse }
        return trimmed
    }
}

import Foundation

/// 把网络和配置错误收成可读文案。
enum IOSLLMErrorMessage {
    static func message(for error: Error) -> String {
        if let failure = error as? IOSChatClient.Failure {
            switch failure {
            case .notConfigured, .badURL:
                return BookL10n.string("help.configureBookLLM") // 未配模型或地址
            case .badResponse:
                return BookL10n.string("help.configureBookLLM") // 非 HTTP 或空响应
            case .http(let body):
                let lower = body.lowercased()
                if lower.contains("api key") || lower.contains("unauthorized") || lower.contains("401") {
                    return BookL10n.string("help.configureBookLLM") // 密钥类错误统一引导设置
                }
                return body.isEmpty ? BookL10n.string("help.configureBookLLM") : body // 其余透出服务端正文
            }
        }
        let lower = error.localizedDescription.lowercased()
        if lower.contains("api key") || lower.contains("could not connect") {
            return BookL10n.string("help.configureBookLLM") // URLSession 常见离线/鉴权文案
        }
        return error.localizedDescription // 未知错误兜底
    }
}
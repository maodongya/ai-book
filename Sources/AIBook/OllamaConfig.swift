import Foundation

struct OllamaModelInfo: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let sizeBytes: Int64?
    let family: String?
    let parameterSize: String?

    var displayTitle: String {
        var parts = [name]
        if let parameterSize, !parameterSize.isEmpty {
            parts.append(parameterSize)
        } else if let family, !family.isEmpty {
            parts.append(family)
        }
        return parts.joined(separator: " · ")
    }

    var sizeLabel: String? {
        guard let sizeBytes, sizeBytes > 0 else { return nil }
        let gb = Double(sizeBytes) / 1_073_741_824.0
        if gb >= 0.1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(sizeBytes) / 1_048_576.0
        return String(format: "%.0f MB", mb)
    }
}

/// 本机 Ollama 服务地址、环境变量与已安装模型发现。
enum OllamaConfig {
    static let defaultHost = "http://127.0.0.1:11434"
    static let defaultOpenAIBaseURL = "http://127.0.0.1:11434/v1"
    static let defaultModel = "llama3.2"

    static let pullHint = "未找到已拉取的模型？在终端执行：ollama pull llama3.2"

    static func normalizedOpenAIBaseURL(_ baseURL: String) -> String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultOpenAIBaseURL }

        if trimmed.hasSuffix("/chat/completions") {
            trimmed = String(trimmed.dropLast("/chat/completions".count))
        }
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !trimmed.hasSuffix("/v1") {
            trimmed += "/v1"
        }
        return trimmed
    }

    /// 用于调用 Ollama 原生 API（/api/tags）的根地址，不含 /v1。
    static func resolvedHost(baseURL: String) -> String {
        if let env = ProcessInfo.processInfo.environment["OLLAMA_HOST"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return normalizeHostURL(env)
        }
        if let fileHost = loadValueFromLocalFiles(key: "OLLAMA_HOST") {
            return normalizeHostURL(fileHost)
        }

        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return defaultHost
        }
        return hostFromOpenAIBaseURL(trimmed)
    }

    static func hostFromOpenAIBaseURL(_ baseURL: String) -> String {
        var host = normalizedOpenAIBaseURL(baseURL)
        if host.hasSuffix("/v1") {
            host = String(host.dropLast(3))
        }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func normalizeHostURL(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return defaultHost }
        if !trimmed.contains("://") {
            trimmed = "http://\(trimmed)"
        }
        if trimmed.hasSuffix("/v1") {
            trimmed = String(trimmed.dropLast(3))
        }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func resolveAPIKey(stored: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        if let env = ProcessInfo.processInfo.environment["OLLAMA_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        return loadValueFromLocalFiles(key: "OLLAMA_API_KEY") ?? ""
    }

    static func repairProfile(_ profile: LLMProfile) -> LLMProfile {
        var repaired = profile
        let base = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        repaired.baseURL = base.isEmpty ? defaultOpenAIBaseURL : normalizedOpenAIBaseURL(base)

        if repaired.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            repaired.model = defaultModel
        }

        repaired.apiKey = resolveAPIKey(stored: profile.apiKey)
        return repaired
    }

    /// 按优先级发现本机已安装模型：HTTP /api/tags → OpenAI /v1/models → `ollama list` → 本地 manifests。
    static func discoverModels(baseURL: String, apiKey: String) async -> [OllamaModelInfo] {
        let host = resolvedHost(baseURL: baseURL)
        let openAIBase = normalizedOpenAIBaseURL(baseURL)
        let key = resolveAPIKey(stored: apiKey)

        if let models = try? await fetchModelsFromTagsAPI(host: host, apiKey: key), !models.isEmpty {
            return models
        }
        if let models = try? await fetchModelsFromOpenAIAPI(baseURL: openAIBase, apiKey: key), !models.isEmpty {
            return models
        }
        if let models = try? listModelsViaCLI(), !models.isEmpty {
            return models
        }
        if let models = scanLocalManifests(), !models.isEmpty {
            return models
        }
        return []
    }

    static func fetchModelsFromTagsAPI(host: String, apiKey: String) async throws -> [OllamaModelInfo] {
        guard let url = URL(string: "\(host)/api/tags") else {
            throw OllamaDiscoveryError.invalidHost
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        applyAuth(to: &request, apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]]
        else {
            throw OllamaDiscoveryError.invalidResponse
        }

        let parsed = models.compactMap { parseTagsEntry($0) }
        return sortAndDedupe(parsed)
    }

    static func fetchModelsFromOpenAIAPI(baseURL: String, apiKey: String) async throws -> [OllamaModelInfo] {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/models") else {
            throw OllamaDiscoveryError.invalidHost
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        applyAuth(to: &request, apiKey: apiKey)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]]
        else {
            throw OllamaDiscoveryError.invalidResponse
        }

        let parsed = models.compactMap { entry -> OllamaModelInfo? in
            guard let id = entry["id"] as? String ?? entry["name"] as? String else { return nil }
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return OllamaModelInfo(id: trimmed, name: trimmed, sizeBytes: nil, family: nil, parameterSize: nil)
        }
        return sortAndDedupe(parsed)
    }

    static func listModelsViaCLI() throws -> [OllamaModelInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ollama", "list"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw OllamaDiscoveryError.cliFailed
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            throw OllamaDiscoveryError.invalidResponse
        }

        var results: [OllamaModelInfo] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.uppercased().hasPrefix("NAME") { continue }
            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let name = parts.first, !name.isEmpty else { continue }
            results.append(OllamaModelInfo(id: name, name: name, sizeBytes: nil, family: nil, parameterSize: nil))
        }
        return sortAndDedupe(results)
    }

    static func scanLocalManifests() -> [OllamaModelInfo]? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let libraryRoot = home
            .appendingPathComponent(".ollama/models/manifests/registry.ollama.ai/library", isDirectory: true)
        guard FileManager.default.fileExists(atPath: libraryRoot.path) else { return nil }

        guard let families = try? FileManager.default.contentsOfDirectory(
            at: libraryRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var names: [String] = []
        for familyURL in families {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: familyURL.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let family = familyURL.lastPathComponent
            guard let tags = try? FileManager.default.contentsOfDirectory(
                at: familyURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for tagURL in tags {
                var tagIsDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: tagURL.path, isDirectory: &tagIsDir), tagIsDir.boolValue else {
                    continue
                }
                let tag = tagURL.lastPathComponent
                let modelName = tag == "latest" ? family : "\(family):\(tag)"
                names.append(modelName)
            }
        }

        let parsed = names.map {
            OllamaModelInfo(id: $0, name: $0, sizeBytes: nil, family: nil, parameterSize: nil)
        }
        let sorted = sortAndDedupe(parsed)
        return sorted.isEmpty ? nil : sorted
    }

    /// 将设置中的模型名解析为 Ollama 已安装名称（如 `llama3.2` → `llama3.2:latest`）。
    static func resolveModelForRequest(_ model: String, baseURL: String, apiKey: String) async -> String {
        let requested = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else { return defaultModel }

        let installed = await discoverModels(baseURL: baseURL, apiKey: apiKey)
        return matchInstalledName(requested, installed: installed.map(\.name)) ?? requested
    }

    static func matchInstalledName(_ requested: String, installed: [String]) -> String? {
        let trimmed = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if installed.contains(trimmed) { return trimmed }

        let base = trimmed.split(separator: ":", maxSplits: 1).first.map(String.init) ?? trimmed
        if let tagged = installed.first(where: { name in
            name == base || name.hasPrefix("\(base):") || name.hasSuffix("/\(base)")
        }) {
            return tagged
        }

        if !trimmed.contains(":"),
           let latest = installed.first(where: { $0 == "\(base):latest" }) {
            return latest
        }

        return nil
    }

    /// 查询 /api/show 是否声明支持 tools；失败时返回 false（走无工具对话，避免 400）。
    static func modelSupportsTools(baseURL: String, model: String, apiKey: String) async -> Bool {
        let host = resolvedHost(baseURL: baseURL)
        let resolvedModel = await resolveModelForRequest(model, baseURL: baseURL, apiKey: apiKey)
        guard let url = URL(string: "\(host)/api/show") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request, apiKey: apiKey)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": resolvedModel])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTP(response: response, data: data)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            if let capabilities = json["capabilities"] as? [String] {
                return capabilities.contains("tools")
            }
            if let details = json["details"] as? [String: Any],
               let families = details["families"] as? [String] {
                return families.contains("tools")
            }
            return false
        } catch {
            return false
        }
    }

    static func isToolsUnsupportedAPIError(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("tool")
            && (
                lower.contains("does not support")
                    || lower.contains("not support")
                    || lower.contains("unsupported")
                    || lower.contains("不支持")
            )
    }

    static func parseAPIErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let errorText = json["error"] as? String, !errorText.isEmpty {
            return errorText
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func enrichError(_ message: String, host: String) -> String {
        let lower = message.lowercased()
        var hints: [String] = []

        if lower.contains("could not connect") || lower.contains("connection refused")
            || lower.contains("network") || lower.contains("timed out") || lower.contains("无法连接")
            || lower.contains("failed to connect") || lower.contains("cannot connect")
            || lower.contains("connect to server") || lower.contains("dial tcp") {
            hints.append("请确认 Ollama 已启动：在终端执行 `ollama serve`（默认 \(defaultHost)）。")
            hints.append("若使用自定义地址，可设置环境变量 OLLAMA_HOST 或在设置中修改 API 地址。")
        }

        if lower.contains("unauthorized") || lower.contains("401") {
            hints.append("服务端启用了鉴权，请在设置中填写 OLLAMA_API_KEY 或可选 API Key。")
        }

        if lower.contains("model") && (lower.contains("not found") || lower.contains("does not exist")) {
            hints.append(pullHint)
            hints.append("请在设置中点击「刷新模型」并选择本机已 pull 的模型名称。")
        }

        if isToolsUnsupportedAPIError(message) {
            hints.append("当前模型不支持 OpenAI tool_calls。进化请换用 llama3.1、qwen2.5 等支持工具的模型；读书讲解会自动改为普通对话模式。")
        }

        if lower.contains("invalid response") || lower.contains("无法解析") {
            hints.append("若使用「思考型」模型，请确认已在设置中选中正确的本地模型，或换用 llama3.2、qwen2.5 等对话模型。")
        }

        if !hints.isEmpty {
            return ([message, "当前探测地址：\(host)"] + hints).joined(separator: "\n")
        }
        return message
    }

    // MARK: - Private

    private enum OllamaDiscoveryError: Error {
        case invalidHost
        case invalidResponse
        case cliFailed
        case http(Int, String)
    }

    private static func parseTagsEntry(_ entry: [String: Any]) -> OllamaModelInfo? {
        let name = (entry["name"] as? String ?? entry["model"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let size = entry["size"] as? Int64 ?? (entry["size"] as? NSNumber)?.int64Value
        let details = entry["details"] as? [String: Any]
        let family = details?["family"] as? String
        let parameterSize = details?["parameter_size"] as? String

        return OllamaModelInfo(
            id: name,
            name: name,
            sizeBytes: size,
            family: family,
            parameterSize: parameterSize
        )
    }

    private static func sortAndDedupe(_ models: [OllamaModelInfo]) -> [OllamaModelInfo] {
        var seen: Set<String> = []
        return models
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { seen.insert($0.id).inserted }
    }

    private static func applyAuth(to request: inout URLRequest, apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }

    private static func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OllamaDiscoveryError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OllamaDiscoveryError.http(http.statusCode, body)
        }
    }

    private static func localEnvCandidates() -> [URL] {
        var candidates: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".aibook/ollama.env"))

        for root in CursorAPIKeyStore.projectRootCandidates() {
            candidates.append(root.appendingPathComponent("ollama.local.env"))
            candidates.append(root.appendingPathComponent("ai-book/ollama.local.env"))
        }
        return candidates
    }

    private static func loadValueFromLocalFiles(key: String) -> String? {
        for url in localEnvCandidates() {
            if let value = parseEnvFile(at: url, key: key) {
                return value
            }
        }
        return nil
    }

    private static func parseEnvFile(at url: URL, key: String) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in content.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }
            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !value.isEmpty { return value }
        }
        return nil
    }
}

@MainActor
final class OllamaModelCatalog: ObservableObject {
    static let shared = OllamaModelCatalog()

    @Published private(set) var models: [OllamaModelInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var statusMessage: String?

    private var lastBaseURL: String?
    private var lastAPIKey: String?

    func refresh(baseURL: String, apiKey: String, force: Bool = false) async {
        let normalizedBase = OllamaConfig.normalizedOpenAIBaseURL(baseURL)
        let key = OllamaConfig.resolveAPIKey(stored: apiKey)

        if !force,
           normalizedBase == lastBaseURL,
           key == lastAPIKey,
           !models.isEmpty {
            return
        }

        lastBaseURL = normalizedBase
        lastAPIKey = key
        isLoading = true
        statusMessage = "正在扫描本机 Ollama 模型…"
        defer { isLoading = false }

        let discovered = await OllamaConfig.discoverModels(baseURL: normalizedBase, apiKey: key)
        models = discovered

        if discovered.isEmpty {
            let host = OllamaConfig.resolvedHost(baseURL: normalizedBase)
            statusMessage = "未发现已安装模型。请确认 `ollama serve` 已运行（\(host)），并执行 `ollama pull` 拉取模型。"
        } else {
            statusMessage = "已发现 \(discovered.count) 个本地模型"
        }
    }

    func modelNamesIncluding(_ current: String) -> [String] {
        var names = models.map(\.name)
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !names.contains(trimmed) {
            names.insert(trimmed, at: 0)
        }
        return names
    }
}

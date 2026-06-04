import Foundation

enum ExplanationSource: String, CaseIterable, Identifiable, Codable {
    case llm = "大模型 API"
    case cursor = "Cursor 本地"

    var id: String { rawValue }
}

struct ChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    let thinking: String?
    let toolSteps: [ExecutionStep]?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        thinking: String? = nil,
        toolSteps: [ExecutionStep]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.toolSteps = toolSteps
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, thinking, toolSteps, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        thinking = try container.decodeIfPresent(String.self, forKey: .thinking)
        toolSteps = try container.decodeIfPresent([ExecutionStep].self, forKey: .toolSteps)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    var hasExecutionTrace: Bool {
        let thinkingText = thinking?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !thinkingText.isEmpty || !(toolSteps?.isEmpty ?? true)
    }

    /// Plain-text export of thinking + tool timeline for clipboard.
    var executionTraceText: String {
        var sections: [String] = []
        if let thinking, !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("【思考过程】\n\(thinking)")
        }
        if let toolSteps, !toolSteps.isEmpty {
            let lines = toolSteps.map { step -> String in
                var parts = [EvolutionToolLabels.localizedToolName(step.name)]
                if let detail = step.detail, !detail.isEmpty {
                    parts.append(detail)
                }
                parts.append(step.status == .completed ? "✓" : (step.status == .failed ? "✗" : "…"))
                if let result = step.resultSummary, !result.isEmpty {
                    parts.append("→ \(result)")
                }
                if let error = step.errorMessage, !error.isEmpty {
                    parts.append("! \(error)")
                }
                return parts.joined(separator: " ")
            }
            sections.append("【工具步骤】\n\(lines.joined(separator: "\n"))")
        }
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("【回复】\n\(content)")
        }
        return sections.joined(separator: "\n\n")
    }
}

struct CursorConfiguration {
    let apiKey: String
    let model: String
    let bridgeDirectory: URL
    let workingDirectory: String
}

enum CursorServiceError: LocalizedError {
    case bridgeNotFound
    case nodeNotFound
    case invalidResponse
    case needsAuthentication
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .bridgeNotFound:
            return "未找到 cursor-bridge 目录。请在 ai-book 下运行 npm install，或在设置中指定路径。"
        case .nodeNotFound:
            return "未找到 Node.js。请先安装 Node.js 18+。"
        case .invalidResponse:
            return "Cursor 桥接脚本返回了无法解析的内容。"
        case .needsAuthentication:
            return "Cursor 需要 API Key（AuthenticationError）。"
        case .processFailed(let message):
            return message
        }
    }

    static func classifyFailure(_ message: String) -> CursorServiceError {
        let lowered = message.lowercased()
        if lowered.contains("authentication")
            || lowered.contains("unauthenticated")
            || lowered.contains("connecterror")
            || lowered.contains("needs_auth") {
            return .needsAuthentication
        }
        return .processFailed(message)
    }
}

struct CursorService {
    private final class RunHandle: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?

        func setProcess(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func terminate() {
            lock.lock()
            process?.terminate()
            process = nil
            lock.unlock()
        }
    }

    private let runHandle = RunHandle()

    func cancel() {
        runHandle.terminate()
    }

    func chat(
        message: String,
        history: [ChatMessage],
        configuration: CursorConfiguration,
        systemInstruction: String? = nil,
        autoAuthorize: Bool = false,
        onEvent: (@Sendable (CursorStreamEvent) -> Void)? = nil
    ) async throws -> (text: String, thinking: String?) {
        let scriptURL = configuration.bridgeDirectory.appendingPathComponent("explain.mjs")
        guard Self.isBridgeReady(at: configuration.bridgeDirectory) else {
            throw CursorServiceError.bridgeNotFound
        }

        guard let node = NodeRuntime.resolveExecutable() else {
            throw CursorServiceError.nodeNotFound
        }

        if configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CursorServiceError.needsAuthentication
        }

        var payload: [String: Any] = [
            "message": message,
            "apiKey": configuration.apiKey,
            "model": configuration.model,
            "cwd": configuration.workingDirectory,
            "autoAuthorize": autoAuthorize,
            "history": history.map { ["role": $0.role.rawValue, "content": $0.content] },
        ]
        if let systemInstruction, !systemInstruction.isEmpty {
            payload["systemInstruction"] = systemInstruction
        }

        let inputData = try JSONSerialization.data(withJSONObject: payload)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: node.path)
                        process.arguments = node.prefixArgs + [scriptURL.path]
                        process.currentDirectoryURL = configuration.bridgeDirectory
                        self.runHandle.setProcess(process)

                        var environment = ProcessInfo.processInfo.environment
                        if !configuration.apiKey.isEmpty {
                            environment["CURSOR_API_KEY"] = configuration.apiKey
                        }
                        process.environment = environment

                        let stdin = Pipe()
                        let stdout = Pipe()
                        let stderr = Pipe()
                        process.standardInput = stdin
                        process.standardOutput = stdout
                        process.standardError = stderr

                        var stdoutBuffer = Data()
                        var finalText = ""
                        var finalThinking: String?
                        var receivedNeedsAuth = false
                        var didResume = false

                        func resumeOnce(with result: Result<(text: String, thinking: String?), Error>) {
                            guard !didResume else { return }
                            didResume = true
                            self.runHandle.terminate()
                            continuation.resume(with: result)
                        }

                        func processStreamLines() {
                            guard let chunk = String(data: stdoutBuffer, encoding: .utf8) else { return }
                            let parts = chunk.components(separatedBy: "\n")
                            stdoutBuffer = Data()

                            if !chunk.hasSuffix("\n"), let trailing = parts.last {
                                stdoutBuffer = Data(trailing.utf8)
                            }

                            let completeLines = chunk.hasSuffix("\n") ? parts : Array(parts.dropLast())
                            let events = completeLines
                                .compactMap { line -> [String: Any]? in
                                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return nil }
                                    return try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                                }
                            for json in events {
                                guard let eventName = json["event"] as? String else { continue }

                                switch eventName {
                                case "thinking":
                                    if let delta = json["delta"] as? String {
                                        onEvent?(.thinkingDelta(delta))
                                    }
                                case "text":
                                    if let delta = json["delta"] as? String {
                                        onEvent?(.textDelta(delta))
                                    }
                                case "tool":
                                    let name = json["name"] as? String ?? "tool"
                                    let status = json["status"] as? String ?? "running"
                                    let callId = json["callId"] as? String
                                    let detail = json["detail"] as? String
                                    let result = json["result"] as? String
                                    let error = json["error"] as? String
                                    onEvent?(.toolUpdate(
                                        name: name,
                                        status: status,
                                        callId: callId,
                                        detail: detail,
                                        result: result,
                                        error: error
                                    ))
                                case "done":
                                    finalText = json["text"] as? String ?? ""
                                    finalThinking = json["thinking"] as? String
                                    onEvent?(.done(text: finalText, thinking: finalThinking))
                                case "needs_auth":
                                    receivedNeedsAuth = true
                                    resumeOnce(with: .failure(CursorServiceError.needsAuthentication))
                                    return
                                case "error":
                                    let message = json["error"] as? String ?? "Cursor 调用失败"
                                    onEvent?(.error(message))
                                    resumeOnce(with: .failure(CursorServiceError.classifyFailure(message)))
                                    return
                                default:
                                    break
                                }
                            }
                        }

                        stdout.fileHandleForReading.readabilityHandler = { handle in
                            let data = handle.availableData
                            if data.isEmpty { return }
                            stdoutBuffer.append(data)
                            processStreamLines()
                        }

                        try process.run()
                        stdin.fileHandleForWriting.write(inputData)
                        stdin.fileHandleForWriting.closeFile()
                        process.waitUntilExit()

                        stdout.fileHandleForReading.readabilityHandler = nil
                        if !stdoutBuffer.isEmpty {
                            processStreamLines()
                        }

                        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                        let errorText = String(data: errorData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        guard process.terminationStatus == 0 else {
                            let fallback = errorText ?? "Cursor 进程异常退出（\(process.terminationStatus)）"
                            resumeOnce(with: .failure(CursorServiceError.classifyFailure(fallback)))
                            return
                        }

                        if receivedNeedsAuth {
                            resumeOnce(with: .failure(CursorServiceError.needsAuthentication))
                            return
                        }

                        if finalText.isEmpty && finalThinking == nil {
                            resumeOnce(with: .failure(CursorServiceError.processFailed(errorText ?? "Cursor 返回了空内容。")))
                            return
                        }

                        resumeOnce(with: .success((text: finalText, thinking: finalThinking)))
                    } catch {
                        self.runHandle.terminate()
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            runHandle.terminate()
        }
    }

}

extension CursorService {
    static func bundledBridgeDirectory() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let bridge = resources.appendingPathComponent("cursor-bridge", isDirectory: true)
        if FileManager.default.fileExists(atPath: bridge.appendingPathComponent("package.json").path) {
            return bridge
        }
        return nil
    }

    /// Resolves the ai-book Swift source tree (Package.swift + Sources/AIBook), not the installed .app Resources bundle.
    static func defaultProjectDirectory() -> URL? {
        for candidate in sourceProjectCandidates() {
            if isSourceProject(at: candidate) {
                return candidate
            }
        }

        if let bridge = bundledBridgeDirectory() {
            return bridge.deletingLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    static func isSourceProject(at url: URL) -> Bool {
        let fileManager = FileManager.default
        let package = url.appendingPathComponent("Package.swift")
        let sources = url.appendingPathComponent("Sources/AIBook", isDirectory: true)
        return fileManager.fileExists(atPath: package.path)
            && fileManager.fileExists(atPath: sources.path)
    }

    static func isBridgeReady(at url: URL) -> Bool {
        let fileManager = FileManager.default
        let script = url.appendingPathComponent("explain.mjs")
        let package = url.appendingPathComponent("package.json")
        let sdk = url.appendingPathComponent("node_modules/@cursor/sdk", isDirectory: true)
        return fileManager.fileExists(atPath: script.path)
            && fileManager.fileExists(atPath: package.path)
            && fileManager.fileExists(atPath: sdk.path)
    }

    static func bridgeStatusMessage(at url: URL?) -> String {
        guard let url else {
            return "未找到 cursor-bridge 目录。"
        }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path)
            || !fileManager.fileExists(atPath: url.appendingPathComponent("explain.mjs").path) {
            return "cursor-bridge 不完整，请确认包含 package.json 与 explain.mjs。"
        }
        if !fileManager.fileExists(atPath: url.appendingPathComponent("node_modules/@cursor/sdk", isDirectory: true).path) {
            return "cursor-bridge 依赖未安装，请在 ai-book/cursor-bridge 目录执行 npm install。"
        }
        return "cursor-bridge 已就绪。"
    }

    private static func sourceProjectCandidates() -> [URL] {
        var candidates: [URL] = []

        let known = URL(
            fileURLWithPath: "/Users/maodongya/Documents/java/game/snake/ai-book",
            isDirectory: true
        )
        candidates.append(known)

        for root in CursorAPIKeyStore.projectRootCandidates() {
            candidates.append(root)
            candidates.append(root.appendingPathComponent("ai-book", isDirectory: true))
        }

        if let bridge = bundledBridgeDirectory() {
            var directory = bridge.deletingLastPathComponent()
            for _ in 0 ..< 8 {
                candidates.append(directory)
                directory.deleteLastPathComponent()
            }
        }

        var seen: Set<String> = []
        return candidates.filter { url in
            guard seen.insert(url.path).inserted else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    static func defaultBridgeDirectory() -> URL? {
        if let bundled = bundledBridgeDirectory() {
            return bundled
        }

        guard let project = defaultProjectDirectory() else { return nil }
        let bridge = project.appendingPathComponent("cursor-bridge", isDirectory: true)
        if FileManager.default.fileExists(atPath: bridge.appendingPathComponent("package.json").path) {
            return bridge
        }
        return nil
    }
}

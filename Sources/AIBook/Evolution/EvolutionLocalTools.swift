import Foundation

/// Sandboxed local tools for LLM evolution agent (mirrors Cursor Agent capabilities within ai-book source tree).
enum EvolutionLocalTools {
    static let maxReadCharacters = 48_000
    static let maxResultCharacters = 12_000

    enum ToolError: LocalizedError {
        case invalidArguments(String)
        case pathOutsideProject(String)
        case fileNotFound(String)
        case editMiss(String)
        case shellBlocked(String)
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidArguments(let message): return message
            case .pathOutsideProject(let path): return "路径超出 ai-book 源码目录：\(path)"
            case .fileNotFound(let path): return "文件不存在：\(path)"
            case .editMiss(let path): return "未找到要替换的内容：\(path)"
            case .shellBlocked(let command): return "命令被安全策略拒绝：\(command)"
            case .executionFailed(let message): return message
            }
        }
    }

    static func execute(name: String, argumentsJSON: String, projectRoot: URL) -> Result<String, ToolError> {
        guard let data = argumentsJSON.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidArguments("工具参数不是合法 JSON。"))
        }

        switch name.lowercased() {
        case "read", "read_file":
            return read(arguments: args, projectRoot: projectRoot)
        case "grep":
            return grep(arguments: args, projectRoot: projectRoot)
        case "glob", "glob_file_search":
            return glob(arguments: args, projectRoot: projectRoot)
        case "edit", "strreplace", "search_replace":
            return edit(arguments: args, projectRoot: projectRoot)
        case "write", "write_file":
            return write(arguments: args, projectRoot: projectRoot)
        case "shell", "run_terminal_cmd":
            return shell(arguments: args, projectRoot: projectRoot)
        default:
            return .failure(.invalidArguments("未知工具：\(name)"))
        }
    }

    static var openAIToolDefinitions: [[String: Any]] {
        [
            toolDefinition(
                name: "read",
                description: "读取 ai-book 项目内的文件内容。path 可为相对项目根的路径。",
                properties: ["path": stringProperty("相对或绝对文件路径")],
                required: ["path"]
            ),
            toolDefinition(
                name: "grep",
                description: "在项目内搜索文本，返回匹配行（类似 ripgrep）。",
                properties: [
                    "pattern": stringProperty("正则或字面搜索词"),
                    "path": stringProperty("可选，限定目录或文件，默认整个项目"),
                    "glob": stringProperty("可选，文件名 glob，如 *.swift"),
                ],
                required: ["pattern"]
            ),
            toolDefinition(
                name: "glob",
                description: "按 glob 模式查找文件路径。",
                properties: [
                    "pattern": stringProperty("glob 模式，如 Sources/**/*.swift"),
                ],
                required: ["pattern"]
            ),
            toolDefinition(
                name: "edit",
                description: "在文件中精确替换一段文本（old_string 须唯一匹配）。",
                properties: [
                    "path": stringProperty("文件路径"),
                    "old_string": stringProperty("要被替换的原文"),
                    "new_string": stringProperty("替换后的内容"),
                ],
                required: ["path", "old_string", "new_string"]
            ),
            toolDefinition(
                name: "write",
                description: "写入或覆盖项目内文件（必要时创建父目录）。",
                properties: [
                    "path": stringProperty("文件路径"),
                    "content": stringProperty("完整文件内容"),
                ],
                required: ["path", "content"]
            ),
            toolDefinition(
                name: "shell",
                description: "在项目根目录运行 shell 命令（如 swift build、git status）。",
                properties: [
                    "command": stringProperty("要执行的命令"),
                ],
                required: ["command"]
            ),
        ]
    }

    // MARK: - Tool implementations

    private static func read(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let pathArg = stringValue(arguments["path"]), !pathArg.isEmpty else {
            return .failure(.invalidArguments("read 需要 path 参数。"))
        }

        let url: URL
        switch resolveURL(pathArg, projectRoot: projectRoot) {
        case .success(let resolved): url = resolved
        case .failure(let error): return .failure(error)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(relativePath(url, projectRoot: projectRoot)))
        }

        do {
            var content = try String(contentsOf: url, encoding: .utf8)
            var note = ""
            if content.count > maxReadCharacters {
                content = String(content.prefix(maxReadCharacters))
                note = "\n\n[已截断，仅返回前 \(maxReadCharacters) 字符]"
            }
            return .success(truncateResult("【\(relativePath(url, projectRoot: projectRoot))】\n\(content)\(note)"))
        } catch {
            return .failure(.executionFailed("读取失败：\(error.localizedDescription)"))
        }
    }

    private static func grep(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let pattern = stringValue(arguments["pattern"]), !pattern.isEmpty else {
            return .failure(.invalidArguments("grep 需要 pattern 参数。"))
        }

        var searchRoot = projectRoot
        if let pathArg = stringValue(arguments["path"]), !pathArg.isEmpty {
            switch resolveURL(pathArg, projectRoot: projectRoot) {
            case .success(let resolved): searchRoot = resolved
            case .failure(let error): return .failure(error)
            }
        }

        let fileGlob = stringValue(arguments["glob"])
        var matches: [String] = []
        let limit = 80

        enumerateFiles(at: searchRoot, projectRoot: projectRoot, glob: fileGlob) { url in
            guard matches.count < limit else { return false }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return true }
            let lines = content.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                if line.range(of: pattern, options: [.caseInsensitive]) != nil
                    || line.contains(pattern) {
                    let rel = relativePath(url, projectRoot: projectRoot)
                    matches.append("\(rel):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                    if matches.count >= limit { return false }
                }
            }
            return true
        }

        if matches.isEmpty {
            return .success("未找到匹配「\(pattern)」的内容。")
        }
        let suffix = matches.count >= limit ? "\n\n[结果已截断，最多 \(limit) 条]" : ""
        return .success(truncateResult(matches.joined(separator: "\n") + suffix))
    }

    private static func glob(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let pattern = stringValue(arguments["pattern"]), !pattern.isEmpty else {
            return .failure(.invalidArguments("glob 需要 pattern 参数。"))
        }

        let normalized = pattern.replacingOccurrences(of: "**/", with: "")
        var results: [String] = []
        let limit = 120

        enumerateFiles(at: projectRoot, projectRoot: projectRoot, glob: normalized) { url in
            results.append(relativePath(url, projectRoot: projectRoot))
            return results.count < limit
        }

        if results.isEmpty {
            return .success("未找到匹配「\(pattern)」的文件。")
        }
        let suffix = results.count >= limit ? "\n\n[结果已截断，最多 \(limit) 条]" : ""
        return .success(truncateResult(results.joined(separator: "\n") + suffix))
    }

    private static func edit(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let pathArg = stringValue(arguments["path"]),
              let oldString = stringValue(arguments["old_string"]),
              let newString = stringValue(arguments["new_string"]) else {
            return .failure(.invalidArguments("edit 需要 path、old_string、new_string。"))
        }

        let url: URL
        switch resolveURL(pathArg, projectRoot: projectRoot) {
        case .success(let resolved): url = resolved
        case .failure(let error): return .failure(error)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(relativePath(url, projectRoot: projectRoot)))
        }

        do {
            var content = try String(contentsOf: url, encoding: .utf8)
            guard let range = content.range(of: oldString) else {
                return .failure(.editMiss(relativePath(url, projectRoot: projectRoot)))
            }
            content.replaceSubrange(range, with: newString)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return .success("已编辑 \(relativePath(url, projectRoot: projectRoot))（替换 \(oldString.count) → \(newString.count) 字符）。")
        } catch let error as ToolError {
            return .failure(error)
        } catch {
            return .failure(.executionFailed("编辑失败：\(error.localizedDescription)"))
        }
    }

    private static func write(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let pathArg = stringValue(arguments["path"]),
              let content = stringValue(arguments["content"]) else {
            return .failure(.invalidArguments("write 需要 path、content。"))
        }

        let url: URL
        switch resolveURL(pathArg, projectRoot: projectRoot) {
        case .success(let resolved): url = resolved
        case .failure(let error): return .failure(error)
        }

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: url, atomically: true, encoding: .utf8)
            return .success("已写入 \(relativePath(url, projectRoot: projectRoot))（\(content.count) 字符）。")
        } catch {
            return .failure(.executionFailed("写入失败：\(error.localizedDescription)"))
        }
    }

    private static func shell(arguments: [String: Any], projectRoot: URL) -> Result<String, ToolError> {
        guard let command = stringValue(arguments["command"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !command.isEmpty else {
            return .failure(.invalidArguments("shell 需要 command 参数。"))
        }

        if isShellCommandBlocked(command) {
            return .failure(.shellBlocked(command))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = projectRoot

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure(.executionFailed("无法启动命令：\(error.localizedDescription)"))
        }

        process.waitUntilExit()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outText = String(data: outData, encoding: .utf8) ?? ""
        let errText = String(data: errData, encoding: .utf8) ?? ""

        var combined = ""
        if !outText.isEmpty { combined += outText }
        if !errText.isEmpty {
            if !combined.isEmpty { combined += "\n" }
            combined += errText
        }
        if combined.isEmpty {
            combined = "命令已结束，退出码 \(process.terminationStatus)。"
        } else if process.terminationStatus != 0 {
            combined += "\n\n[退出码 \(process.terminationStatus)]"
        }

        return .success(truncateResult(combined))
    }

    // MARK: - Helpers

    private static func toolDefinition(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required,
                ],
            ] as [String: Any],
        ]
    }

    private static func stringProperty(_ description: String) -> [String: Any] {
        ["type": "string", "description": description]
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func resolveURL(_ path: String, projectRoot: URL) -> Result<URL, ToolError> {
        let expanded = (path as NSString).expandingTildeInPath
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            url = projectRoot.appendingPathComponent(expanded)
        }

        let standardizedRoot = projectRoot.standardizedFileURL.path
        let standardizedTarget = url.standardizedFileURL.path
        guard standardizedTarget.hasPrefix(standardizedRoot + "/") || standardizedTarget == standardizedRoot else {
            return .failure(.pathOutsideProject(path))
        }
        return .success(url.standardizedFileURL)
    }

    private static func relativePath(_ url: URL, projectRoot: URL) -> String {
        let root = projectRoot.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        if path.hasPrefix(root) {
            return String(path.dropFirst(root.count))
        }
        return path
    }

    private static func truncateResult(_ text: String) -> String {
        guard text.count > maxResultCharacters else { return text }
        return String(text.prefix(maxResultCharacters)) + "\n\n[输出已截断]"
    }

    private static func isShellCommandBlocked(_ command: String) -> Bool {
        let lowered = command.lowercased()
        let blocked = [
            "rm -rf /",
            "rm -rf ~",
            "mkfs",
            "dd if=",
            ":(){ :|:& };:",
            "sudo rm",
            "> /dev/sd",
            "chmod -r /",
        ]
        return blocked.contains { lowered.contains($0) }
    }

    private static func enumerateFiles(
        at root: URL,
        projectRoot: URL,
        glob: String?,
        body: (URL) -> Bool
    ) {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let skipPrefixes = [".build/", "node_modules/", ".git/"]

        for case let url as URL in enumerator {
            let rel = relativePath(url, projectRoot: projectRoot)
            if skipPrefixes.contains(where: { rel.contains($0) }) {
                enumerator.skipDescendants()
                continue
            }

            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            if let glob, !glob.isEmpty {
                if !matchesGlob(rel, pattern: glob) && !matchesGlob(url.lastPathComponent, pattern: glob) {
                    continue
                }
            }

            if !body(url) { break }
        }
    }

    private static func matchesGlob(_ text: String, pattern: String) -> Bool {
        if pattern.contains("*") {
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
                .replacingOccurrences(of: "\\*", with: ".*")
            return text.range(of: "^\(escaped)$", options: .regularExpression) != nil
                || text.contains(pattern.replacingOccurrences(of: "*", with: ""))
        }
        return text.contains(pattern)
    }
}

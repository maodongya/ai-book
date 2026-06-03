import Foundation

enum CursorAPIKeyStore {
    private static let defaultsKey = "aiBook.cursorAPIKey"

    static func resolveStoredKey() -> String {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }

        if let env = ProcessInfo.processInfo.environment["CURSOR_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        return loadFromLocalFiles() ?? ""
    }

    static func save(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
    }

    static func loadFromLocalFiles() -> String? {
        for url in localEnvFileCandidates() {
            if let value = parseEnvFile(at: url, key: "CURSOR_API_KEY") {
                return value
            }
        }
        return nil
    }

    static func localEnvFileCandidates() -> [URL] {
        var candidates: [URL] = []

        for root in projectRootCandidates() {
            candidates.append(root.appendingPathComponent("cursor.local.env"))
            candidates.append(root.appendingPathComponent("ai-book/cursor.local.env"))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".aibook/cursor.env"))

        return candidates
    }

    static func projectRootCandidates() -> [URL] {
        var roots: [URL] = []
        let fileManager = FileManager.default

        if let resources = Bundle.main.resourceURL {
            roots.append(resources)
            roots.append(resources.deletingLastPathComponent())
        }

        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        roots.append(cwd)
        roots.append(cwd.appendingPathComponent("ai-book", isDirectory: true))

        if let executable = Bundle.main.executableURL {
            var directory = executable.deletingLastPathComponent()
            for _ in 0 ..< 6 {
                roots.append(directory)
                roots.append(directory.appendingPathComponent("ai-book", isDirectory: true))
                directory.deleteLastPathComponent()
            }
        }

        var unique: [String: URL] = [:]
        for root in roots where fileManager.fileExists(atPath: root.path) {
            unique[root.path] = root
        }
        return Array(unique.values)
    }

    private static func parseEnvFile(at url: URL, key: String) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for line in content.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else {
                continue
            }

            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            if !value.isEmpty {
                return value
            }
        }

        return nil
    }
}

extension AppSettings {
    /// cursor-bridge 目录与 explain.mjs 可用。
    var isCursorBridgeReady: Bool {
        guard let bridge = cursorConfiguration?.bridgeDirectory else { return false }
        return CursorService.isBridgeReady(at: bridge)
    }

    var cursorBridgeStatusMessage: String {
        CursorService.bridgeStatusMessage(at: cursorConfiguration?.bridgeDirectory)
    }

    /// 已配置 Cursor API Key（本地 SDK 调用必需）。
    var isCursorConfigured: Bool {
        !effectiveCursorAPIKey.isEmpty
    }

    /// 可同时使用 Cursor 本地桥接（bridge + Key）。
    var isCursorRunnable: Bool {
        isCursorBridgeReady && isCursorConfigured
    }

    var effectiveCursorAPIKey: String {
        let trimmed = cursorAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return CursorAPIKeyStore.resolveStoredKey()
    }

    func saveCursorAPIKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        cursorAPIKey = trimmed
        CursorAPIKeyStore.save(trimmed)
    }

    func refreshCursorAPIKeyFromSources() {
        let resolved = CursorAPIKeyStore.resolveStoredKey()
        if cursorAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !resolved.isEmpty {
            cursorAPIKey = resolved
        }
    }
}

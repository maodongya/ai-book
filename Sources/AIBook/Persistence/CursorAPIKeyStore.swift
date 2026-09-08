import Foundation

enum CursorAPIKeyStore {
    private static let defaultsKey = "aiBook.cursorAPIKey"
    private static let appSupportFileName = "cursor-api-key"
    private static let bundleIdentifier = "com.aibook.reader"

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var appSupportKeyFileURL: URL {
        appSupportDirectory.appendingPathComponent(appSupportFileName)
    }

    static func resolveStoredKey() -> String {
        if let appSupport = loadFromAppSupport(), !appSupport.isEmpty {
            return appSupport
        }

        if let defaults = loadFromUserDefaults(), !defaults.isEmpty {
            save(defaults)
            return defaults
        }

        if let legacy = loadFromLegacyUserDefaults(), !legacy.isEmpty {
            save(legacy)
            return legacy
        }

        return resolveExternalKey() ?? ""
    }

    /// 仅从环境变量与本地 env 文件读取，不读已持久化存储。
    static func resolveExternalKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["CURSOR_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        return loadFromLocalFiles()
    }

    static func save(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
        if trimmed.isEmpty {
            try? FileManager.default.removeItem(at: appSupportKeyFileURL)
            return
        }
        do {
            try trimmed.write(to: appSupportKeyFileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: appSupportKeyFileURL.path
            )
        } catch {
            // UserDefaults 仍可用；文件写入失败不阻断保存。
        }
    }

    static func loadFromAppSupport() -> String? {
        guard let content = try? String(contentsOf: appSupportKeyFileURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

    private static func loadFromUserDefaults() -> String? {
        UserDefaults.standard.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `swift run` 与旧版 setup 脚本曾写入错误域名的 UserDefaults。
    private static func loadFromLegacyUserDefaults() -> String? {
        for domain in ["AIBook", bundleIdentifier] {
            if let value = UserDefaults(suiteName: domain)?.string(forKey: defaultsKey)
                ?? legacyDefaultsValue(domain: domain) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func legacyDefaultsValue(domain: String) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent("Library/Preferences/\(domain).plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = plist[defaultsKey] as? String else {
            return nil
        }
        return value
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

    /// 从 Application Support / UserDefaults / 环境变量 / cursor.local.env 同步到内存与持久化存储。
    func reloadCursorAPIKey() {
        refreshCursorAPIKeyFromSources()
        let resolved = CursorAPIKeyStore.resolveStoredKey()
        guard !resolved.isEmpty else { return }
        let current = cursorAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if current != resolved {
            cursorAPIKey = resolved
            CursorAPIKeyStore.save(resolved)
        }
    }

    func refreshCursorAPIKeyFromSources() {
        guard let external = CursorAPIKeyStore.resolveExternalKey(),
              !external.isEmpty else {
            return
        }

        let current = cursorAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if current != external {
            saveCursorAPIKey(external)
        }
    }
}

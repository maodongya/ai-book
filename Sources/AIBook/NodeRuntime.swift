import Foundation

enum NodeRuntime {
    struct Executable: Equatable {
        let path: String
        let prefixArgs: [String]
    }

    static func resolveExecutable() -> Executable? {
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return Executable(path: candidate, prefixArgs: [])
        }

        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/env") else {
            return nil
        }
        return Executable(path: "/usr/bin/env", prefixArgs: ["node"])
    }

    static func jsonEventLines(from data: Data) -> [[String: Any]] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return nil }
                return try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
            }
    }

    static func lastJSONEvent(from data: Data) -> [String: Any]? {
        jsonEventLines(from: data).last
    }
}

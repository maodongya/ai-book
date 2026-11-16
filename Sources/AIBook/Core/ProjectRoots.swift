import Foundation

/// 开发机上找仓库根，用来读说明书。不负责 Cursor 桥。
enum ProjectRoots {
    static func candidates() -> [URL] {
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

    /// 含 Package.swift 的目录。
    static func sourceDirectory() -> URL? {
        let fileManager = FileManager.default
        for root in candidates() {
            if fileManager.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
                return root
            }
            let nested = root.appendingPathComponent("ai-book", isDirectory: true)
            if fileManager.fileExists(atPath: nested.appendingPathComponent("Package.swift").path) {
                return nested
            }
        }
        return nil
    }
}

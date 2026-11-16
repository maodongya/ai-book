import Foundation

/// 沙盒里拒绝访问时抛出。调用方改走系统面板，不按裸路径再试。
enum FolderAccessError: Error {
    case notAuthorized
}

/// 判断一个路径是不是落在用户授权过的文件夹里。不读盘。
enum FolderAccessPolicy {
    /// 根自己和它下面的条目算授权内。`/a` 不算盖住 `/ab`。
    static func contains(candidate: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path // 去掉 .. 和重复斜杠
        let candidatePath = candidate.standardizedFileURL.path // 和根用同一套路径
        if candidatePath == rootPath { return true } // 授权根自己
        return candidatePath.hasPrefix(rootPath + "/") // 必须多一段分隔，避免前缀误伤
    }

    /// 展开记录里，根以外的路径丢掉，避免下次启动顺着旧路径往外扫。
    static func pathsInside(root: URL, paths: Set<String>) -> Set<String> {
        let rootURL = root.standardizedFileURL // 比较前先标准化
        return Set(paths.filter { path in // 只留根内
            contains(candidate: URL(fileURLWithPath: path, isDirectory: true), root: rootURL)
        })
    }
}

/// 把面板给出的 URL 收成安全作用域书签，并在解析时重新打开访问。
enum SecurityScopedBookmark {
    /// 面板 URL 还有效时做成书签。做不成就返回 nil，调用方不得改记裸路径。
    static func make(for url: URL) -> Data? {
        try? url.bookmarkData( // 安全作用域，下次启动靠它回来
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// 解析书签。失败表示用户撤了权限或书签坏了，不当成还能扫的目录。
    static func resolve(_ data: Data) -> (url: URL, isStale: Bool)? {
        var stale = false // 系统会标过期书签
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil } // 解析失败就没有访问权
        return (url.standardizedFileURL, stale) // 路径和会话里存的根对齐
    }
}

/// 这次进程里已经 start 过的文件夹和文件。停的时候按次数配对。
final class UserFolderGrants {
    /// 一次成功的授权。bookmark 为空表示这次进程能用，但下次启动不能靠它恢复。
    struct CapturedFolder {
        let url: URL // 标准化后的面板 URL
        let bookmarkData: Data? // 能落盘的书签；沙盒外可能为空
    }

    private struct Entry {
        let url: URL // 这次授权的根或文件
        let bookmarkData: Data? // 对应书签
        let started: Bool // 只有 true 才需要 stop
    }

    private var entries: [UUID: Entry] = [:] // 目录会话 id 或当前文档 id

    /// 沙盒容器环境变量只在真正进了沙盒时才有。
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// 面板刚给出的 URL。沙盒里 start 失败就拒绝，避免接着按路径去扫。
    func capture(_ url: URL, id: UUID) -> CapturedFolder? {
        let standardized = url.standardizedFileURL // 和目录树用同一路径
        let started = standardized.startAccessingSecurityScopedResource() // 面板 URL 要先打开访问
        if !started && Self.isSandboxed { return nil } // 沙盒里没拿到权限就不收
        return adopt(standardized, id: id, alreadyStarted: started, bookmark: nil) // 顺手做成书签
    }

    /// 用上次存的书签重新打开访问。解析失败或沙盒里 start 失败则丢掉这个根。
    func begin(_ data: Data, id: UUID) -> CapturedFolder? {
        guard let resolved = SecurityScopedBookmark.resolve(data) else { return nil } // 书签无效
        let started = resolved.url.startAccessingSecurityScopedResource() // 解析后仍要 start
        if !started && Self.isSandboxed { return nil } // 不能靠裸路径顶上
        var bookmark = data // 没过期就沿用旧书签
        if resolved.isStale, let refreshed = SecurityScopedBookmark.make(for: resolved.url) {
            bookmark = refreshed // 过期就换一张新的
        }
        return adopt(resolved.url, id: id, alreadyStarted: started, bookmark: bookmark)
    }

    /// 记下已经 start 过的 URL。同一个 id 先停掉旧的，避免次数对不上。
    func adopt(_ url: URL, id: UUID, alreadyStarted: Bool, bookmark: Data?) -> CapturedFolder? {
        if !alreadyStarted && Self.isSandboxed { return nil } // 沙盒里没有访问权
        stop(id) // 换目标前先释放旧的
        let standardized = url.standardizedFileURL
        let data = bookmark ?? SecurityScopedBookmark.make(for: standardized) // 调用方没带书签就现做
        entries[id] = Entry(url: standardized, bookmarkData: data, started: alreadyStarted)
        return CapturedFolder(url: standardized, bookmarkData: data)
    }

    /// 当前文档或某个根对应的书签，用来下次启动再打开。
    func bookmarkData(for id: UUID) -> Data? {
        entries[id]?.bookmarkData
    }

    /// 这个 URL 是不是某个已授权根自己，或在它里面。
    func covers(_ url: URL) -> Bool {
        let candidate = url.standardizedFileURL
        return entries.values.contains { FolderAccessPolicy.contains(candidate: candidate, root: $0.url) }
    }

    /// 读文本。已授权的根里面直接读；否则只接受这次面板给的作用域 URL。
    func readText(at url: URL) throws -> String {
        try withScope(url) {
            try String(contentsOf: url, encoding: .utf8)
        }
    }

    /// 读二进制。`.aibook` 用。
    func readData(at url: URL) throws -> Data {
        try withScope(url) {
            try Data(contentsOf: url)
        }
    }

    /// 写文本。没授权的路径在沙盒里直接拒绝。
    func writeText(_ text: String, to url: URL) throws {
        try withScope(url) {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// 写二进制。`.aibook` 用。
    func writeData(_ data: Data, to url: URL) throws {
        try withScope(url) {
            try data.write(to: url, options: .atomic)
        }
    }

    /// 释放某个授权。目录根卸掉或另存取消时调用。
    func stop(_ id: UUID) {
        guard let entry = entries.removeValue(forKey: id) else { return } // 没记过就不用停
        if entry.started {
            entry.url.stopAccessingSecurityScopedResource() // 和 start 配对
        }
    }

    deinit {
        for id in Array(entries.keys) { // 拷一份，stop 会改字典
            stop(id)
        }
    }

    /// 根内的文件不再额外 start。面板刚给的 URL 自己 start，用完停掉。
    private func withScope<T>(_ url: URL, _ body: () throws -> T) throws -> T {
        if covers(url) {
            return try body() // 父目录的授权已经盖住它
        }
        let started = url.startAccessingSecurityScopedResource() // 面板 URL
        if !started && Self.isSandboxed {
            throw FolderAccessError.notAuthorized // 沙盒里不允许改走裸路径
        }
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        return try body()
    }
}

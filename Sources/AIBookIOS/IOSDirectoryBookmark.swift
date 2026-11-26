import Foundation

/// 记住用户上次用系统选择器打开的文件夹，下次进目录优先落在这里。
enum IOSDirectoryBookmark {
    private static let key = "aiBook.ios.lastDirectoryBookmark" // UserDefaults 存安全书签

    static func save(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return } // 书签打失败就静默
        UserDefaults.standard.set(data, forKey: key) // 持久化供下次 resolve
    }

    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil } // 从未选过目录
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil } // 书签失效时静默忽略
        if stale {
            save(url) // 系统标记过期时重写书签
        }
        return url
    }
}
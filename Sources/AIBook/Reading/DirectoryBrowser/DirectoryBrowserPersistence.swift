import Foundation

/// 一次打开的根目录。id 稳定，用来记住展开节点。
struct DirectoryBrowserRootSession: Identifiable, Equatable {
    let id: UUID // 会话稳定 id，展开状态按它存
    let rootURL: URL // 用户授权过的根，standardized 后比较
    var tree: DirectoryTreeNode? // 扫完才有；失败保持 nil
    var isLoading: Bool // 扫的时候转圈，避免空树当没文件
    var expandedPaths: Set<String> // 展开节点的绝对路径
    var loadError: String? // 权限/不存在时给目录页看

    /// 侧栏只显示路径最后一级。
    var displayName: String { rootURL.lastPathComponent } // 侧栏只显示最后一级名

    /// 刚授权的根：先转圈，根路径自己算展开。
    static func new(url: URL) -> DirectoryBrowserRootSession {
        DirectoryBrowserRootSession(
            id: UUID(),
            rootURL: url.standardizedFileURL, // 去 .. 和多余斜杠，和书签路径对齐
            tree: nil,
            isLoading: true,
            expandedPaths: [url.standardizedFileURL.path], // 根默认展开，否则一打开是空的
            loadError: nil
        )
    }
}

/// 根目录书签和展开状态落盘。
enum DirectoryBrowserPersistence {
    private static let rootsKey = "aiBook.directoryBrowser.roots" // 只在这里写死，别处禁止再写这个键

    /// 安全书签 + 展示名。书签失效要重新授权。
    struct StoredRoot: Codable, Hashable {
        let id: UUID // 与内存 session 对齐，换 URL 也不丢展开
        let urlPath: String // 绝对路径；加载时路径不存在就丢掉
        var expandedPaths: [String] // Set 不能直接 Codable，存成数组
    }

    /// 坏 JSON 当空。磁盘上没了的根丢掉，不弹授权框。
    static func load() -> [StoredRoot] {
        guard let data = UserDefaults.standard.data(forKey: rootsKey),
              let roots = try? JSONDecoder().decode([StoredRoot].self, from: data) else {
            return []
        }
        return roots.filter { FileManager.default.fileExists(atPath: $0.urlPath) }
    }

    /// 只存还活着的 session。编码失败静默，避免关窗崩。
    static func save(_ sessions: [DirectoryBrowserRootSession]) {
        let stored = sessions.map {
            StoredRoot(
                id: $0.id,
                urlPath: $0.rootURL.path,
                expandedPaths: Array($0.expandedPaths)
            )
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: rootsKey)
    }
}

/// 把树压成 List 行，只含已展开的孩子。
enum DirectoryTreeFlatRows {
    /// depth 给缩进。未展开的目录只占一行。
    static func visibleRows(
        from node: DirectoryTreeNode,
        expandedPaths: Set<String>
    ) -> [(node: DirectoryTreeNode, depth: Int)] {
        var rows: [(DirectoryTreeNode, Int)] = []

        /// 先写自己再写孩子；文件或未展开目录到此为止。
        func visit(_ node: DirectoryTreeNode, depth: Int) {
            rows.append((node, depth))
            guard node.isDirectory, expandedPaths.contains(node.id) else { return }
            for child in node.children ?? [] { // nil children 当没有，不扫盘
                visit(child, depth: depth + 1)
            }
        }

        visit(node, depth: 0)
        return rows
    }
}

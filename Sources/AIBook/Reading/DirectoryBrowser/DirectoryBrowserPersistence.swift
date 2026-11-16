import Foundation

/// 一次打开的根目录。id 稳定，用来记住展开节点。
struct DirectoryBrowserRootSession: Identifiable, Equatable {
    let id: UUID // 会话稳定 id，展开状态按它存
    let rootURL: URL // 用户授权过的根，standardized 后比较
    var tree: DirectoryTreeNode? // 扫完才有；失败保持 nil
    var isLoading: Bool // 扫的时候转圈，避免空树当没文件
    var expandedPaths: Set<String> // 展开节点的绝对路径
    var loadError: String? // 权限/不存在时给目录页看
    var bookmarkData: Data? // 安全作用域书签；没有就不能在下次启动时扫这个根

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
            loadError: nil,
            bookmarkData: nil // 调用方拿到面板书签后再填
        )
    }
}

/// 根目录书签和展开状态落盘。
enum DirectoryBrowserPersistence {
    private static let rootsKey = "aiBook.directoryBrowser.roots" // 只在这里写死，别处禁止再写这个键

    /// 安全书签 + 展示名。没有书签的记录下次不能扫。
    struct StoredRoot: Codable, Hashable {
        let id: UUID // 与内存 session 对齐，换 URL 也不丢展开
        let urlPath: String // 只给人看；恢复访问以书签为准
        var bookmarkData: Data? // 安全作用域书签；旧数据没有这一项
        var expandedPaths: [String] // Set 不能直接 Codable，存成数组
    }

    /// 解析成功、并且展开路径都落在这个根里的授权。
    struct RestoredRoot: Equatable {
        let id: UUID // 原会话 id
        let url: URL // 书签解析出来的根，不采用 urlPath
        let bookmarkData: Data // 仍可继续落盘的书签
        let expandedPaths: [String] // 已经滤掉根以外的路径
    }

    /// 坏 JSON 当空。不按路径探磁盘，没书签的记录留给 restorable 丢掉。
    static func load() -> [StoredRoot] {
        guard let data = UserDefaults.standard.data(forKey: rootsKey),
              let roots = try? JSONDecoder().decode([StoredRoot].self, from: data) else {
            return []
        }
        return roots
    }

    /// 只恢复能解析出 URL 的书签。urlPath 即使还在磁盘上也不算授权。
    static func restorable(_ stored: [StoredRoot], resolve: (Data) -> URL?) -> [RestoredRoot] {
        stored.compactMap { item in
            guard let data = item.bookmarkData, let resolved = resolve(data) else { return nil } // 没书签或解析失败
            let url = resolved.standardizedFileURL // 和目录树路径对齐
            let expanded = FolderAccessPolicy.pathsInside(root: url, paths: Set(item.expandedPaths)) // 根外的展开记录丢掉
            return RestoredRoot(
                id: item.id,
                url: url,
                bookmarkData: data,
                expandedPaths: Array(expanded)
            )
        }
    }

    /// 只存还活着的 session。编码失败静默，避免关窗崩。
    static func save(_ sessions: [DirectoryBrowserRootSession]) {
        let stored = sessions.map {
            StoredRoot(
                id: $0.id,
                urlPath: $0.rootURL.path,
                bookmarkData: $0.bookmarkData,
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

import Foundation

struct DirectoryBrowserRootSession: Identifiable, Equatable {
    let id: UUID
    let rootURL: URL
    var tree: DirectoryTreeNode?
    var isLoading: Bool
    var expandedPaths: Set<String>
    var loadError: String?

    var displayName: String { rootURL.lastPathComponent }

    static func new(url: URL) -> DirectoryBrowserRootSession {
        DirectoryBrowserRootSession(
            id: UUID(),
            rootURL: url.standardizedFileURL,
            tree: nil,
            isLoading: true,
            expandedPaths: [url.standardizedFileURL.path],
            loadError: nil
        )
    }
}

enum DirectoryBrowserPersistence {
    private static let rootsKey = "aiBook.directoryBrowser.roots"

    struct StoredRoot: Codable, Hashable {
        let id: UUID
        let urlPath: String
        var expandedPaths: [String]
    }

    static func load() -> [StoredRoot] {
        guard let data = UserDefaults.standard.data(forKey: rootsKey),
              let roots = try? JSONDecoder().decode([StoredRoot].self, from: data) else {
            return []
        }
        return roots.filter { FileManager.default.fileExists(atPath: $0.urlPath) }
    }

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

enum DirectoryTreeFlatRows {
    static func visibleRows(
        from node: DirectoryTreeNode,
        expandedPaths: Set<String>
    ) -> [(node: DirectoryTreeNode, depth: Int)] {
        var rows: [(DirectoryTreeNode, Int)] = []

        func visit(_ node: DirectoryTreeNode, depth: Int) {
            rows.append((node, depth))
            guard node.isDirectory, expandedPaths.contains(node.id) else { return }
            for child in node.children ?? [] {
                visit(child, depth: depth + 1)
            }
        }

        visit(node, depth: 0)
        return rows
    }
}

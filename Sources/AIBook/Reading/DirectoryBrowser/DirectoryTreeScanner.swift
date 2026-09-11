import Foundation

/// A node in a directory tree for the file browser.
struct DirectoryTreeNode: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [DirectoryTreeNode]?

    var id: String { url.path }
}

/// Where to load a file chosen from the directory browser.
enum DirectoryFileOpenTarget: String, CaseIterable, Identifiable {
    case original
    case translation
    case explanation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "原文"
        case .translation: return "翻译"
        case .explanation: return "讲解"
        }
    }

    var icon: String {
        switch self {
        case .original: return "text.book.closed"
        case .translation: return "character.book.closed"
        case .explanation: return "sparkles.text.clipboard"
        }
    }

    var help: String {
        switch self {
        case .original: return "在左页原文区打开"
        case .translation: return "在右页翻译区打开"
        case .explanation: return "在右页讲解区打开"
        }
    }
}

enum DirectoryTreeScanner {
    private static let textExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "rtf",
    ]

    private static let skippedNames: Set<String> = [
        ".DS_Store", ".git", ".svn", "Thumbs.db",
    ]

    static func scan(root: URL) -> DirectoryTreeNode? {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return scanEntry(at: root, isRoot: true)
    }

    static func isTextFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return false }
        if skippedNames.contains(name) { return false }

        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return true }
        return textExtensions.contains(ext)
    }

    private static func scanEntry(at url: URL, isRoot: Bool) -> DirectoryTreeNode? {
        let name = url.lastPathComponent
        if !isRoot {
            if name.hasPrefix(".") || skippedNames.contains(name) { return nil }
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            let children = listChildren(in: url)
            if !isRoot, children.isEmpty { return nil }
            return DirectoryTreeNode(
                url: url,
                name: isRoot ? name : name,
                isDirectory: true,
                children: children
            )
        }

        guard isTextFile(url) else { return nil }
        return DirectoryTreeNode(url: url, name: name, isDirectory: false, children: nil)
    }

    private static func listChildren(in directory: URL) -> [DirectoryTreeNode] {
        let manager = FileManager.default
        guard let urls = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .compactMap { scanEntry(at: $0, isRoot: false) }
            .sorted(by: sortNodes)
    }

    private static func sortNodes(_ lhs: DirectoryTreeNode, _ rhs: DirectoryTreeNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

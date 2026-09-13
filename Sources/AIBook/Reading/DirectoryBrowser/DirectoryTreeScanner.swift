import Foundation

/// 目录树节点。id 用绝对路径，同一文件只出现一次。
struct DirectoryTreeNode: Identifiable, Hashable {
    let url: URL // standardized 后的绝对路径
    let name: String // lastPathComponent，侧栏直接显示
    let isDirectory: Bool
    var children: [DirectoryTreeNode]? // 目录才有；文件必须是 nil。空目录是 [] 不是 nil

    /// 和 expandedPaths 用同一套路径键。
    var id: String { url.path } // 和 expandedPaths 用同一套路径
}

/// 从目录点开文件时落到哪一栏。
enum DirectoryFileOpenTarget: String, CaseIterable, Identifiable {
    case original // 左页正文
    case translation // 右页翻译
    case explanation // 右页讲解

    /// 和 expandedPaths 用同一套路径键。
    var id: String { rawValue }

    /// 打开目标的短标题。
    var displayName: String {
        switch self {
        case .original: return "原文"
        case .translation: return "翻译"
        case .explanation: return "讲解"
        }
    }

    /// 打开目标的 SF Symbol。
    var icon: String {
        switch self {
        case .original: return "text.book.closed"
        case .translation: return "character.book.closed"
        case .explanation: return "sparkles.text.clipboard"
        }
    }

    /// 打开目标的悬停说明。
    var help: String {
        switch self {
        case .original: return "在左页原文区打开"
        case .translation: return "在右页翻译区打开"
        case .explanation: return "在右页讲解区打开"
        }
    }
}

/// 扫一层孩子。跳过隐藏项。非根空目录丢掉。
enum DirectoryTreeScanner {
    private static let textExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "rtf", // 只收这些；无扩展名当文本
    ]

    private static let skippedNames: Set<String> = [
        ".DS_Store", ".git", ".svn", "Thumbs.db",
    ]

    /// 根必须是存在的目录。文件路径回 nil。
    static func scan(root: URL) -> DirectoryTreeNode? {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return scanEntry(at: root, isRoot: true)
    }

    /// 无扩展名当文本（很多古文是无后缀）。隐藏文件和跳过名单除外。
    static func isTextFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return false }
        if skippedNames.contains(name) { return false }

        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return true }
        return textExtensions.contains(ext)
    }

    /// isRoot 为真时不因名字点开头丢掉，否则用户打不开隐藏工程根。
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
            if !isRoot, children.isEmpty { return nil } // 空子目录不占行，根空目录仍显示
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

    /// 列目录失败当空，不把整棵树判死。
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

    /// 目录在前，再按本地化名字。
    private static func sortNodes(_ lhs: DirectoryTreeNode, _ rhs: DirectoryTreeNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

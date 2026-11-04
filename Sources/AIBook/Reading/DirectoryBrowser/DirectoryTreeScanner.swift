import Foundation

/// 目录树节点。id 用绝对路径，同一文件只出现一次。子目录 children 为 nil 表示这一层还没从硬盘读。
struct DirectoryTreeNode: Identifiable, Hashable {
    let url: URL // standardized 后的绝对路径
    let name: String // lastPathComponent，侧栏直接显示
    let isDirectory: Bool
    var children: [DirectoryTreeNode]? // 目录才有；文件必须是 nil。空目录是 [] 不是 nil

    /// 和 expandedPaths 用同一套路径键。
    var id: String { url.path } // 和 expandedPaths 用同一套路径

    /// 这个目录已经在树上，但还没列过孩子。
    func directoryNeedsLoad(_ path: String) -> Bool {
        guard let node = find(path) else { return false }
        return node.isDirectory && node.children == nil
    }

    /// 把某一层换成刚从硬盘读到的列表。其它层不动。
    func replacingChildren(at path: String, with newChildren: [DirectoryTreeNode]) -> DirectoryTreeNode {
        if id == path {
            var copy = self
            copy.children = newChildren
            return copy
        }
        guard var kids = children else { return self }
        for index in kids.indices {
            kids[index] = kids[index].replacingChildren(at: path, with: newChildren)
        }
        var copy = self
        copy.children = kids
        return copy
    }

    /// 按绝对路径找节点。还没展开到的子目录找不到。
    private func find(_ path: String) -> DirectoryTreeNode? {
        if id == path { return self }
        for child in children ?? [] {
            if let found = child.find(path) { return found }
        }
        return nil
    }
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
        case .original: return BookL10n.string("page.source")
        case .translation: return BookL10n.string("panel.translation")
        case .explanation: return BookL10n.string("panel.explanation")
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
        case .original: return BookL10n.string("directory.open.original")
        case .translation: return BookL10n.string("directory.open.translation")
        case .explanation: return BookL10n.string("directory.open.explanation")
        }
    }
}

/// 只列展开的那一层。跳过隐藏项。子目录等下次展开再读硬盘。
enum DirectoryTreeScanner {
    private static let textExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "rtf", "aibook", // 只收这些；无扩展名当文本
    ]

    private static let skippedNames: Set<String> = [
        ".DS_Store", ".git", ".svn", "Thumbs.db",
    ]

    /// 根必须是存在的目录。只列这一层，子目录要等展开再读硬盘。
    static func scan(root: URL) -> DirectoryTreeNode? {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let children = children(in: root) else {
            return nil
        }
        return DirectoryTreeNode(url: root, name: root.lastPathComponent, isDirectory: true, children: children)
    }

    /// 根这一层立刻列出，已经展开的子目录也按当前硬盘再列一层。
    static func scan(root: URL, expandedPaths: Set<String>) -> DirectoryTreeNode? {
        guard var tree = scan(root: root) else { return nil }
        var safety = 0 // 每一轮补当前已经出现在树上的一层
        while safety < 64 {
            safety += 1
            let pending = expandedPaths
                .filter { tree.directoryNeedsLoad($0) }
                .sorted { $0.count < $1.count } // 先补浅的，深的才找得到
            guard !pending.isEmpty else { break }
            for path in pending {
                let listed = children(in: URL(fileURLWithPath: path, isDirectory: true)) ?? [] // 读失败当这一层是空的
                tree = tree.replacingChildren(at: path, with: listed)
            }
        }
        return tree
    }

    /// 只列这一层。子目录的 children 保持 nil，展开时再读。
    static func children(in directory: URL) -> [DirectoryTreeNode]? {
        let manager = FileManager.default
        guard let urls = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return urls
            .compactMap { makeChild(at: $0) }
            .sorted(by: sortNodes)
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

    /// 子目录先不往下读。空文件夹也留着，里面以后可能有新文件。
    private static func makeChild(at url: URL) -> DirectoryTreeNode? {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || skippedNames.contains(name) { return nil }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            return DirectoryTreeNode(url: url, name: name, isDirectory: true, children: nil)
        }
        guard isTextFile(url) else { return nil }
        return DirectoryTreeNode(url: url, name: name, isDirectory: false, children: nil)
    }

    /// 目录在前，再按本地化名字。
    private static func sortNodes(_ lhs: DirectoryTreeNode, _ rhs: DirectoryTreeNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

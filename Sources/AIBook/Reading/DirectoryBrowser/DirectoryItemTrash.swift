import Foundation

/// 目录树里删除文件或文件夹。确认后移到废纸篓，不直接抹掉。
enum DirectoryItemTrash {
    /// 路径等于被删项，或在它里面。避免「书」误伤「书摘」。
    static func contains(path: String, deletedPath: String) -> Bool {
        path == deletedPath || path.hasPrefix(deletedPath + "/")
    }

    /// 目标必须是某个已授权根自己，或在它里面。空列表表示现在没有授权。
    static func isInsideGrantedFolder(_ url: URL, roots: [URL]) -> Bool {
        roots.contains { FolderAccessPolicy.contains(candidate: url, root: $0) }
    }

    /// 移到废纸篓。调用方负责先确认授权，并在访问仍然有效时调用。
    static func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

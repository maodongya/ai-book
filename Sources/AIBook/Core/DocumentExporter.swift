import AppKit
import Foundation
import UniformTypeIdentifiers

/// 另存为面板的默认目录、上次目录记忆，以及 UTF-8 文本写出。不负责选区算法。
enum DocumentExporter {
    /// 进化/能力列表上的短标签。
    static let capabilityLabel = "导出"
    /// 菜单旁的快捷键提示，键位来自 BookKeyboardShortcuts。
    static let shortcutHint = "\(BookKeyboardShortcuts.saveAsHint) 另存为 · \(BookKeyboardShortcuts.exportSelectionHint) 导出选中"
    /// 导出进化命令时的默认文件名。
    static let evolutionCommandsSuggestedName = "进化命令.txt"

    /// 旧版只存了路径。新代码不再读它，避免按裸路径探磁盘。
    private static let lastDirectoryKey = "DocumentExporter.lastDirectory"
    /// 上次目录的安全作用域书签。
    private static let lastDirectoryBookmarkKey = "DocumentExporter.lastDirectoryBookmark"
    /// 这次进程里已经打开访问的上次目录。
    private static var heldDirectory: URL?
    /// heldDirectory 是否调用过 start，停的时候要配对。
    private static var heldDirectoryStarted = false

    /// 上次用户通过面板选过的目录。只从书签恢复，不按旧路径去 stat。
    static var lastDirectoryURL: URL? {
        get {
            if let heldDirectory { return heldDirectory } // 这次进程已经打开过
            guard let data = UserDefaults.standard.data(forKey: lastDirectoryBookmarkKey),
                  let resolved = SecurityScopedBookmark.resolve(data) else { return nil } // 没书签就让面板自己决定
            let started = resolved.url.startAccessingSecurityScopedResource() // 解析后仍要打开访问
            if !started && UserFolderGrants.isSandboxed { return nil } // 沙盒里书签无效就忘掉
            heldDirectory = resolved.url
            heldDirectoryStarted = started
            return resolved.url
        }
        set {
            if heldDirectoryStarted, let heldDirectory {
                heldDirectory.stopAccessingSecurityScopedResource() // 换目录前先停旧的
            }
            heldDirectory = nil
            heldDirectoryStarted = false
            UserDefaults.standard.removeObject(forKey: lastDirectoryKey) // 旧的裸路径不再使用
            guard let url = newValue?.standardizedFileURL else {
                UserDefaults.standard.removeObject(forKey: lastDirectoryBookmarkKey) // 显式清空
                return
            }
            let started = url.startAccessingSecurityScopedResource()
            if started || !UserFolderGrants.isSandboxed {
                heldDirectory = url // 这次进程的面板还能指到这里
                heldDirectoryStarted = started
            }
            if let data = SecurityScopedBookmark.make(for: url) {
                UserDefaults.standard.set(data, forKey: lastDirectoryBookmarkKey) // 只记书签
            }
        }
    }

    /// 另存为面板的起始目录：当前文件旁 → 上次书签目录 → 沙盒临时目录。不探桌面或整盘。
    static func defaultDirectory(currentFileURL: URL?) -> URL {
        if let directory = currentFileURL?.deletingLastPathComponent() {
            return directory // 和正在读的书放一起；真正写入仍要授权
        }
        if let last = lastDirectoryURL {
            return last // 沿用上次面板选过的目录
        }
        return FileManager.default.temporaryDirectory // 沙盒里这是容器内目录，不是用户磁盘
    }

    /// 建议文件名：无名变 未命名.txt；已有扩展名则保留；选区导出加「-选中摘录」。
    static func suggestedFileName(currentFileURL: URL?, fileName: String, selectionSuffix: Bool = false) -> String {
        let base = currentFileURL?.lastPathComponent ?? fileName // 优先用当前打开文件的名字
        let normalized: String
        if base == "未命名" || base.isEmpty {
            normalized = "未命名.txt" // 空书也要能导出成可双击的 txt
        } else if base.lowercased().hasSuffix(".txt") {
            normalized = base // 已经是 txt，不再叠扩展名
        } else {
            normalized = "\(base).txt" // 原文是 epub/md 时仍导出纯文本
        }

        guard selectionSuffix else { return normalized } // 全文导出到此为止

        let stem = (normalized as NSString).deletingPathExtension // 去掉 .txt 再加后缀，避免 .txt-选中摘录.txt
        return "\(stem)-选中摘录.txt"
    }

    /// 用户没写扩展名时补 .txt，避免保存成无类型文件。
    static func normalizedDestinationURL(from url: URL) -> URL {
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension("txt")
        }
        return url
    }

    /// 跑系统另存为面板；取消返回 nil。成功则记住目录。必须在主线程。
    @MainActor
    static func runSavePanel(
        title: String,
        message: String,
        suggestedName: String,
        directory: URL
    ) -> URL? {
        let panel = NSSavePanel() // 系统面板，不自己画
        panel.title = title // 调用方传入场景标题（全文/选区）
        panel.message = message
        panel.allowedContentTypes = [.plainText] // 只许纯文本，避免误存 rtf
        panel.canCreateDirectories = true // 允许用户在面板里新建文件夹
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = directory

        guard panel.runModal() == .OK, let url = panel.url else { return nil } // 取消或关窗
        let destination = normalizedDestinationURL(from: url) // 补扩展名
        lastDirectoryURL = destination.deletingLastPathComponent() // 记下这次目录，下次默认打开
        return destination
    }

    /// 原子写入 UTF-8 文本。失败抛给调用方弹错。
    static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8) // atomically 避免写到一半断电留下半文件
    }
}

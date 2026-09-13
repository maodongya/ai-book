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

    /// 上次成功导出目录的 UserDefaults 键，只在本类型里出现。
    private static let lastDirectoryKey = "DocumentExporter.lastDirectory"

    /// 上次用户选过且仍然存在的目录；路径没了当 nil，避免面板指到黑洞。
    static var lastDirectoryURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: lastDirectoryKey) else { return nil } // 从未导出过
            let url = URL(fileURLWithPath: path, isDirectory: true) // 按目录打开，不是文件
            return FileManager.default.fileExists(atPath: url.path) ? url : nil // 目录被删则忘掉
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: lastDirectoryKey) // 只记 path，跨卷也能读
            } else {
                UserDefaults.standard.removeObject(forKey: lastDirectoryKey) // 显式清空
            }
        }
    }

    /// 另存为面板的起始目录：当前文件旁 → 上次目录 → 桌面 → 临时目录。
    static func defaultDirectory(currentFileURL: URL?) -> URL {
        if let directory = currentFileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: directory.path) {
            return directory // 和正在读的书放一起，少让用户找
        }
        if let last = lastDirectoryURL {
            return last // 沿用上次导出位置
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory // 桌面不可用时才进临时目录
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

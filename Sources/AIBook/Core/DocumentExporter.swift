import AppKit
import Foundation
import UniformTypeIdentifiers

/// Save-as panel defaults, directory memory, and UTF-8 text export.
enum DocumentExporter {
    static let capabilityLabel = "导出"
    static let shortcutHint = "\(BookKeyboardShortcuts.saveAsHint) 另存为 · \(BookKeyboardShortcuts.exportSelectionHint) 导出选中"
    static let evolutionCommandsSuggestedName = "进化命令.txt"

    private static let lastDirectoryKey = "DocumentExporter.lastDirectory"

    static var lastDirectoryURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: lastDirectoryKey) else { return nil }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: lastDirectoryKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastDirectoryKey)
            }
        }
    }

    static func defaultDirectory(currentFileURL: URL?) -> URL {
        if let directory = currentFileURL?.deletingLastPathComponent(),
           FileManager.default.fileExists(atPath: directory.path) {
            return directory
        }
        if let last = lastDirectoryURL {
            return last
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    static func suggestedFileName(currentFileURL: URL?, fileName: String, selectionSuffix: Bool = false) -> String {
        let base = currentFileURL?.lastPathComponent ?? fileName
        let normalized: String
        if base == "未命名" || base.isEmpty {
            normalized = "未命名.txt"
        } else if base.lowercased().hasSuffix(".txt") {
            normalized = base
        } else {
            normalized = "\(base).txt"
        }

        guard selectionSuffix else { return normalized }

        let stem = (normalized as NSString).deletingPathExtension
        return "\(stem)-选中摘录.txt"
    }

    static func normalizedDestinationURL(from url: URL) -> URL {
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension("txt")
        }
        return url
    }

    @MainActor
    static func runSavePanel(
        title: String,
        message: String,
        suggestedName: String,
        directory: URL
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.message = message
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = directory

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let destination = normalizedDestinationURL(from: url)
        lastDirectoryURL = destination.deletingLastPathComponent()
        return destination
    }

    static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

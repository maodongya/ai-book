import Foundation

/// 左页命令笔记的读写。优先 Application Support 已存稿，再 bundle，再仓库 readme.txt。
final class ReadmeNotesStore {
    static let shared = ReadmeNotesStore()

    /// Application Support 里的文件名，和仓库 readme.txt 不是同一份。
    private let fileName = "readme-notes.txt"

    /// ~/Library/Application Support/AIBook/readme-notes.txt
    var notesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    /// 启动时填左页：已保存 → 包内 readme.txt → 仓库 readme.txt → 空串。
    func loadInitialContent() -> String {
        if let saved = try? String(contentsOf: notesURL, encoding: .utf8), !saved.isEmpty {
            return saved // 用户改过的笔记优先
        }

        if let bundled = Bundle.main.url(forResource: "readme", withExtension: "txt"),
           let text = try? String(contentsOf: bundled, encoding: .utf8) {
            return text // 安装包自带的默认笔记
        }

        let projectReadme = CursorService.defaultProjectDirectory()?
            .appendingPathComponent("readme.txt")
        if let projectReadme,
           FileManager.default.fileExists(atPath: projectReadme.path),
           let text = try? String(contentsOf: projectReadme, encoding: .utf8) {
            return text // 开发态读仓库
        }

        return "" // 都没有就空页，让用户自己写
    }

    /// 原子写入 UTF-8。失败抛给调用方。
    func save(_ content: String) throws {
        try content.write(to: notesURL, atomically: true, encoding: .utf8)
    }
}

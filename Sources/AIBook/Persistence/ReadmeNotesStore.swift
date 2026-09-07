import Foundation

final class ReadmeNotesStore {
    static let shared = ReadmeNotesStore()

    private let fileName = "readme-notes.txt"

    var notesURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    func loadInitialContent() -> String {
        if let saved = try? String(contentsOf: notesURL, encoding: .utf8), !saved.isEmpty {
            return saved
        }

        if let bundled = Bundle.main.url(forResource: "readme", withExtension: "txt"),
           let text = try? String(contentsOf: bundled, encoding: .utf8) {
            return text
        }

        let projectReadme = CursorService.defaultProjectDirectory()?
            .appendingPathComponent("readme.txt")
        if let projectReadme,
           FileManager.default.fileExists(atPath: projectReadme.path),
           let text = try? String(contentsOf: projectReadme, encoding: .utf8) {
            return text
        }

        return ""
    }

    func save(_ content: String) throws {
        try content.write(to: notesURL, atomically: true, encoding: .utf8)
    }
}

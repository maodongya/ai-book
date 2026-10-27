import Foundation

/// 与讲解 `.txt` 同目录的结构化对齐 sidecar（`*.aibook-explanation.json`）。
enum ExplanationAlignmentSidecar {
    static func url(forExplanationFile txtURL: URL) -> URL {
        let base = txtURL.deletingPathExtension().path
        return URL(fileURLWithPath: base + ".aibook-explanation.json")
    }

    static func write(_ alignment: TranslationAlignment, near txtURL: URL) {
        let url = url(forExplanationFile: txtURL)
        guard let data = try? JSONEncoder().encode(alignment) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func read(near txtURL: URL) -> TranslationAlignment? {
        let url = url(forExplanationFile: txtURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranslationAlignment.self, from: data)
    }
}

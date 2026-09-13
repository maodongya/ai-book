import Foundation

/// 与 `.txt` 译文同目录的结构化对齐 sidecar（`*.aibook-translation.json`）。
enum TranslationAlignmentSidecar {
    /// sidecar 文件名：`article.txt` → `article.aibook-translation.json`。
    static func url(forTranslationFile txtURL: URL) -> URL {
        let base = txtURL.deletingPathExtension().path
        return URL(fileURLWithPath: base + ".aibook-translation.json")
    }

    /// 写入对齐；失败静默，不影响 txt 已保存。
    static func write(_ alignment: TranslationAlignment, near txtURL: URL) {
        let url = url(forTranslationFile: txtURL)
        guard let data = try? JSONEncoder().encode(alignment) else { return }  // 编码失败就放弃
        try? data.write(to: url, options: .atomic)  // 与 txt 同目录
    }

    /// 读取 sidecar；不存在或损坏返回 nil。
    static func read(near txtURL: URL) -> TranslationAlignment? {
        let url = url(forTranslationFile: txtURL)
        guard let data = try? Data(contentsOf: url) else { return nil }  // 没有 sidecar
        return try? JSONDecoder().decode(TranslationAlignment.self, from: data)
    }
}

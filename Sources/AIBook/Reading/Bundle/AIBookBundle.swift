import Foundation

/// 一种语言在包里的译文和讲解。某一侧可以缺。
struct AIBookLanguagePayload: Equatable {
    var translationText: String?
    var translationAlignment: TranslationAlignment?
    var explanationText: String?
    var explanationAlignment: TranslationAlignment?

    var hasTranslation: Bool {
        !(translationText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasExplanation: Bool {
        !(explanationText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// `.aibook`：zip 里的原文，以及按 BCP-47 存放的译文和讲解。
struct AIBookBundle: Equatable {
    static let format = "aibook-bundle"
    static let version = 1

    var title: String
    var source: String
    var languages: [String: AIBookLanguagePayload]

    enum Failure: Error {
        case invalidManifest
        case unsupportedVersion
        case missingSource
        case unsafePath
    }

    /// 写入一种语言的译文或讲解。传入的字段覆盖旧值；`nil` 表示这一侧不动。
    mutating func upsert(
        languageID: String,
        translationText: String? = nil,
        translationAlignment: TranslationAlignment? = nil,
        replaceTranslationAlignment: Bool = false,
        explanationText: String? = nil,
        explanationAlignment: TranslationAlignment? = nil,
        replaceExplanationAlignment: Bool = false
    ) {
        guard Self.isLanguageID(languageID) else { return }
        var payload = languages[languageID] ?? AIBookLanguagePayload()
        if let translationText {
            payload.translationText = translationText
        }
        if replaceTranslationAlignment {
            payload.translationAlignment = translationAlignment
        }
        if let explanationText {
            payload.explanationText = explanationText
        }
        if replaceExplanationAlignment {
            payload.explanationAlignment = explanationAlignment
        }
        if payload.hasTranslation || payload.hasExplanation {
            languages[languageID] = payload
        } else {
            languages.removeValue(forKey: languageID)
        }
    }

    func encoded() throws -> Data {
        var files: [String: Data] = [:]
        let sourcePath = "source/source.txt"
        guard let sourceData = source.data(using: .utf8) else { throw Failure.missingSource }
        files[sourcePath] = sourceData

        var languageRefs: [Manifest.Language] = []
        for id in languages.keys.sorted() {
            guard Self.isLanguageID(id) else { continue }
            let payload = languages[id] ?? AIBookLanguagePayload()
            var ref = Manifest.Language(id: id, translation: nil, explanation: nil)
            if payload.hasTranslation, let text = payload.translationText, let data = text.data(using: .utf8) {
                let textPath = "languages/\(id)/translation/translation.txt"
                files[textPath] = data
                var part = Manifest.Part(text: textPath, alignment: nil)
                if let alignment = payload.translationAlignment,
                   let alignmentData = try? JSONEncoder().encode(alignment) {
                    let alignmentPath = "languages/\(id)/translation/alignment.json"
                    files[alignmentPath] = alignmentData
                    part.alignment = alignmentPath
                }
                ref.translation = part
            }
            if payload.hasExplanation, let text = payload.explanationText, let data = text.data(using: .utf8) {
                let textPath = "languages/\(id)/explanation/explanation.txt"
                files[textPath] = data
                var part = Manifest.Part(text: textPath, alignment: nil)
                if let alignment = payload.explanationAlignment,
                   let alignmentData = try? JSONEncoder().encode(alignment) {
                    let alignmentPath = "languages/\(id)/explanation/alignment.json"
                    files[alignmentPath] = alignmentData
                    part.alignment = alignmentPath
                }
                ref.explanation = part
            }
            if ref.translation != nil || ref.explanation != nil {
                languageRefs.append(ref)
            }
        }

        let manifest = Manifest(
            format: Self.format,
            version: Self.version,
            title: title,
            source: Manifest.SourceFile(path: sourcePath),
            languages: languageRefs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        files["manifest.json"] = try encoder.encode(manifest)
        return try ZipArchive.archive(files: files)
    }

    static func decode(_ data: Data) throws -> AIBookBundle {
        let files = try ZipArchive.extract(data)
        guard let manifestData = files["manifest.json"] else { throw Failure.invalidManifest }
        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.format == format else { throw Failure.invalidManifest }
        guard manifest.version == version else { throw Failure.unsupportedVersion }
        guard ZipArchive.isSafePath(manifest.source.path),
              let sourceData = files[manifest.source.path],
              let source = String(data: sourceData, encoding: .utf8) else {
            throw Failure.missingSource
        }

        var languages: [String: AIBookLanguagePayload] = [:]
        for language in manifest.languages {
            guard isLanguageID(language.id) else { continue }
            var payload = AIBookLanguagePayload()
            if let part = language.translation {
                payload.translationText = try textFile(part.text, in: files)
                payload.translationAlignment = try alignmentFile(part.alignment, in: files)
            }
            if let part = language.explanation {
                payload.explanationText = try textFile(part.text, in: files)
                payload.explanationAlignment = try alignmentFile(part.alignment, in: files)
            }
            if payload.hasTranslation || payload.hasExplanation {
                languages[language.id] = payload
            }
        }
        return AIBookBundle(title: manifest.title, source: source, languages: languages)
    }

    static func isLanguageID(_ id: String) -> Bool {
        guard let language = TranslationTargetLanguage(rawValue: id) else { return false }
        return language != .followAppLanguage
    }

    /// 界面语言收成包里用的 BCP-47。跟随系统时按当前地区映射。
    static func contentLanguageID(appLanguage: BookAppLanguage) -> String {
        switch appLanguage {
        case .system:
            return TranslationTargetLanguage.matchingSystemLocale().rawValue
        case .zhHans:
            return TranslationTargetLanguage.zhHans.rawValue
        case .en:
            return TranslationTargetLanguage.en.rawValue
        case .ja:
            return TranslationTargetLanguage.ja.rawValue
        case .de:
            return TranslationTargetLanguage.de.rawValue
        case .fr:
            return TranslationTargetLanguage.fr.rawValue
        case .it:
            return TranslationTargetLanguage.it.rawValue
        case .la:
            return TranslationTargetLanguage.la.rawValue
        case .el:
            return TranslationTargetLanguage.el.rawValue
        }
    }

    private static func textFile(_ path: String, in files: [String: Data]) throws -> String? {
        guard ZipArchive.isSafePath(path), let data = files[path] else { throw Failure.unsafePath }
        guard let text = String(data: data, encoding: .utf8) else { throw Failure.invalidManifest }
        return text
    }

    private static func alignmentFile(_ path: String?, in files: [String: Data]) throws -> TranslationAlignment? {
        guard let path else { return nil }
        guard ZipArchive.isSafePath(path), let data = files[path] else { throw Failure.unsafePath }
        return try? JSONDecoder().decode(TranslationAlignment.self, from: data)
    }

    private struct Manifest: Codable {
        var format: String
        var version: Int
        var title: String
        var source: SourceFile
        var languages: [Language]

        struct SourceFile: Codable {
            var path: String
        }

        struct Language: Codable {
            var id: String
            var translation: Part?
            var explanation: Part?
        }

        struct Part: Codable {
            var text: String
            var alignment: String?
        }
    }
}

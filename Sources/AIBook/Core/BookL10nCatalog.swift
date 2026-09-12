import Foundation

/// Runtime lookup for `Localizable.xcstrings` (SPM copies JSON; `String(localized:)` does not resolve it).
enum BookL10nCatalog {
    private static let lock = NSLock()
    private static var table: [String: [String: String]] = [:]
    private static var isLoaded = false

    static func string(forKey key: String, language: BookAppLanguage) -> String {
        loadIfNeeded()
        let code = languageCode(for: language)
        if let value = table[key]?[code], !value.isEmpty {
            return value
        }
        if code != "en", let value = table[key]?["en"], !value.isEmpty {
            return value
        }
        if let value = table[key]?["zh-Hans"], !value.isEmpty {
            return value
        }
        return key
    }

    private static func loadIfNeeded() {
        lock.lock()
        defer { lock.unlock() }
        guard !isLoaded else { return }
        isLoaded = true

        guard let url = resolveCatalogURL(),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any]
        else {
            return
        }

        var parsed: [String: [String: String]] = [:]
        parsed.reserveCapacity(strings.count)

        for (key, rawEntry) in strings {
            guard let entry = rawEntry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else { continue }

            var langMap: [String: String] = [:]
            for (lang, rawLoc) in localizations {
                guard let loc = rawLoc as? [String: Any] else { continue }
                if let unit = loc["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String {
                    langMap[lang] = value
                } else if let variations = loc["variations"] as? [String: Any],
                          let device = variations["device"] as? [String: Any],
                          let generic = device["generic"] as? [String: Any],
                          let unit = generic["stringUnit"] as? [String: Any],
                          let value = unit["value"] as? String {
                    langMap[lang] = value
                }
            }
            if !langMap.isEmpty {
                parsed[key] = langMap
            }
        }
        table = parsed
    }

    private static func resolveCatalogURL() -> URL? {
        if let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") {
            return url
        }
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") {
            return url
        }
        return nil
    }

    private static func languageCode(for language: BookAppLanguage) -> String {
        switch language {
        case .system:
            return normalizedLanguageCode(Locale.current.identifier)
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        case .ja:
            return "ja"
        case .de:
            return "de"
        case .fr:
            return "fr"
        case .it:
            return "it"
        case .la:
            return "la"
        case .el:
            return "el"
        }
    }

    private static func normalizedLanguageCode(_ identifier: String) -> String {
        let id = identifier.lowercased()
        if id.hasPrefix("zh") { return "zh-Hans" }
        if id.hasPrefix("ja") { return "ja" }
        if id.hasPrefix("de") { return "de" }
        if id.hasPrefix("fr") { return "fr" }
        if id.hasPrefix("it") { return "it" }
        if id.hasPrefix("el") { return "el" }
        if id == "la" || id.hasPrefix("la_") { return "la" }
        if id.hasPrefix("en") { return "en" }
        return "en"
    }
}

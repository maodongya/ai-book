import Foundation

/// 运行时查 `Localizable.xcstrings`。SPM 拷的是 JSON，`String(localized:)` 解析不了，所以自己读。
enum BookL10nCatalog {
    /// 保护 table / isLoaded，目录只加载一次。
    private static let lock = NSLock()
    /// key →（BCP-47 → 文案）。空表表示加载失败，string 会退回 key 本身。
    private static var table: [String: [String: String]] = [:]
    /// 是否已经尝试加载；失败也标 true，避免每次取文案都打磁盘。
    private static var isLoaded = false

    /// 按界面语言取条目：当前语言 → en → zh-Hans → key 本身。空字符串当缺失。
    static func string(forKey key: String, language: BookAppLanguage) -> String {
        loadIfNeeded() // 第一次才读磁盘
        let code = languageCode(for: language) // system 在这里解析成具体目录键
        if let value = table[key]?[code], !value.isEmpty {
            return value // 当前语言命中
        }
        if code != "en", let value = table[key]?["en"], !value.isEmpty {
            return value // 缺译用英文，避免中文界面掺简体残留
        }
        if let value = table[key]?["zh-Hans"], !value.isEmpty {
            return value // 英文也没有时用简体，开发期常见
        }
        return key // 目录里没有这条，返回 key 方便发现漏译
    }

    /// 线程安全地加载一次 xcstrings JSON。
    private static func loadIfNeeded() {
        lock.lock()
        defer { lock.unlock() } // 无论成功失败都解锁
        guard !isLoaded else { return } // 已试过就不再读
        isLoaded = true // 先标记，坏文件也不会死循环

        guard let url = resolveCatalogURL(),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any]
        else {
            return // 找不到或坏 JSON，table 保持空，string 退回 key
        }

        var parsed: [String: [String: String]] = [:]
        parsed.reserveCapacity(strings.count) // 目录条目多，先占容量

        for (key, rawEntry) in strings {
            guard let entry = rawEntry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any]
            else { continue } // 跳过注释-only 或损坏条目

            var langMap: [String: String] = [:]
            for (lang, rawLoc) in localizations {
                guard let loc = rawLoc as? [String: Any] else { continue }
                if let unit = loc["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String {
                    langMap[lang] = value // 普通字符串
                } else if let variations = loc["variations"] as? [String: Any],
                          let device = variations["device"] as? [String: Any],
                          let generic = device["generic"] as? [String: Any],
                          let unit = generic["stringUnit"] as? [String: Any],
                          let value = unit["value"] as? String {
                    langMap[lang] = value // device variation 取 generic，Mac 没有独立文案
                }
            }
            if !langMap.isEmpty {
                parsed[key] = langMap // 完全空的 key 不进表
            }
        }
        table = parsed
    }

    /// 模块包优先，其次主 bundle（已安装 app）。
    private static func resolveCatalogURL() -> URL? {
        if let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") {
            return url // swift run / 测试
        }
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") {
            return url // 装好的 .app
        }
        return nil
    }

    /// 产品语言 → 目录键。`.system` 按本机 Locale 归一。
    private static func languageCode(for language: BookAppLanguage) -> String {
        switch language {
        case .system:
            return normalizedLanguageCode(Locale.current.identifier) // 使用时解析，不在点选时写死
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

    /// 把任意 Locale 标识收到八种目录键之一，未覆盖的当 en。
    private static func normalizedLanguageCode(_ identifier: String) -> String {
        let id = identifier.lowercased()
        if id.hasPrefix("zh") { return "zh-Hans" } // 繁体也先用简体目录
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

import Foundation

/// 听写语言。界面语言优先；没有对应听写包时改用简体中文，再改用本机语言。
enum OperationSpeechLocale {
    /// 从系统支持的语言里挑一个可用的。拉丁语没有听写包，会落到后面的回退。
    static func resolve(
        uiIdentifier: String,
        supported: [Locale],
        currentIdentifier: String = Locale.current.identifier,
        isAvailable: (Locale) -> Bool
    ) -> Locale? {
        var seen = Set<String>() // 界面已经是中文时不重复试
        let identifiers = [uiIdentifier, "zh-Hans", currentIdentifier]
        for identifier in identifiers {
            let key = identifier.lowercased()
            guard seen.insert(key).inserted else { continue }
            if let match = match(identifier: identifier, supported: supported, isAvailable: isAvailable) {
                return match
            }
        }
        return nil
    }

    /// 按语言前缀找一个可用地区。简体优先 zh-Hans / zh-CN，不拿繁体凑。
    private static func match(
        identifier: String,
        supported: [Locale],
        isAvailable: (Locale) -> Bool
    ) -> Locale? {
        let wanted = identifier.lowercased()
        let available = supported.filter(isAvailable)
        if wanted.hasPrefix("zh") {
            return available.first(where: prefersSimplifiedChinese)
                ?? available.first { $0.identifier.lowercased().hasPrefix("zh") }
        }
        let code = wanted.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? wanted
        guard code != "la" else { return nil } // 系统没有拉丁语听写
        return available.first { locale in
            let id = locale.identifier.lowercased()
            return id == code || id.hasPrefix(code + "-") || id.hasPrefix(code + "_")
        }
    }

    /// 简体听写包。繁体标识排除。
    private static func prefersSimplifiedChinese(_ locale: Locale) -> Bool {
        let id = locale.identifier.lowercased()
        if id.contains("hant") || id.hasPrefix("zh-tw") || id.hasPrefix("zh_tw") || id.hasPrefix("zh-hk") || id.hasPrefix("zh_hk") {
            return false
        }
        return id.contains("hans") || id.hasPrefix("zh-cn") || id.hasPrefix("zh_cn")
    }
}

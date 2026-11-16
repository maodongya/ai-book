import Foundation

/// 把界面语言写进本应用的 AppleLanguages，让系统权限框读对应的 InfoPlist.strings。
enum InterfaceLanguageLaunch {
    /// 进程入口调用。必须早于系统第一次读取 Bundle 语言。
    static func applySaved() {
        let stored = UserDefaults.standard.string(forKey: "aiBook.appLanguage")
        apply(BookAppLanguage.migrated(from: stored))
    }

    /// `.system` 清掉覆盖，让系统语言自己选 lproj。显式语言写成单个 BCP-47。
    static func apply(_ language: BookAppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        default:
            guard let code = language.localeIdentifier else { return }
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }
}

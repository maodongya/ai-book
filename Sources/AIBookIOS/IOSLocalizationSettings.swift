import Foundation

/// iOS 界面语言。与 Mac 共用 `aiBook.appLanguage`，切语言后整支界面重取目录。
@MainActor
final class IOSLocalizationSettings: ObservableObject {
  /// 与 AppSettings / BookL10n 相同的键。
  private static let languageKey = "aiBook.appLanguage"

  @Published var appLanguage: BookAppLanguage {
    didSet {
      guard appLanguage != oldValue else { return }
      UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.languageKey) // 落盘与 Mac 一致
      localizationRevision &+= 1 // 逼 SwiftUI 重绘 BookL10n 文案
    }
  }

  /// 语言切换世代号，不进 Environment 也能 `.id` 刷新。
  @Published private(set) var localizationRevision = 0

  init() {
    appLanguage = BookAppLanguage.migrated(from: UserDefaults.standard.string(forKey: Self.languageKey)) // 读旧值并迁
  }
}
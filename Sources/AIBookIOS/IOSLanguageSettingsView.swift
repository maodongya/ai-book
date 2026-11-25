import SwiftUI

/// 设置页：应用界面语言。与 Mac 的 BookLanguageSettingsView 同一套枚举和偏好键。
struct IOSLanguageSettingsView: View {
  @ObservedObject var localization: IOSLocalizationSettings

  var body: some View {
    let _ = localization.localizationRevision // 切语言后重取 Picker 文案
    Picker(BookL10n.string("settings.language"), selection: $localization.appLanguage) {
      ForEach(BookAppLanguage.allCases) { language in
        if language == .system {
          Text(BookL10n.string("language.system")).tag(language) // 「跟随系统」走目录
        } else {
          Text(language.nativeDisplayName).tag(language) // 自称 endonym
        }
      }
    }
    Text(BookL10n.string("settings.language.hint"))
      .font(.footnote)
      .foregroundStyle(IOSPaper.inkMuted)
  }
}
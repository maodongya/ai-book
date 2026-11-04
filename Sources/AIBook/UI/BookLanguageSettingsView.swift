import SwiftUI

/// 设置页：应用界面语言。点选写 BookAppLanguage，不在这里解析成具体语言。
struct BookLanguageSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared // 切预设时墨色跟着变，不必拆掉外层滚动

    var body: some View {
        let _ = settings.localizationRevision // 切语言后重绘 Picker 文案
        let _ = styleManager.revision
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent(BookL10n.string("settings.language")) {
                Picker("", selection: $settings.appLanguage) {
                    ForEach(BookAppLanguage.allCases) { language in
                        if language == .system {
                            Text(BookL10n.string("language.system")).tag(language) // 「跟随系统」走目录
                        } else {
                            Text(language.nativeDisplayName).tag(language) // 自称 endonym，避免未译语言菜单空白
                        }
                    }
                }
                .labelsHidden()
            }

            Text(BookL10n.string("settings.language.hint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
    }
}

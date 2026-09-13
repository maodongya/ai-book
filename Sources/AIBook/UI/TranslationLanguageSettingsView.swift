import SwiftUI

/// 设置页：译文目标语言。只绑 AppSettings，不在这里解析「跟随界面语言」。
struct TranslationLanguageSettingsView: View {
    /// 共享设置；切换语言会写 TranslationTargetLanguageStore。
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.localizationRevision // 读世代号，切界面语言时重绘选项文案
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent(BookL10n.string("translation.target.title")) {
                Picker("", selection: $settings.translationTargetLanguage) {
                    ForEach(TranslationTargetLanguage.allCases) { language in
                        Text(language.localizedName).tag(language) // 显示名走目录，tag 是枚举本身
                    }
                }
                .labelsHidden() // 标题已在 LabeledContent
            }

            Text(BookL10n.string("translation.target.hint")) // 说明「跟随」在使用时解析
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
    }
}

import SwiftUI

/// 设置页：译文目标语言。只绑 AppSettings，不在这里解析「跟随界面语言」。
struct TranslationLanguageSettingsView: View {
    /// 共享设置；切换语言会写 TranslationTargetLanguageStore。
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.localizationRevision // 读世代号，切界面语言时重绘选项文案
        VStack(alignment: .leading, spacing: 12) {
            Text(BookL10n.string("translation.target.title"))
                .font(BookTheme.captionFont)

            ForEach(TranslationTargetLanguage.selectableTargets) { language in
                let selected = settings.translationTargetLanguages.contains(language)
                Toggle(language.localizedName, isOn: Binding(
                    get: { selected },
                    set: { isOn in
                        if isOn != selected {
                            settings.toggleTranslationTargetLanguage(language)
                        }
                    }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .disabled(selected && settings.translationTargetLanguages.count == 1)
            }

            Text(BookL10n.string("translation.target.multiHint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
    }
}

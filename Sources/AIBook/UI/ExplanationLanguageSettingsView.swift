import SwiftUI

/// 设置页：讲解语言。只绑 AppSettings。
struct ExplanationLanguageSettingsView: View {
    /// 共享设置；切换语言会写 ExplanationTargetLanguageStore。
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.localizationRevision // 读世代号，切界面语言时重绘选项文案
        VStack(alignment: .leading, spacing: 12) {
            Text(BookL10n.string("explanation.target.title"))
                .font(BookTheme.captionFont)

            ForEach(TranslationTargetLanguage.selectableTargets) { language in
                let selected = settings.explanationTargetLanguages.contains(language)
                Toggle(language.localizedName, isOn: Binding(
                    get: { selected },
                    set: { isOn in
                        if isOn != selected {
                            settings.toggleExplanationTargetLanguage(language)
                        }
                    }
                ))
                .toggleStyle(CheckboxToggleStyle())
                .disabled(selected && settings.explanationTargetLanguages.count == 1)
            }

            Text(BookL10n.string("explanation.target.multiHint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
    }
}

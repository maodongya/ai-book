import SwiftUI

struct TranslationLanguageSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.localizationRevision
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent(BookL10n.string("translation.target.title")) {
                Picker("", selection: $settings.translationTargetLanguage) {
                    ForEach(TranslationTargetLanguage.allCases) { language in
                        Text(language.localizedName).tag(language)
                    }
                }
                .labelsHidden()
            }

            Text(BookL10n.string("translation.target.hint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
    }
}

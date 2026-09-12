import SwiftUI

struct BookLanguageSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.localizationRevision
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent(BookL10n.string("settings.language")) {
                Picker("", selection: $settings.appLanguage) {
                    ForEach(BookAppLanguage.allCases) { language in
                        if language == .system {
                            Text(BookL10n.string("language.system")).tag(language)
                        } else {
                            Text(language.nativeDisplayName).tag(language)
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

import SwiftUI

/// 讲解/翻译目标语言与节选占比。与 Mac 共用 UserDefaults 键。
struct IOSBookLanguageSettings: View {
    @ObservedObject var localization: IOSLocalizationSettings
    @ObservedObject var settings: IOSModelSettings

    @State private var translationLanguages: [TranslationTargetLanguage] = []
    @State private var explanationLanguages: [TranslationTargetLanguage] = []

    var body: some View {
        let _ = localization.localizationRevision
        VStack(alignment: .leading, spacing: 12) {
            Text(BookL10n.string("target.translation"))
                .font(.subheadline.weight(.semibold))
            languageToggleGrid($translationLanguages) { saveTranslationLanguages() }

            Text(BookL10n.string("target.explanation"))
                .font(.subheadline.weight(.semibold))
            languageToggleGrid($explanationLanguages) { saveExplanationLanguages() }

            VStack(alignment: .leading, spacing: 6) {
                Text(BookL10n.string("context.label.excerpt"))
                    .font(.subheadline.weight(.semibold))
                Slider(value: $settings.bookContextPercent, in: 0.2...1.0, step: 0.05)
                Text("\(Int(settings.bookContextPercent * 100))%")
                    .font(.caption)
                    .foregroundStyle(IOSPaper.inkMuted)
            }
        }
        .onAppear { reload() }
        .onChange(of: localization.appLanguage) { _, _ in reload() }
    }

    private func languageToggleGrid(
        _ binding: Binding<[TranslationTargetLanguage]>,
        onChange: @escaping () -> Void
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TranslationTargetLanguage.selectableTargets) { language in
                let selected = binding.wrappedValue.contains(language)
                Button(language.localizedName) {
                    if selected {
                        binding.wrappedValue.removeAll { $0 == language }
                    } else {
                        binding.wrappedValue.append(language)
                    }
                    if binding.wrappedValue.isEmpty {
                        binding.wrappedValue = [TranslationTargetLanguage.matching(appLanguage: localization.appLanguage)]
                    }
                    onChange()
                }
                .buttonStyle(.bordered)
                .tint(selected ? IOSPaper.ink : IOSPaper.inkMuted)
            }
        }
    }

    private func reload() {
        translationLanguages = TranslationTargetLanguageStore.loadSelection(appLanguage: localization.appLanguage)
        explanationLanguages = ExplanationTargetLanguageStore.loadSelection(appLanguage: localization.appLanguage)
    }

    private func saveTranslationLanguages() {
        TranslationTargetLanguageStore.saveSelection(translationLanguages)
    }

    private func saveExplanationLanguages() {
        ExplanationTargetLanguageStore.saveSelection(explanationLanguages)
    }
}
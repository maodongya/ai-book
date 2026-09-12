import SwiftUI

struct BookStyleSettingsView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 12
            ) {
                ForEach(BookStylePresetID.allCases) { preset in
                    BookStylePreviewCard(
                        preset: preset,
                        isSelected: styleManager.presetID == preset
                    ) {
                        styleManager.selectPreset(preset)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(styleManager.presetID.displayName)
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Text(styleManager.presetID.summary)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(BookL10n.string("label.decorations"))
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                ornamentToggle(BookL10n.string("style.ribbon"), current: styleManager.tokens.ornaments.showBookmarkRibbon) {
                    styleManager.setShowBookmarkRibbon($0)
                }
                ornamentToggle(BookL10n.string("style.cornerFold"), current: styleManager.tokens.ornaments.showPageCornerFold) {
                    styleManager.setShowPageCornerFold($0)
                }
                ornamentToggle(BookL10n.string("style.paperTexture"), current: styleManager.tokens.ornaments.showPaperTexture) {
                    styleManager.setShowPaperTexture($0)
                }
                ornamentToggle(BookL10n.string("style.headerOrnament"), current: styleManager.tokens.ornaments.showHeaderOrnament) {
                    styleManager.setShowHeaderOrnament($0)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(BookL10n.string("label.readingTypography"))
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Text(BookL10n.string("label.readingTypographyHint"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsSecondary)

                HStack {
                    Text(BookL10n.string("label.font"))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                    Spacer()
                    Picker(BookL10n.string("label.font"), selection: $styleManager.readingFontFamilyID) {
                        ForEach(BookStyleCatalog.readingFontFamilyOptions) { option in
                            Text(option.localizedDisplayName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(BookTheme.settingsPrimary)
                }

                HStack {
                    Text(BookL10n.string("label.fontSize"))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                    Spacer()
                    Picker(BookL10n.string("label.fontSize"), selection: readingSizeBinding) {
                        Text(BookL10n.string("label.followTheme")).tag(Optional<Double>.none)
                        ForEach(BookStyleCatalog.readingSizes, id: \.self) { size in
                            Text("\(Int(size))").tag(Optional(size))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(BookTheme.settingsPrimary)
                }
            }
        }
    }

    private var readingSizeBinding: Binding<Double?> {
        Binding(
            get: { styleManager.readingFontSizeOverride },
            set: { styleManager.readingFontSizeOverride = $0 }
        )
    }

    private func ornamentToggle(_ title: String, current: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            Spacer()
            Toggle(title, isOn: Binding(
                get: { current },
                set: set
            ))
            .labelsHidden()
            .tint(BookTheme.gold)
        }
    }
}

struct BookStylePreviewCard: View {
    let preset: BookStylePresetID
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        let tokens = BookStyleCatalog.baseTokens(for: preset)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        tokens.bindingGradient
                            .frame(height: 22)
                        HStack(spacing: 0) {
                            tokens.colors.pageLeft
                            tokens.colors.pageRight
                        }
                        .frame(height: 34)
                        HStack(spacing: 6) {
                            Capsule().fill(tokens.accentGradient).frame(height: 7)
                            Capsule().fill(tokens.colors.buttonFillHover).frame(height: 7)
                        }
                        .padding(7)
                        .background(tokens.colors.deskBottom)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isSelected ? tokens.colors.chromeAccent : tokens.colors.pageEdge.opacity(0.7),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                    if isSelected {
                        Text(BookL10n.string("label.current"))
                            .font(BookTheme.captionFont.weight(.semibold))
                            .foregroundStyle(tokens.colors.buttonProminentText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background {
                                Capsule().fill(tokens.accentGradient)
                            }
                            .padding(6)
                    }
                }

                Text(preset.displayName)
                    .font(BookTheme.captionFont.weight(.medium))
                    .foregroundStyle(isSelected ? BookTheme.buttonProminentText : BookTheme.menuItemText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(isSelected ? AnyShapeStyle(BookTheme.goldGradient) : AnyShapeStyle(BookTheme.menuItemFill))
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        isSelected ? BookTheme.menuItemBorderHover : BookTheme.menuItemBorder,
                                        lineWidth: 1
                                    )
                            }
                    }
            }
        }
        .buttonStyle(.plain)
        .help(preset.summary)
    }
}

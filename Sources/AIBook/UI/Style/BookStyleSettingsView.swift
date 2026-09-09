import SwiftUI

struct BookStyleSettingsView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BookStylePresetID.allCases) { preset in
                        BookStylePreviewCard(
                            preset: preset,
                            isSelected: styleManager.presetID == preset
                        ) {
                            styleManager.selectPreset(preset)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(styleManager.presetID.displayName)
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.ink)
                Text(styleManager.presetID.summary)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("装饰细节")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.ink)
                ornamentToggle("书脊丝带", current: styleManager.tokens.ornaments.showBookmarkRibbon) {
                    styleManager.setShowBookmarkRibbon($0)
                }
                ornamentToggle("折页角", current: styleManager.tokens.ornaments.showPageCornerFold) {
                    styleManager.setShowPageCornerFold($0)
                }
                ornamentToggle("纸纹", current: styleManager.tokens.ornaments.showPaperTexture) {
                    styleManager.setShowPaperTexture($0)
                }
                ornamentToggle("页眉金线", current: styleManager.tokens.ornaments.showHeaderOrnament) {
                    styleManager.setShowHeaderOrnament($0)
                }
            }

            HStack {
                Text("左页字号")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Picker("左页字号", selection: readingSizeBinding) {
                    Text("跟随主题").tag(Optional<Double>.none)
                    ForEach(BookStyleCatalog.readingSizes, id: \.self) { size in
                        Text("\(Int(size))").tag(Optional(size))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(BookTheme.leather)
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
        Toggle(title, isOn: Binding(
            get: { current },
            set: set
        ))
        .font(BookTheme.captionFont)
        .foregroundStyle(BookTheme.ink)
        .tint(BookTheme.gold)
    }
}

struct BookStylePreviewCard: View {
    let preset: BookStylePresetID
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        let tokens = BookStyleCatalog.baseTokens(for: preset)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    tokens.bindingGradient
                        .frame(height: 28)
                    HStack(spacing: 0) {
                        tokens.colors.pageLeft
                        tokens.colors.pageRight
                    }
                    .frame(height: 44)
                    HStack(spacing: 6) {
                        Capsule().fill(tokens.accentGradient).frame(height: 8)
                        Capsule().fill(tokens.colors.buttonFillHover).frame(height: 8)
                    }
                    .padding(8)
                    .background(tokens.colors.deskBottom)
                }
                .frame(width: 160, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isSelected ? BookTheme.gold : BookTheme.pageEdge.opacity(0.7),
                            lineWidth: isSelected ? 2 : 1
                        )
                }

                HStack {
                    Text(preset.displayName)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.ink)
                    if isSelected {
                        Text("当前")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leatherShadow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(BookTheme.gold.opacity(0.85)) }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help(preset.summary)
    }
}

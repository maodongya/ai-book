import SwiftUI

/// 设置页：风格预设与阅读字体。纹样在 iOS 不画，但开关与 Mac 共用偏好，便于同步。
struct IOSStyleSettingsView: View {
  @ObservedObject var styleManager: BookStyleManager
  @ObservedObject var localization: IOSLocalizationSettings

  private let presetColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

  var body: some View {
    let _ = localization.localizationRevision // 预设名跟界面语言
    let _ = styleManager.revision // 选中态跟令牌
    VStack(alignment: .leading, spacing: 16) {
      Text(BookL10n.string("settings.themePresets"))
        .font(.headline)
        .foregroundStyle(IOSPaper.ink)
      LazyVGrid(columns: presetColumns, spacing: 12) {
        ForEach(BookStylePresetID.allCases) { preset in
          presetCard(preset)
        }
      }
      Text(styleManager.presetID.localizedSummary)
        .font(.footnote)
        .foregroundStyle(IOSPaper.inkMuted)
      typographySection
    }
  }

  /// 一块预设缩略，点选立刻换令牌。
  private func presetCard(_ preset: BookStylePresetID) -> some View {
    let tokens = BookStyleCatalog.baseTokens(for: preset)
    let selected = styleManager.presetID == preset
    return Button {
      styleManager.selectPreset(preset) // 与 Mac 同一落盘键
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(tokens.colors.pageLeft)
          .frame(height: 44)
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(selected ? tokens.colors.chromeAccent : tokens.colors.pageEdge.opacity(0.6), lineWidth: selected ? 2 : 1)
          }
        Text(preset.localizedDisplayName)
          .font(.caption.weight(.medium))
          .foregroundStyle(IOSPaper.ink)
          .lineLimit(1)
      }
    }
    .buttonStyle(.plain)
  }

  /// 阅读字体与字号，与 Mac 目录项一致。
  private var typographySection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(BookL10n.string("label.readingTypography"))
        .font(.headline)
        .foregroundStyle(IOSPaper.ink)
      Picker(BookL10n.string("label.font"), selection: $styleManager.readingFontFamilyID) {
        ForEach(BookStyleCatalog.readingFontFamilyOptions) { option in
          Text(option.localizedDisplayName).tag(option.id)
        }
      }
      Picker(BookL10n.string("label.fontSize"), selection: readingSizeBinding) {
        Text(BookL10n.string("label.followTheme")).tag(Optional<Double>.none)
        ForEach(BookStyleCatalog.readingSizes, id: \.self) { size in
          Text("\(Int(size))").tag(Optional(size))
        }
      }
    }
  }

  /// nil 表示跟随主题字号。
  private var readingSizeBinding: Binding<Double?> {
    Binding(
      get: { styleManager.readingFontSizeOverride },
      set: { styleManager.readingFontSizeOverride = $0 }
    )
  }
}
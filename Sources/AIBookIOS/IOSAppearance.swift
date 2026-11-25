import SwiftUI

/// 根视图挂上界面语言与阅读风格，跟 Mac 的 bookLocalizationEnvironment 同类。
struct IOSAppearanceModifier: ViewModifier {
  @ObservedObject var localization: IOSLocalizationSettings
  @ObservedObject var styleManager: BookStyleManager

  func body(content: Content) -> some View {
    let _ = localization.localizationRevision // 切语言后重跑子树
    let _ = styleManager.revision // 切预设后重跑子树
    IOSPaper.bind(styleManager) // 静态色板跟令牌走
    return content
      .environment(\.locale, BookL10n.activeLocale) // 日期与系统控件跟界面语言
      .preferredColorScheme(styleManager.colorScheme) // 跟 Mac 预设的亮暗
  }
}

extension View {
  /// 语言与风格都从这一处注入。
  func iosBookAppearance(localization: IOSLocalizationSettings, styleManager: BookStyleManager) -> some View {
    modifier(IOSAppearanceModifier(localization: localization, styleManager: styleManager))
  }
}
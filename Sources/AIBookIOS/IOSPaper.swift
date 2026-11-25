import SwiftUI

/// iOS 纸色与墨色。跟 Mac 的 BookStyleManager 同一套令牌，便于两端风格一致。
@MainActor
enum IOSPaper {
  private static weak var styleSource: BookStyleManager?

  /// 根视图挂上风格管理器后，全应用从这里取色。
  static func bind(_ manager: BookStyleManager) {
    styleSource = manager // 弱引用，避免和单例循环
  }

  private static var tokens: BookStyleTokens {
    styleSource?.tokens ?? BookStyleCatalog.baseTokens(for: .classicStudy) // 未绑定时用房书房风
  }

  /// 正文纸。
  static var page: Color { tokens.colors.pageLeft }
  /// 正文墨。
  static var ink: Color { tokens.colors.ink }
  /// 次要说明。
  static var inkMuted: Color { tokens.colors.inkMuted }
  /// 阅读正文字体。
  static var readingFont: Font { tokens.typography.readingFont }
  /// 标题字号，与 Mac label 接近。
  static var titleFont: Font { tokens.typography.titleFont }
  /// 风格 revision，body 里读一下可触发重绘。
  static var revision: String { styleSource?.revision ?? "-" }
}
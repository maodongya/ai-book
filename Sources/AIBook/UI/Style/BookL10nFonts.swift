import Foundation

/// 阅读字体选项的显示名。内置 id 走目录，自定义字体用 displayName 原文。
extension ReadingFontFamilyOption {
    /// 设置页字体菜单上的一行字。
    var localizedDisplayName: String {
        switch id {
        case ReadingFontFamilyOption.themeDefaultID:
            return BookL10n.string("font.followTheme") // 跟随当前风格预设，不是某个具体字体
        case "songti":
            return BookL10n.string("font.songti")
        case "kaiti":
            return BookL10n.string("font.kaiti")
        case "heiti":
            return BookL10n.string("font.heiti")
        case "pingfang":
            return BookL10n.string("font.pingfang")
        case "system":
            return BookL10n.string("font.systemDefault") // 系统默认 UI 字体
        default:
            return displayName // 用户自装字体，目录里没有译名
        }
    }
}

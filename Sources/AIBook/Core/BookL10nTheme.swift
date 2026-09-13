import Foundation

/// 风格预设的界面文案。只负责把预设 id 映射到目录键，不定义颜色或令牌。
extension BookStylePresetID {
    /// 设置页和菜单上的预设显示名，八种语言走同一套 key。
    var localizedDisplayName: String {
        switch self {
        case .classicStudy: return BookL10n.string("theme.classicStudy") // 书房风菜单名，key 与预设 id 对齐，改名只改目录
        case .plainInk: return BookL10n.string("theme.plainInk") // 素墨风菜单名
        case .nightLamp: return BookL10n.string("theme.nightLamp") // 夜灯风菜单名
        case .bambooScroll: return BookL10n.string("theme.bambooScroll") // 竹简风菜单名
        case .cinnabarHall: return BookL10n.string("theme.cinnabarHall") // 朱砂堂菜单名
        case .plumBlossom: return BookL10n.string("theme.plumBlossom") // 梅花风菜单名
        case .indigoNight: return BookL10n.string("theme.indigoNight") // 靛蓝夜菜单名
        case .modernClean: return BookL10n.string("theme.modernClean") // 现代简洁菜单名
        }
    }

    /// 预设一句话摘要，设置页说明用，不进实际样式计算。
    var localizedSummary: String {
        switch self {
        case .classicStudy: return BookL10n.string("theme.summary.classicStudy") // 书房风摘要，与 displayName 分 key，避免标题和说明抢同一条
        case .plainInk: return BookL10n.string("theme.summary.plainInk") // 素墨风摘要
        case .nightLamp: return BookL10n.string("theme.summary.nightLamp") // 夜灯风摘要
        case .bambooScroll: return BookL10n.string("theme.summary.bambooScroll") // 竹简风摘要
        case .cinnabarHall: return BookL10n.string("theme.summary.cinnabarHall") // 朱砂堂摘要
        case .plumBlossom: return BookL10n.string("theme.summary.plumBlossom") // 梅花风摘要
        case .indigoNight: return BookL10n.string("theme.summary.indigoNight") // 靛蓝夜摘要
        case .modernClean: return BookL10n.string("theme.summary.modernClean") // 现代简洁摘要
        }
    }
}

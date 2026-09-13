import SwiftUI

/// 阅读风格预设 id。显示名和摘要在 BookL10nTheme，这里只保证落盘稳定。
enum BookStylePresetID: String, CaseIterable, Identifiable, Codable {
    case classicStudy
    case plainInk
    case nightLamp
    case bambooScroll
    case cinnabarHall
    case plumBlossom
    case indigoNight
    case modernClean

    var id: String { rawValue } // 和 Codable rawValue 同一套

    /// 设置页标题，转给本地化扩展。
    var displayName: String { localizedDisplayName }

    /// 设置页一句话说明。
    var summary: String { localizedSummary }

    /// 读盘：空值或乱值回退书房风，读者从名字知道有默认。
    static func resolved(from stored: String?) -> BookStylePresetID {
        BookStylePresetID(rawValue: stored ?? "") ?? .classicStudy
    }
}

/// 页眉页脚纹样档位，跟配色预设分开存。
enum BookOrnamentStyle: String, Codable {
    case classic // 传统纹样
    case minimal // 极简线
    case none // 不画纹样
}

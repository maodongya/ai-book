import SwiftUI
import UIKit

/// 在 Mac 令牌基础上略加深 iOS 对比度，不关 Mac 色板。
enum IOSColorContrast {
    /// 正文墨略深，亮底上更清晰。
    static func ink(_ color: Color, darkScheme: Bool) -> Color {
        if darkScheme {
            return adjust(color, brightnessDelta: 0.06, saturationScale: 1.02)
        }
        return adjust(color, brightnessDelta: -0.05, saturationScale: 1.06)
    }

    /// 次要字更深，避免灰蒙蒙。
    static func inkMuted(_ color: Color, darkScheme: Bool) -> Color {
        if darkScheme {
            return adjust(color, brightnessDelta: 0.08, saturationScale: 1.04)
        }
        return adjust(color, brightnessDelta: -0.14, saturationScale: 1.1)
    }

    /// 纸面略压暗，和墨拉开差。
    static func page(_ color: Color, darkScheme: Bool) -> Color {
        if darkScheme {
            return adjust(color, brightnessDelta: -0.03, saturationScale: 1.0)
        }
        return adjust(color, brightnessDelta: -0.035, saturationScale: 1.03)
    }

    /// 顶栏/底栏面板：比纸色稍实，描边更明显。
    static func panel(_ fill: Color, border: Color, darkScheme: Bool) -> Color {
        if darkScheme {
            return adjust(fill, brightnessDelta: 0.04, saturationScale: 1.0)
        }
        return adjust(fill, brightnessDelta: -0.02, saturationScale: 1.02)
    }

    private static func adjust(_ color: Color, brightnessDelta: CGFloat, saturationScale: CGFloat) -> Color {
        let ui = UIColor(color)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        let sat = min(1, max(0, s * saturationScale))
        let bri = min(1, max(0, b + brightnessDelta))
        return Color(hue: Double(h), saturation: Double(sat), brightness: Double(bri), opacity: Double(a))
    }
}
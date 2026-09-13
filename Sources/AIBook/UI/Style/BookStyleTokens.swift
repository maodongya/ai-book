import AppKit
import SwiftUI

/// 一套风格的全部颜色。具体色值在 BookStyleCatalog，这里只描述形状。
struct BookStyleColors {
    var deskTop: Color
    var deskBottom: Color
    var deskLampGlow: Color
    var deskLampGlowOpacity: Double

    var bindingHighlight: Color
    var bindingBase: Color
    var bindingShadow: Color
    var spineLight: Color
    var spineDark: Color

    var chromeText: Color
    var chromeMuted: Color
    var chromeAccent: Color
    var chromeAccentSoft: Color
    var chromeAccentDeep: Color
    var chromeOverlay: Color

    var pageLeft: Color
    var pageRight: Color
    var pageEdge: Color
    var paperTextureOpacity: Double

    var ink: Color
    var inkSecondary: Color
    var inkMuted: Color
    var selection: Color
    var destructive: Color
    var success: Color

    var buttonFill: Color
    var buttonFillHover: Color
    var buttonBorder: Color
    var buttonBorderHover: Color
    var buttonProminentText: Color

    var menuPanelFill: Color
    var menuPanelBorder: Color
    var menuItemFill: Color
    var menuItemFillHover: Color
    var menuItemBorder: Color
    var menuItemBorderHover: Color
    var menuItemText: Color
    var menuDivider: Color
}

/// 标题/正文/阅读正文字号与字体名。空名字走系统字体。
struct BookStyleTypography {
    /// 按顺序尝试的 PostScript 名，都失败则系统字体。
    var preferredFontNames: [String]
    var titleSize: CGFloat
    var labelSize: CGFloat
    var bodySize: CGFloat
    var captionSize: CGFloat
    var readingSize: CGFloat
    var readingLineSpacing: CGFloat

    var titleFont: Font { swiftUIFont(size: titleSize, weight: .semibold) }
    var labelFont: Font { swiftUIFont(size: labelSize, weight: .medium) }
    var bodyFont: Font { swiftUIFont(size: bodySize, weight: .regular) }
    var captionFont: Font { swiftUIFont(size: captionSize, weight: .regular) }

    var readingNSFont: NSFont {
        nsFont(size: readingSize) // TextKit 左页用 NSFont
    }

    var readingFont: Font {
        if let name = preferredFontNames.first {
            return .custom(name, size: readingSize)
        }
        return .system(size: readingSize)
    }

    func nsFont(size: CGFloat) -> NSFont {
        for name in preferredFontNames {
            if let font = NSFont(name: name, size: size) {
                return font // 本机装着这款才用
            }
        }
        return NSFont.systemFont(ofSize: size)
    }

    private func swiftUIFont(size: CGFloat, weight: Font.Weight) -> Font {
        if let name = preferredFontNames.first {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }
}

/// 书签、折角、页眉纹、纸纹开关和颜色。
struct BookStyleOrnaments {
    var showBookmarkRibbon: Bool
    var showPageCornerFold: Bool
    var showHeaderOrnament: Bool
    var showPaperTexture: Bool
    var bookmarkTop: Color
    var bookmarkBottom: Color
    var style: BookOrnamentStyle
}

/// 一套可交给 View 的完整令牌：色 + 字 + 纹样 + 亮暗。
struct BookStyleTokens {
    var colors: BookStyleColors
    var typography: BookStyleTypography
    var ornaments: BookStyleOrnaments
    var preferredColorScheme: ColorScheme

    var deskGradient: LinearGradient {
        LinearGradient(
            colors: [colors.deskTop, colors.deskBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var bindingGradient: LinearGradient {
        LinearGradient(
            colors: [colors.bindingHighlight, colors.bindingBase, colors.bindingShadow],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [colors.chromeAccentSoft, colors.chromeAccent, colors.chromeAccentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var deskLampGlow: RadialGradient {
        RadialGradient(
            colors: [
                colors.deskLampGlow.opacity(colors.deskLampGlowOpacity),
                Color.clear,
            ],
            center: .top,
            startRadius: 40,
            endRadius: 420
        )
    }
}

/// 0–1 RGB 便捷构造，给 Catalog 写色值用。
enum BookStyleRGB {
    static func color(_ red: Double, _ green: Double, _ blue: Double, _ opacity: Double = 1) -> Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

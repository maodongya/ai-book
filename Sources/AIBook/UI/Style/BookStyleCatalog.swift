import SwiftUI

enum BookStyleCatalog {
    static func tokens(
        for preset: BookStylePresetID,
        ornamentOverrides: BookStyleOrnamentOverrides = .empty,
        readingFontSizeOverride: Double? = nil
    ) -> BookStyleTokens {
        var tokens = baseTokens(for: preset)
        if let showBookmark = ornamentOverrides.showBookmarkRibbon {
            tokens.ornaments.showBookmarkRibbon = showBookmark
        }
        if let showFold = ornamentOverrides.showPageCornerFold {
            tokens.ornaments.showPageCornerFold = showFold
        }
        if let showHeader = ornamentOverrides.showHeaderOrnament {
            tokens.ornaments.showHeaderOrnament = showHeader
        }
        if let showTexture = ornamentOverrides.showPaperTexture {
            tokens.ornaments.showPaperTexture = showTexture
        }
        if let size = readingFontSizeOverride, size > 0 {
            tokens.typography.readingSize = size
        }
        return tokens
    }

    static func baseTokens(for preset: BookStylePresetID) -> BookStyleTokens {
        switch preset {
        case .classicStudy: return classicStudy
        case .plainInk: return plainInk
        case .nightLamp: return nightLamp
        case .bambooScroll: return bambooScroll
        case .modernClean: return modernClean
        }
    }

    static let songtiNames = ["Songti SC", "STSong", "Georgia"]
    static let readingSizes: [Double] = [15, 16, 17, 18, 19]

    private static let classicStudy = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.18, 0.13, 0.09),
            deskBottom: BookStyleRGB.color(0.08, 0.055, 0.04),
            deskLampGlow: BookStyleRGB.color(0.42, 0.32, 0.18),
            deskLampGlowOpacity: 0.35,
            bindingHighlight: BookStyleRGB.color(0.54, 0.34, 0.20),
            bindingBase: BookStyleRGB.color(0.38, 0.23, 0.15),
            bindingShadow: BookStyleRGB.color(0.18, 0.10, 0.065),
            spineLight: BookStyleRGB.color(0.72, 0.62, 0.48),
            spineDark: BookStyleRGB.color(0.48, 0.38, 0.26),
            chromeText: BookStyleRGB.color(0.99, 0.93, 0.74),
            chromeMuted: Color.white.opacity(0.78),
            chromeAccent: BookStyleRGB.color(0.82, 0.64, 0.30),
            chromeAccentSoft: BookStyleRGB.color(0.95, 0.86, 0.64),
            chromeAccentDeep: BookStyleRGB.color(0.68, 0.48, 0.20),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.99, 0.96, 0.89),
            pageRight: BookStyleRGB.color(0.97, 0.94, 0.87),
            pageEdge: BookStyleRGB.color(0.86, 0.78, 0.66),
            paperTextureOpacity: 0.018,
            ink: BookStyleRGB.color(0.18, 0.14, 0.10),
            inkSecondary: BookStyleRGB.color(0.40, 0.34, 0.26),
            inkMuted: BookStyleRGB.color(0.55, 0.48, 0.38),
            selection: BookStyleRGB.color(0.95, 0.86, 0.55),
            destructive: BookStyleRGB.color(0.64, 0.16, 0.12),
            success: BookStyleRGB.color(0.24, 0.43, 0.34),
            buttonFill: Color.white.opacity(0.18),
            buttonFillHover: Color.white.opacity(0.28),
            buttonBorder: Color.white.opacity(0.34),
            buttonBorderHover: Color.white.opacity(0.50),
            buttonProminentText: BookStyleRGB.color(0.18, 0.10, 0.065),
            menuPanelFill: BookStyleRGB.color(0.995, 0.97, 0.91),
            menuPanelBorder: BookStyleRGB.color(0.72, 0.58, 0.40),
            menuItemFill: BookStyleRGB.color(1.0, 0.99, 0.95),
            menuItemFillHover: BookStyleRGB.color(0.96, 0.88, 0.68),
            menuItemBorder: BookStyleRGB.color(0.78, 0.66, 0.48),
            menuItemBorderHover: BookStyleRGB.color(0.68, 0.50, 0.28),
            menuItemText: BookStyleRGB.color(0.18, 0.14, 0.10),
            menuDivider: BookStyleRGB.color(0.78, 0.66, 0.48)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: true,
            showPageCornerFold: true,
            showHeaderOrnament: true,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.82, 0.18, 0.14),
            bookmarkBottom: BookStyleRGB.color(0.45, 0.08, 0.06),
            style: .classic
        ),
        preferredColorScheme: .light
    )

    private static let plainInk = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.961, 0.953, 0.937),
            deskBottom: BookStyleRGB.color(0.918, 0.902, 0.871),
            deskLampGlow: .clear,
            deskLampGlowOpacity: 0,
            bindingHighlight: BookStyleRGB.color(0.97, 0.96, 0.94),
            bindingBase: BookStyleRGB.color(0.91, 0.89, 0.85),
            bindingShadow: BookStyleRGB.color(0.82, 0.79, 0.74),
            spineLight: BookStyleRGB.color(0.80, 0.78, 0.74),
            spineDark: BookStyleRGB.color(0.62, 0.59, 0.54),
            chromeText: BookStyleRGB.color(0.173, 0.173, 0.173),
            chromeMuted: BookStyleRGB.color(0.40, 0.40, 0.40),
            chromeAccent: BookStyleRGB.color(0.22, 0.22, 0.22),
            chromeAccentSoft: BookStyleRGB.color(0.40, 0.40, 0.40),
            chromeAccentDeep: BookStyleRGB.color(0.12, 0.12, 0.12),
            chromeOverlay: .black,
            pageLeft: Color.white,
            pageRight: BookStyleRGB.color(0.98, 0.98, 0.97),
            pageEdge: BookStyleRGB.color(0.82, 0.80, 0.76),
            paperTextureOpacity: 0,
            ink: BookStyleRGB.color(0.173, 0.173, 0.173),
            inkSecondary: BookStyleRGB.color(0.38, 0.38, 0.38),
            inkMuted: BookStyleRGB.color(0.52, 0.52, 0.52),
            selection: BookStyleRGB.color(0.90, 0.90, 0.86),
            destructive: BookStyleRGB.color(0.64, 0.16, 0.12),
            success: BookStyleRGB.color(0.24, 0.43, 0.34),
            buttonFill: Color.black.opacity(0.08),
            buttonFillHover: Color.black.opacity(0.14),
            buttonBorder: Color.black.opacity(0.24),
            buttonBorderHover: Color.black.opacity(0.38),
            buttonProminentText: Color.white,
            menuPanelFill: Color.white,
            menuPanelBorder: BookStyleRGB.color(0.62, 0.60, 0.56),
            menuItemFill: BookStyleRGB.color(0.97, 0.96, 0.94),
            menuItemFillHover: BookStyleRGB.color(0.91, 0.90, 0.86),
            menuItemBorder: BookStyleRGB.color(0.62, 0.60, 0.56),
            menuItemBorderHover: BookStyleRGB.color(0.28, 0.28, 0.28),
            menuItemText: BookStyleRGB.color(0.12, 0.12, 0.12),
            menuDivider: BookStyleRGB.color(0.72, 0.70, 0.66)
        ),
        typography: BookStyleTypography(
            preferredFontNames: ["STSong", "Songti SC", "Georgia"],
            titleSize: 22,
            labelSize: 13,
            bodySize: 16,
            captionSize: 12,
            readingSize: 17,
            readingLineSpacing: 9
        ),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: false,
            showHeaderOrnament: false,
            showPaperTexture: false,
            bookmarkTop: BookStyleRGB.color(0.35, 0.35, 0.35),
            bookmarkBottom: BookStyleRGB.color(0.18, 0.18, 0.18),
            style: .none
        ),
        preferredColorScheme: .light
    )

    private static let nightLamp = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.102, 0.086, 0.071),
            deskBottom: BookStyleRGB.color(0.06, 0.05, 0.04),
            deskLampGlow: BookStyleRGB.color(0.55, 0.38, 0.16),
            deskLampGlowOpacity: 0.28,
            bindingHighlight: BookStyleRGB.color(0.28, 0.20, 0.14),
            bindingBase: BookStyleRGB.color(0.16, 0.12, 0.09),
            bindingShadow: BookStyleRGB.color(0.08, 0.06, 0.04),
            spineLight: BookStyleRGB.color(0.42, 0.32, 0.22),
            spineDark: BookStyleRGB.color(0.22, 0.16, 0.11),
            chromeText: BookStyleRGB.color(0.98, 0.91, 0.72),
            chromeMuted: Color.white.opacity(0.72),
            chromeAccent: BookStyleRGB.color(0.831, 0.627, 0.329),
            chromeAccentSoft: BookStyleRGB.color(0.95, 0.86, 0.64),
            chromeAccentDeep: BookStyleRGB.color(0.62, 0.42, 0.18),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.165, 0.145, 0.125),
            pageRight: BookStyleRGB.color(0.180, 0.161, 0.141),
            pageEdge: BookStyleRGB.color(0.32, 0.26, 0.20),
            paperTextureOpacity: 0.04,
            ink: BookStyleRGB.color(0.910, 0.878, 0.831),
            inkSecondary: BookStyleRGB.color(0.78, 0.72, 0.64),
            inkMuted: BookStyleRGB.color(0.62, 0.56, 0.48),
            selection: BookStyleRGB.color(0.831, 0.627, 0.329, 0.35),
            destructive: BookStyleRGB.color(0.86, 0.42, 0.34),
            success: BookStyleRGB.color(0.45, 0.68, 0.52),
            buttonFill: Color.white.opacity(0.14),
            buttonFillHover: Color.white.opacity(0.24),
            buttonBorder: Color.white.opacity(0.32),
            buttonBorderHover: Color.white.opacity(0.48),
            buttonProminentText: BookStyleRGB.color(0.12, 0.08, 0.05),
            menuPanelFill: BookStyleRGB.color(0.22, 0.18, 0.14),
            menuPanelBorder: BookStyleRGB.color(0.55, 0.42, 0.26),
            menuItemFill: BookStyleRGB.color(0.30, 0.24, 0.18),
            menuItemFillHover: BookStyleRGB.color(0.42, 0.32, 0.20),
            menuItemBorder: BookStyleRGB.color(0.55, 0.42, 0.26),
            menuItemBorderHover: BookStyleRGB.color(0.83, 0.63, 0.33),
            menuItemText: BookStyleRGB.color(0.96, 0.91, 0.82),
            menuDivider: BookStyleRGB.color(0.48, 0.38, 0.26)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: false,
            showHeaderOrnament: false,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.831, 0.627, 0.329),
            bookmarkBottom: BookStyleRGB.color(0.45, 0.28, 0.10),
            style: .minimal
        ),
        preferredColorScheme: .dark
    )

    private static let bambooScroll = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.910, 0.929, 0.910),
            deskBottom: BookStyleRGB.color(0.839, 0.867, 0.839),
            deskLampGlow: BookStyleRGB.color(0.55, 0.65, 0.50),
            deskLampGlowOpacity: 0.12,
            bindingHighlight: BookStyleRGB.color(0.32, 0.48, 0.38),
            bindingBase: BookStyleRGB.color(0.239, 0.361, 0.282),
            bindingShadow: BookStyleRGB.color(0.14, 0.22, 0.16),
            spineLight: BookStyleRGB.color(0.62, 0.72, 0.58),
            spineDark: BookStyleRGB.color(0.32, 0.42, 0.30),
            chromeText: BookStyleRGB.color(0.97, 0.95, 0.86),
            chromeMuted: Color.white.opacity(0.68),
            chromeAccent: BookStyleRGB.color(0.82, 0.72, 0.42),
            chromeAccentSoft: BookStyleRGB.color(0.92, 0.86, 0.62),
            chromeAccentDeep: BookStyleRGB.color(0.58, 0.48, 0.22),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.98, 0.99, 0.97),
            pageRight: BookStyleRGB.color(0.95, 0.97, 0.94),
            pageEdge: BookStyleRGB.color(0.72, 0.78, 0.70),
            paperTextureOpacity: 0.012,
            ink: BookStyleRGB.color(0.12, 0.18, 0.14),
            inkSecondary: BookStyleRGB.color(0.28, 0.36, 0.30),
            inkMuted: BookStyleRGB.color(0.45, 0.52, 0.46),
            selection: BookStyleRGB.color(0.82, 0.90, 0.78),
            destructive: BookStyleRGB.color(0.64, 0.22, 0.16),
            success: BookStyleRGB.color(0.24, 0.43, 0.34),
            buttonFill: Color.white.opacity(0.16),
            buttonFillHover: Color.white.opacity(0.26),
            buttonBorder: Color.white.opacity(0.32),
            buttonBorderHover: Color.white.opacity(0.48),
            buttonProminentText: BookStyleRGB.color(0.12, 0.18, 0.14),
            menuPanelFill: BookStyleRGB.color(0.98, 0.99, 0.96),
            menuPanelBorder: BookStyleRGB.color(0.42, 0.54, 0.44),
            menuItemFill: Color.white,
            menuItemFillHover: BookStyleRGB.color(0.88, 0.94, 0.88),
            menuItemBorder: BookStyleRGB.color(0.52, 0.64, 0.54),
            menuItemBorderHover: BookStyleRGB.color(0.24, 0.36, 0.28),
            menuItemText: BookStyleRGB.color(0.10, 0.16, 0.12),
            menuDivider: BookStyleRGB.color(0.62, 0.72, 0.62)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: true,
            showHeaderOrnament: true,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.32, 0.48, 0.38),
            bookmarkBottom: BookStyleRGB.color(0.14, 0.22, 0.16),
            style: .minimal
        ),
        preferredColorScheme: .light
    )

    private static let modernClean = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.94, 0.94, 0.94),
            deskBottom: BookStyleRGB.color(0.90, 0.90, 0.90),
            deskLampGlow: .clear,
            deskLampGlowOpacity: 0,
            bindingHighlight: Color.white,
            bindingBase: BookStyleRGB.color(0.97, 0.97, 0.97),
            bindingShadow: BookStyleRGB.color(0.88, 0.88, 0.88),
            spineLight: BookStyleRGB.color(0.82, 0.82, 0.82),
            spineDark: BookStyleRGB.color(0.62, 0.62, 0.62),
            chromeText: BookStyleRGB.color(0.10, 0.10, 0.10),
            chromeMuted: BookStyleRGB.color(0.32, 0.32, 0.32),
            chromeAccent: BookStyleRGB.color(0.0, 0.478, 1.0),
            chromeAccentSoft: BookStyleRGB.color(0.35, 0.64, 1.0),
            chromeAccentDeep: BookStyleRGB.color(0.0, 0.35, 0.78),
            chromeOverlay: .black,
            pageLeft: Color.white,
            pageRight: Color.white,
            pageEdge: BookStyleRGB.color(0.82, 0.82, 0.82),
            paperTextureOpacity: 0,
            ink: BookStyleRGB.color(0.12, 0.12, 0.12),
            inkSecondary: BookStyleRGB.color(0.35, 0.35, 0.35),
            inkMuted: BookStyleRGB.color(0.52, 0.52, 0.52),
            selection: BookStyleRGB.color(0.80, 0.90, 1.0),
            destructive: BookStyleRGB.color(0.90, 0.22, 0.21),
            success: BookStyleRGB.color(0.20, 0.56, 0.35),
            buttonFill: Color.white,
            buttonFillHover: BookStyleRGB.color(0.92, 0.95, 1.0),
            buttonBorder: Color.black.opacity(0.22),
            buttonBorderHover: BookStyleRGB.color(0.0, 0.40, 0.90),
            buttonProminentText: Color.white,
            menuPanelFill: Color.white,
            menuPanelBorder: BookStyleRGB.color(0.55, 0.55, 0.55),
            menuItemFill: BookStyleRGB.color(0.97, 0.97, 0.97),
            menuItemFillHover: BookStyleRGB.color(0.88, 0.93, 1.0),
            menuItemBorder: BookStyleRGB.color(0.62, 0.62, 0.62),
            menuItemBorderHover: BookStyleRGB.color(0.0, 0.40, 0.90),
            menuItemText: BookStyleRGB.color(0.08, 0.08, 0.08),
            menuDivider: BookStyleRGB.color(0.78, 0.78, 0.78)
        ),
        typography: BookStyleTypography(
            preferredFontNames: [],
            titleSize: 20,
            labelSize: 13,
            bodySize: 16,
            captionSize: 12,
            readingSize: 16,
            readingLineSpacing: 6
        ),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: false,
            showHeaderOrnament: false,
            showPaperTexture: false,
            bookmarkTop: BookStyleRGB.color(0.0, 0.478, 1.0),
            bookmarkBottom: BookStyleRGB.color(0.0, 0.35, 0.78),
            style: .none
        ),
        preferredColorScheme: .light
    )

    private static func songtiTypography() -> BookStyleTypography {
        BookStyleTypography(
            preferredFontNames: songtiNames,
            titleSize: 22,
            labelSize: 13,
            bodySize: 16,
            captionSize: 12,
            readingSize: 17,
            readingLineSpacing: 9
        )
    }
}

struct BookStyleOrnamentOverrides: Equatable {
    var showBookmarkRibbon: Bool?
    var showPageCornerFold: Bool?
    var showHeaderOrnament: Bool?
    var showPaperTexture: Bool?

    static let empty = BookStyleOrnamentOverrides()
}

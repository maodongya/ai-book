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
        case .cinnabarHall: return cinnabarHall
        case .plumBlossom: return plumBlossom
        case .indigoNight: return indigoNight
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
            chromeText: BookStyleRGB.color(0.96, 0.90, 0.84),
            chromeMuted: Color.white.opacity(0.72),
            chromeAccent: BookStyleRGB.color(0.78, 0.42, 0.32),
            chromeAccentSoft: BookStyleRGB.color(0.88, 0.58, 0.48),
            chromeAccentDeep: BookStyleRGB.color(0.55, 0.26, 0.18),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.165, 0.145, 0.125),
            pageRight: BookStyleRGB.color(0.180, 0.161, 0.141),
            pageEdge: BookStyleRGB.color(0.32, 0.26, 0.20),
            paperTextureOpacity: 0.04,
            ink: BookStyleRGB.color(0.910, 0.878, 0.831),
            inkSecondary: BookStyleRGB.color(0.78, 0.72, 0.64),
            inkMuted: BookStyleRGB.color(0.62, 0.56, 0.48),
            selection: BookStyleRGB.color(0.78, 0.42, 0.32, 0.35),
            destructive: BookStyleRGB.color(0.86, 0.42, 0.34),
            success: BookStyleRGB.color(0.45, 0.68, 0.52),
            buttonFill: Color.white.opacity(0.14),
            buttonFillHover: Color.white.opacity(0.24),
            buttonBorder: Color.white.opacity(0.32),
            buttonBorderHover: Color.white.opacity(0.48),
            buttonProminentText: BookStyleRGB.color(0.98, 0.94, 0.90),
            menuPanelFill: BookStyleRGB.color(0.22, 0.18, 0.14),
            menuPanelBorder: BookStyleRGB.color(0.62, 0.38, 0.30),
            menuItemFill: BookStyleRGB.color(0.30, 0.24, 0.18),
            menuItemFillHover: BookStyleRGB.color(0.48, 0.30, 0.24),
            menuItemBorder: BookStyleRGB.color(0.62, 0.38, 0.30),
            menuItemBorderHover: BookStyleRGB.color(0.88, 0.58, 0.48),
            menuItemText: BookStyleRGB.color(0.96, 0.91, 0.82),
            menuDivider: BookStyleRGB.color(0.48, 0.38, 0.26)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: false,
            showHeaderOrnament: false,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.78, 0.42, 0.32),
            bookmarkBottom: BookStyleRGB.color(0.45, 0.20, 0.14),
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
            chromeAccent: BookStyleRGB.color(0.28, 0.48, 0.36),
            chromeAccentSoft: BookStyleRGB.color(0.48, 0.68, 0.52),
            chromeAccentDeep: BookStyleRGB.color(0.16, 0.32, 0.24),
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
            buttonProminentText: BookStyleRGB.color(0.97, 0.99, 0.96),
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

    private static let cinnabarHall = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.22, 0.08, 0.08),
            deskBottom: BookStyleRGB.color(0.10, 0.04, 0.04),
            deskLampGlow: BookStyleRGB.color(0.62, 0.22, 0.16),
            deskLampGlowOpacity: 0.22,
            bindingHighlight: BookStyleRGB.color(0.72, 0.28, 0.22),
            bindingBase: BookStyleRGB.color(0.58, 0.16, 0.14),
            bindingShadow: BookStyleRGB.color(0.28, 0.08, 0.07),
            spineLight: BookStyleRGB.color(0.78, 0.42, 0.36),
            spineDark: BookStyleRGB.color(0.42, 0.12, 0.10),
            chromeText: BookStyleRGB.color(0.99, 0.94, 0.90),
            chromeMuted: Color.white.opacity(0.78),
            chromeAccent: BookStyleRGB.color(0.76, 0.22, 0.16),
            chromeAccentSoft: BookStyleRGB.color(0.88, 0.40, 0.32),
            chromeAccentDeep: BookStyleRGB.color(0.52, 0.12, 0.10),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.995, 0.96, 0.92),
            pageRight: BookStyleRGB.color(0.97, 0.93, 0.88),
            pageEdge: BookStyleRGB.color(0.86, 0.72, 0.66),
            paperTextureOpacity: 0.016,
            ink: BookStyleRGB.color(0.20, 0.10, 0.09),
            inkSecondary: BookStyleRGB.color(0.42, 0.26, 0.22),
            inkMuted: BookStyleRGB.color(0.58, 0.42, 0.38),
            selection: BookStyleRGB.color(0.96, 0.78, 0.74),
            destructive: BookStyleRGB.color(0.64, 0.12, 0.10),
            success: BookStyleRGB.color(0.24, 0.43, 0.34),
            buttonFill: Color.white.opacity(0.16),
            buttonFillHover: Color.white.opacity(0.26),
            buttonBorder: Color.white.opacity(0.34),
            buttonBorderHover: Color.white.opacity(0.50),
            buttonProminentText: BookStyleRGB.color(0.99, 0.95, 0.92),
            menuPanelFill: BookStyleRGB.color(0.995, 0.97, 0.94),
            menuPanelBorder: BookStyleRGB.color(0.72, 0.40, 0.34),
            menuItemFill: BookStyleRGB.color(1.0, 0.99, 0.97),
            menuItemFillHover: BookStyleRGB.color(0.97, 0.86, 0.82),
            menuItemBorder: BookStyleRGB.color(0.80, 0.58, 0.52),
            menuItemBorderHover: BookStyleRGB.color(0.64, 0.22, 0.16),
            menuItemText: BookStyleRGB.color(0.20, 0.10, 0.09),
            menuDivider: BookStyleRGB.color(0.82, 0.64, 0.58)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: true,
            showPageCornerFold: true,
            showHeaderOrnament: true,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.76, 0.22, 0.16),
            bookmarkBottom: BookStyleRGB.color(0.42, 0.10, 0.08),
            style: .classic
        ),
        preferredColorScheme: .light
    )

    private static let plumBlossom = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.94, 0.88, 0.90),
            deskBottom: BookStyleRGB.color(0.88, 0.80, 0.84),
            deskLampGlow: BookStyleRGB.color(0.72, 0.48, 0.58),
            deskLampGlowOpacity: 0.12,
            bindingHighlight: BookStyleRGB.color(0.62, 0.34, 0.44),
            bindingBase: BookStyleRGB.color(0.48, 0.22, 0.34),
            bindingShadow: BookStyleRGB.color(0.28, 0.12, 0.20),
            spineLight: BookStyleRGB.color(0.78, 0.52, 0.62),
            spineDark: BookStyleRGB.color(0.38, 0.16, 0.26),
            chromeText: BookStyleRGB.color(0.99, 0.95, 0.96),
            chromeMuted: Color.white.opacity(0.78),
            chromeAccent: BookStyleRGB.color(0.58, 0.22, 0.38),
            chromeAccentSoft: BookStyleRGB.color(0.76, 0.42, 0.56),
            chromeAccentDeep: BookStyleRGB.color(0.40, 0.12, 0.26),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.995, 0.97, 0.97),
            pageRight: BookStyleRGB.color(0.97, 0.93, 0.94),
            pageEdge: BookStyleRGB.color(0.84, 0.72, 0.76),
            paperTextureOpacity: 0.012,
            ink: BookStyleRGB.color(0.22, 0.10, 0.16),
            inkSecondary: BookStyleRGB.color(0.42, 0.26, 0.32),
            inkMuted: BookStyleRGB.color(0.58, 0.44, 0.48),
            selection: BookStyleRGB.color(0.94, 0.82, 0.88),
            destructive: BookStyleRGB.color(0.64, 0.16, 0.22),
            success: BookStyleRGB.color(0.24, 0.43, 0.34),
            buttonFill: Color.white.opacity(0.18),
            buttonFillHover: Color.white.opacity(0.28),
            buttonBorder: Color.white.opacity(0.36),
            buttonBorderHover: Color.white.opacity(0.52),
            buttonProminentText: BookStyleRGB.color(0.99, 0.96, 0.97),
            menuPanelFill: BookStyleRGB.color(0.995, 0.97, 0.97),
            menuPanelBorder: BookStyleRGB.color(0.70, 0.42, 0.52),
            menuItemFill: Color.white,
            menuItemFillHover: BookStyleRGB.color(0.96, 0.88, 0.92),
            menuItemBorder: BookStyleRGB.color(0.78, 0.58, 0.66),
            menuItemBorderHover: BookStyleRGB.color(0.48, 0.18, 0.32),
            menuItemText: BookStyleRGB.color(0.20, 0.10, 0.16),
            menuDivider: BookStyleRGB.color(0.84, 0.70, 0.74)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: true,
            showPageCornerFold: true,
            showHeaderOrnament: false,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.76, 0.42, 0.56),
            bookmarkBottom: BookStyleRGB.color(0.40, 0.12, 0.26),
            style: .minimal
        ),
        preferredColorScheme: .light
    )

    private static let indigoNight = BookStyleTokens(
        colors: BookStyleColors(
            deskTop: BookStyleRGB.color(0.07, 0.09, 0.16),
            deskBottom: BookStyleRGB.color(0.04, 0.05, 0.10),
            deskLampGlow: BookStyleRGB.color(0.32, 0.42, 0.68),
            deskLampGlowOpacity: 0.22,
            bindingHighlight: BookStyleRGB.color(0.22, 0.28, 0.46),
            bindingBase: BookStyleRGB.color(0.12, 0.16, 0.30),
            bindingShadow: BookStyleRGB.color(0.06, 0.08, 0.14),
            spineLight: BookStyleRGB.color(0.36, 0.44, 0.64),
            spineDark: BookStyleRGB.color(0.14, 0.18, 0.32),
            chromeText: BookStyleRGB.color(0.90, 0.93, 0.98),
            chromeMuted: Color.white.opacity(0.72),
            chromeAccent: BookStyleRGB.color(0.42, 0.58, 0.86),
            chromeAccentSoft: BookStyleRGB.color(0.62, 0.74, 0.94),
            chromeAccentDeep: BookStyleRGB.color(0.22, 0.36, 0.64),
            chromeOverlay: .white,
            pageLeft: BookStyleRGB.color(0.12, 0.14, 0.22),
            pageRight: BookStyleRGB.color(0.14, 0.16, 0.24),
            pageEdge: BookStyleRGB.color(0.28, 0.32, 0.44),
            paperTextureOpacity: 0.03,
            ink: BookStyleRGB.color(0.90, 0.92, 0.97),
            inkSecondary: BookStyleRGB.color(0.70, 0.74, 0.84),
            inkMuted: BookStyleRGB.color(0.54, 0.58, 0.70),
            selection: BookStyleRGB.color(0.42, 0.58, 0.86, 0.35),
            destructive: BookStyleRGB.color(0.90, 0.46, 0.50),
            success: BookStyleRGB.color(0.42, 0.72, 0.62),
            buttonFill: Color.white.opacity(0.12),
            buttonFillHover: Color.white.opacity(0.22),
            buttonBorder: Color.white.opacity(0.30),
            buttonBorderHover: Color.white.opacity(0.48),
            buttonProminentText: BookStyleRGB.color(0.08, 0.10, 0.18),
            menuPanelFill: BookStyleRGB.color(0.16, 0.18, 0.28),
            menuPanelBorder: BookStyleRGB.color(0.42, 0.50, 0.70),
            menuItemFill: BookStyleRGB.color(0.22, 0.26, 0.38),
            menuItemFillHover: BookStyleRGB.color(0.30, 0.38, 0.56),
            menuItemBorder: BookStyleRGB.color(0.42, 0.50, 0.70),
            menuItemBorderHover: BookStyleRGB.color(0.62, 0.74, 0.94),
            menuItemText: BookStyleRGB.color(0.92, 0.94, 0.98),
            menuDivider: BookStyleRGB.color(0.36, 0.40, 0.54)
        ),
        typography: songtiTypography(),
        ornaments: BookStyleOrnaments(
            showBookmarkRibbon: false,
            showPageCornerFold: false,
            showHeaderOrnament: true,
            showPaperTexture: true,
            bookmarkTop: BookStyleRGB.color(0.62, 0.74, 0.94),
            bookmarkBottom: BookStyleRGB.color(0.22, 0.36, 0.64),
            style: .minimal
        ),
        preferredColorScheme: .dark
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

import Foundation

extension ReadingFontFamilyOption {
    var localizedDisplayName: String {
        switch id {
        case ReadingFontFamilyOption.themeDefaultID:
            return BookL10n.string("font.followTheme")
        case "songti":
            return BookL10n.string("font.songti")
        case "kaiti":
            return BookL10n.string("font.kaiti")
        case "heiti":
            return BookL10n.string("font.heiti")
        case "pingfang":
            return BookL10n.string("font.pingfang")
        case "system":
            return BookL10n.string("font.systemDefault")
        default:
            return displayName
        }
    }
}

import Foundation

extension BookStylePresetID {
    var localizedDisplayName: String {
        switch self {
        case .classicStudy: return BookL10n.string("theme.classicStudy")
        case .plainInk: return BookL10n.string("theme.plainInk")
        case .nightLamp: return BookL10n.string("theme.nightLamp")
        case .bambooScroll: return BookL10n.string("theme.bambooScroll")
        case .cinnabarHall: return BookL10n.string("theme.cinnabarHall")
        case .plumBlossom: return BookL10n.string("theme.plumBlossom")
        case .indigoNight: return BookL10n.string("theme.indigoNight")
        case .modernClean: return BookL10n.string("theme.modernClean")
        }
    }

    var localizedSummary: String {
        switch self {
        case .classicStudy: return BookL10n.string("theme.summary.classicStudy")
        case .plainInk: return BookL10n.string("theme.summary.plainInk")
        case .nightLamp: return BookL10n.string("theme.summary.nightLamp")
        case .bambooScroll: return BookL10n.string("theme.summary.bambooScroll")
        case .cinnabarHall: return BookL10n.string("theme.summary.cinnabarHall")
        case .plumBlossom: return BookL10n.string("theme.summary.plumBlossom")
        case .indigoNight: return BookL10n.string("theme.summary.indigoNight")
        case .modernClean: return BookL10n.string("theme.summary.modernClean")
        }
    }
}

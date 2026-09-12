import SwiftUI

enum BookStylePresetID: String, CaseIterable, Identifiable, Codable {
    case classicStudy
    case plainInk
    case nightLamp
    case bambooScroll
    case cinnabarHall
    case plumBlossom
    case indigoNight
    case modernClean

    var id: String { rawValue }

    var displayName: String { localizedDisplayName }

    var summary: String { localizedSummary }

    static func resolved(from stored: String?) -> BookStylePresetID {
        BookStylePresetID(rawValue: stored ?? "") ?? .classicStudy
    }
}

enum BookOrnamentStyle: String, Codable {
    case classic
    case minimal
    case none
}

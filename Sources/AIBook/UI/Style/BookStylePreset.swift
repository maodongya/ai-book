import SwiftUI

enum BookStylePresetID: String, CaseIterable, Identifiable, Codable {
    case classicStudy
    case plainInk
    case nightLamp
    case bambooScroll
    case modernClean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classicStudy: return "古典书房"
        case .plainInk: return "素笺墨香"
        case .nightLamp: return "深夜灯盏"
        case .bambooScroll: return "青简竹简"
        case .modernClean: return "现代简约"
        }
    }

    var summary: String {
        switch self {
        case .classicStudy: return "暖色台灯下的皮革精装书，默认风格"
        case .plainInk: return "素色信纸上的墨迹，弱化装帧、突出正文"
        case .nightLamp: return "暗室暖灯阅读，适合夜间长时间看书"
        case .bambooScroll: return "竹青与绢帛点缀，偏文艺清新"
        case .modernClean: return "扁平双栏阅读器，信息密度更高"
        }
    }

    static func resolved(from stored: String?) -> BookStylePresetID {
        BookStylePresetID(rawValue: stored ?? "") ?? .classicStudy
    }
}

enum BookOrnamentStyle: String, Codable {
    case classic
    case minimal
    case none
}

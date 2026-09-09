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

    var displayName: String {
        switch self {
        case .classicStudy: return "古典书房"
        case .plainInk: return "素笺墨香"
        case .nightLamp: return "深夜灯盏"
        case .bambooScroll: return "青简竹简"
        case .cinnabarHall: return "朱砂厅堂"
        case .plumBlossom: return "梅笺春讯"
        case .indigoNight: return "靛蓝夜读"
        case .modernClean: return "现代简约"
        }
    }

    var summary: String {
        switch self {
        case .classicStudy: return "暖色台灯下的皮革精装书，金色按钮为这一套独有"
        case .plainInk: return "素色信纸上的墨迹，弱化装帧、突出正文"
        case .nightLamp: return "暗室暖灯阅读，陶土色按钮，适合夜间长时间看书"
        case .bambooScroll: return "竹青与绢帛点缀，按钮用竹青而非金色"
        case .cinnabarHall: return "朱红装帧与牙白皮页，强调色为朱砂"
        case .plumBlossom: return "浅粉梅笺，绛紫按钮，偏春日笺纸"
        case .indigoNight: return "深蓝夜读，石青冷光按钮，无金色"
        case .modernClean: return "扁平双栏阅读器，系统蓝强调"
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

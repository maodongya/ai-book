import SwiftUI

@MainActor
final class BookStyleManager: ObservableObject {
    static let shared = BookStyleManager()

    @Published var presetID: BookStylePresetID {
        didSet {
            UserDefaults.standard.set(presetID.rawValue, forKey: Keys.presetID)
        }
    }

    @Published var ornamentOverrides: BookStyleOrnamentOverrides {
        didSet { persistOrnamentOverrides() }
    }

    @Published var readingFontSizeOverride: Double? {
        didSet {
            if let readingFontSizeOverride {
                UserDefaults.standard.set(readingFontSizeOverride, forKey: Keys.readingFontSize)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.readingFontSize)
            }
        }
    }

    var tokens: BookStyleTokens {
        BookStyleCatalog.tokens(
            for: presetID,
            ornamentOverrides: ornamentOverrides,
            readingFontSizeOverride: readingFontSizeOverride
        )
    }

    var colorScheme: ColorScheme {
        tokens.preferredColorScheme
    }

    var revision: String {
        let bookmark = Self.flagToken(ornamentOverrides.showBookmarkRibbon)
        let fold = Self.flagToken(ornamentOverrides.showPageCornerFold)
        let header = Self.flagToken(ornamentOverrides.showHeaderOrnament)
        let texture = Self.flagToken(ornamentOverrides.showPaperTexture)
        let fontSize = readingFontSizeOverride.map { String($0) } ?? "-"
        return "\(presetID.rawValue)/\(bookmark)/\(fold)/\(header)/\(texture)/\(fontSize)"
    }

    private static func flagToken(_ value: Bool?) -> String {
        guard let value else { return "-" }
        return value ? "1" : "0"
    }

    private enum Keys {
        static let presetID = "aiBook.style.presetID"
        static let bookmark = "aiBook.style.ornament.bookmark"
        static let cornerFold = "aiBook.style.ornament.cornerFold"
        static let paperTexture = "aiBook.style.ornament.paperTexture"
        static let headerOrnament = "aiBook.style.ornament.headerOrnament"
        static let readingFontSize = "aiBook.style.readingFontSize"
    }

    private init() {
        presetID = BookStylePresetID.resolved(from: UserDefaults.standard.string(forKey: Keys.presetID))
        ornamentOverrides = BookStyleOrnamentOverrides(
            showBookmarkRibbon: UserDefaults.standard.optionalBool(forKey: Keys.bookmark),
            showPageCornerFold: UserDefaults.standard.optionalBool(forKey: Keys.cornerFold),
            showHeaderOrnament: UserDefaults.standard.optionalBool(forKey: Keys.headerOrnament),
            showPaperTexture: UserDefaults.standard.optionalBool(forKey: Keys.paperTexture)
        )
        let storedSize = UserDefaults.standard.object(forKey: Keys.readingFontSize) as? Double
        if let storedSize, BookStyleCatalog.readingSizes.contains(storedSize) {
            readingFontSizeOverride = storedSize
        } else {
            readingFontSizeOverride = nil
        }
    }

    func selectPreset(_ preset: BookStylePresetID) {
        presetID = preset
    }

    func setShowBookmarkRibbon(_ value: Bool) {
        var next = ornamentOverrides
        next.showBookmarkRibbon = value
        ornamentOverrides = next
    }

    func setShowPageCornerFold(_ value: Bool) {
        var next = ornamentOverrides
        next.showPageCornerFold = value
        ornamentOverrides = next
    }

    func setShowPaperTexture(_ value: Bool) {
        var next = ornamentOverrides
        next.showPaperTexture = value
        ornamentOverrides = next
    }

    func setShowHeaderOrnament(_ value: Bool) {
        var next = ornamentOverrides
        next.showHeaderOrnament = value
        ornamentOverrides = next
    }

    private func persistOrnamentOverrides() {
        UserDefaults.standard.setOptionalBool(ornamentOverrides.showBookmarkRibbon, forKey: Keys.bookmark)
        UserDefaults.standard.setOptionalBool(ornamentOverrides.showPageCornerFold, forKey: Keys.cornerFold)
        UserDefaults.standard.setOptionalBool(ornamentOverrides.showHeaderOrnament, forKey: Keys.headerOrnament)
        UserDefaults.standard.setOptionalBool(ornamentOverrides.showPaperTexture, forKey: Keys.paperTexture)
    }
}

private extension UserDefaults {
    func optionalBool(forKey key: String) -> Bool? {
        guard object(forKey: key) != nil else { return nil }
        return bool(forKey: key)
    }

    func setOptionalBool(_ value: Bool?, forKey key: String) {
        if let value {
            set(value, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
}

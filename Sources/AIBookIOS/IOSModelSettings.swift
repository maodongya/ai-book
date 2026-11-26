import Foundation

/// 读书通道模型设置。与 Mac 共用 `aiBook.book.*` 键；旧 `aiBook.ios.*` 首次启动会迁过来。
@MainActor
final class IOSModelSettings: ObservableObject {
    private enum Key {
        static let baseURL = "aiBook.book.baseURL"
        static let model = "aiBook.book.model"
        static let apiKey = "aiBook.book.apiKey"
        static let contextPercent = "aiBook.book.contextPercent"
        static let legacyBaseURL = "aiBook.ios.baseURL"
        static let legacyModel = "aiBook.ios.model"
        static let legacyApiKey = "aiBook.ios.apiKey"
    }

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Key.baseURL) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Key.model) }
    }
    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Key.apiKey) }
    }
    @Published var bookContextPercent: Double {
        didSet { defaults.set(bookContextPercent, forKey: Key.contextPercent) }
    }

    private let defaults: UserDefaults

    var isReady: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateLegacyIOSKeysIfNeeded(defaults: defaults)

        let storedURL = defaults.string(forKey: Key.baseURL) ?? ""
        let storedModel = defaults.string(forKey: Key.model) ?? ""
        let storedKey = defaults.string(forKey: Key.apiKey) ?? ""
        let untouchedOpenAI = storedKey.isEmpty
            && (storedURL.isEmpty || storedURL == "https://api.openai.com/v1")
            && (storedModel.isEmpty || storedModel == "gpt-4o-mini")
        let deepSeekURL = "https://api.deepseek.com/v1"
        let deepSeekModel = "deepseek-chat"
        if untouchedOpenAI {
            baseURL = deepSeekURL
            model = deepSeekModel
            defaults.set(deepSeekURL, forKey: Key.baseURL)
            defaults.set(deepSeekModel, forKey: Key.model)
        } else {
            baseURL = storedURL.isEmpty ? deepSeekURL : storedURL
            model = storedModel.isEmpty ? deepSeekModel : storedModel
        }
        apiKey = storedKey
        let storedPercent = defaults.object(forKey: Key.contextPercent) as? Double
        bookContextPercent = storedPercent ?? 0.35
    }

    func useDeepSeek() {
        baseURL = "https://api.deepseek.com/v1"
        model = "deepseek-chat"
    }

  private static func migrateLegacyIOSKeysIfNeeded(defaults: UserDefaults) {
        if defaults.string(forKey: Key.baseURL)?.isEmpty != false,
           let legacy = defaults.string(forKey: Key.legacyBaseURL), !legacy.isEmpty {
            defaults.set(legacy, forKey: Key.baseURL)
        }
        if defaults.string(forKey: Key.model)?.isEmpty != false,
           let legacy = defaults.string(forKey: Key.legacyModel), !legacy.isEmpty {
            defaults.set(legacy, forKey: Key.model)
        }
        if defaults.string(forKey: Key.apiKey)?.isEmpty != false,
           let legacy = defaults.string(forKey: Key.legacyApiKey), !legacy.isEmpty {
            defaults.set(legacy, forKey: Key.apiKey)
        }
    }
}
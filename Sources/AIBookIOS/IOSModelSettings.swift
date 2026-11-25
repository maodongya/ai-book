import Foundation

/// iOS 上这次要用的模型地址、模型和密钥。写在本机偏好里，不读 Mac 的档案。
@MainActor
final class IOSModelSettings: ObservableObject {
    /// 偏好键集中在这一处。
    private enum Key {
        static let baseURL = "aiBook.ios.baseURL" // OpenAI 兼容地址
        static let model = "aiBook.ios.model"
        static let apiKey = "aiBook.ios.apiKey"
    }

    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Key.baseURL) } // 改完就落盘
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Key.model) }
    }
    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Key.apiKey) } // 密钥只留在本机偏好
    }

    private let defaults: UserDefaults

    /// 地址、模型和密钥都写了，才允许发讲解或翻译。
    var isReady: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedURL = defaults.string(forKey: Key.baseURL) ?? ""
        let storedModel = defaults.string(forKey: Key.model) ?? ""
        let storedKey = defaults.string(forKey: Key.apiKey) ?? ""
        let untouchedOpenAI = storedKey.isEmpty
            && (storedURL.isEmpty || storedURL == "https://api.openai.com/v1")
            && (storedModel.isEmpty || storedModel == "gpt-4o-mini")
        let deepSeekURL = "https://api.deepseek.com/v1"
        let deepSeekModel = "deepseek-chat"
        if untouchedOpenAI {
            baseURL = deepSeekURL // 还没配过密钥时，改用 DeepSeek
            model = deepSeekModel
            defaults.set(deepSeekURL, forKey: Key.baseURL) // init 里不会触发 didSet，这里直接落盘
            defaults.set(deepSeekModel, forKey: Key.model)
        } else {
            baseURL = storedURL.isEmpty ? deepSeekURL : storedURL
            model = storedModel.isEmpty ? deepSeekModel : storedModel
        }
        apiKey = storedKey
    }

    /// 切到 DeepSeek 的地址和模型。已填写的密钥留着。
    func useDeepSeek() {
        baseURL = "https://api.deepseek.com/v1" // OpenAI 兼容入口
        model = "deepseek-chat"
    }
}

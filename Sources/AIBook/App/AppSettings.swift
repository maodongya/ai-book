import Foundation

/// 讲解语速档。rawValue 是中文，历史「极速（本地）」等旧名在 migrated 里回收。
enum SpeechEngineMode: String, CaseIterable, Identifiable, Codable {
    case fast = "快速"
    case balanced = "平衡"
    case natural = "自然"
    case relaxed = "舒缓"

    var id: String { rawValue }

    /// 读盘：空值/乱值回平衡；旧在线档位名映射到现在的四档。
    static func migrated(from stored: String?) -> SpeechEngineMode {
        guard let stored, !stored.isEmpty else { return .balanced }
        if let mode = SpeechEngineMode(rawValue: stored) { return mode }
        switch stored {
        case "极速（本地）": return .fast
        case "平衡（在线）": return .balanced
        case "高音质（在线）": return .natural
        case "美声（在线）": return .relaxed
        default: return .balanced
        }
    }
}

/// 讲解语言处理深度。rawValue 中文落盘。
enum SpeechLanguageMode: String, CaseIterable, Identifiable, Codable {
    case efficient = "高效"
    case balanced = "平衡"
    case deep = "深度"

    var id: String { rawValue }
}

/// 全局设置单例：进化 LLM、读书 LLM、Cursor、语音、界面/译文语言。键集中在 Keys。
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// 进化通道当前提供商。切换时先落盘旧档案再加载新档案。
    @Published var provider: LLMProvider {
        didSet {
            guard provider != oldValue else { return }
            guard !suppressLLMProfilePersistence else { return } // init/load 时不要回写
            persistActiveLLMProfile(for: oldValue) // 把旧提供商的 key/url/model 收进 Store
            UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
            loadLLMProfile(for: provider)
        }
    }

    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: Keys.baseURL)
            guard !suppressLLMProfilePersistence else { return }
            persistActiveLLMProfile(for: provider)
        }
    }

    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: Keys.model)
            guard !suppressLLMProfilePersistence else { return }
            persistActiveLLMProfile(for: provider)
        }
    }

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
            guard !suppressLLMProfilePersistence else { return }
            persistActiveLLMProfile(for: provider)
        }
    }

    @Published var explanationSource: ExplanationSource {
        didSet { UserDefaults.standard.set(explanationSource.rawValue, forKey: Keys.explanationSource) }
    }

    @Published var cursorAPIKey: String {
        didSet { UserDefaults.standard.set(cursorAPIKey, forKey: Keys.cursorAPIKey) }
    }

    @Published var cursorModel: String {
        didSet { UserDefaults.standard.set(cursorModel, forKey: Keys.cursorModel) }
    }

    @Published var cursorBridgePath: String {
        didSet { UserDefaults.standard.set(cursorBridgePath, forKey: Keys.cursorBridgePath) }
    }

    @Published var cursorContextPercent: Double {
        didSet { UserDefaults.standard.set(cursorContextPercent, forKey: Keys.cursorContextPercent) }
    }

    @Published var llmContextPercent: Double {
        didSet { UserDefaults.standard.set(llmContextPercent, forKey: Keys.llmContextPercent) }
    }

    /// 读书（讲解/翻译）通道提供商，和进化通道分开存。
    @Published var bookProvider: LLMProvider {
        didSet {
            guard bookProvider != oldValue else { return }
            guard !suppressBookProfilePersistence else { return }
            persistBookProfile(for: oldValue)
            UserDefaults.standard.set(bookProvider.rawValue, forKey: Keys.bookProvider)
            loadBookProfile(for: bookProvider)
        }
    }

    @Published var bookBaseURL: String {
        didSet {
            UserDefaults.standard.set(bookBaseURL, forKey: Keys.bookBaseURL)
            guard !suppressBookProfilePersistence else { return }
            persistBookProfile(for: bookProvider)
        }
    }

    @Published var bookModel: String {
        didSet {
            UserDefaults.standard.set(bookModel, forKey: Keys.bookModel)
            guard !suppressBookProfilePersistence else { return }
            persistBookProfile(for: bookProvider)
        }
    }

    @Published var bookApiKey: String {
        didSet {
            UserDefaults.standard.set(bookApiKey, forKey: Keys.bookApiKey)
            guard !suppressBookProfilePersistence else { return }
            persistBookProfile(for: bookProvider)
        }
    }

    @Published var bookContextPercent: Double {
        didSet { UserDefaults.standard.set(bookContextPercent, forKey: Keys.bookContextPercent) }
    }

    @Published var autoEvolutionEnabled: Bool {
        didSet { UserDefaults.standard.set(autoEvolutionEnabled, forKey: Keys.autoEvolutionEnabled) }
    }

    @Published var explanationVoiceID: String {
        didSet { SpeechVoiceStore.selectedVoiceID = explanationVoiceID } // 语音另库存一份
    }

    @Published var speechEngineMode: SpeechEngineMode {
        didSet { UserDefaults.standard.set(speechEngineMode.rawValue, forKey: Keys.speechEngineMode) }
    }

    @Published var speechLanguageMode: SpeechLanguageMode {
        didSet { UserDefaults.standard.set(speechLanguageMode.rawValue, forKey: Keys.speechLanguageMode) }
    }

    @Published var translationTargetLanguage: TranslationTargetLanguage {
        didSet { TranslationTargetLanguageStore.save(translationTargetLanguage) } // 键在 Store 里，这里不写死
    }

    @Published var appLanguage: BookAppLanguage {
        didSet {
            guard appLanguage != oldValue else { return }
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            localizationRevision &+= 1 // 通知界面重取目录文案
        }
    }

    /// 界面语言世代号。只加不减，给 Environment 当观察哨。
    @Published private(set) var localizationRevision = 0

    /// UserDefaults 键只在这里出现。
    private enum Keys {
        static let provider = "aiBook.provider"
        static let baseURL = "aiBook.baseURL"
        static let model = "aiBook.model"
        static let apiKey = "aiBook.apiKey"
        static let explanationSource = "aiBook.explanationSource"
        static let cursorAPIKey = "aiBook.cursorAPIKey"
        static let cursorModel = "aiBook.cursorModel"
        static let cursorBridgePath = "aiBook.cursorBridgePath"
        static let cursorContextPercent = "aiBook.cursorContextPercent"
        static let llmContextPercent = "aiBook.llmContextPercent"
        static let bookProvider = "aiBook.book.provider"
        static let bookBaseURL = "aiBook.book.baseURL"
        static let bookModel = "aiBook.book.model"
        static let bookApiKey = "aiBook.book.apiKey"
        static let bookContextPercent = "aiBook.book.contextPercent"
        static let autoEvolutionEnabled = "aiBook.autoEvolutionEnabled"
        static let speechEngineMode = "aiBook.speechEngineMode"
        static let speechLanguageMode = "aiBook.speechLanguageMode"
        static let appLanguage = "aiBook.appLanguage"
    }

    /// init / loadProfile 时挡住 didSet，避免用半成品覆盖档案。
    private var suppressLLMProfilePersistence = false
    private var suppressBookProfilePersistence = false

    private init() {
        suppressLLMProfilePersistence = true
        suppressBookProfilePersistence = true
        defer {
            suppressLLMProfilePersistence = false
            suppressBookProfilePersistence = false
        }

        LLMProfileStore.migrateLegacyFlatStorageIfNeeded() // 旧扁平 key → 按提供商分档

        let storedProvider = UserDefaults.standard.string(forKey: Keys.provider)
        let resolvedProvider = LLMProvider(rawValue: storedProvider ?? "") ?? .openAI // 乱值当 OpenAI
        provider = resolvedProvider

        let legacyBaseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? resolvedProvider.defaultBaseURL
        let legacyModel = UserDefaults.standard.string(forKey: Keys.model) ?? resolvedProvider.defaultModel
        let legacyAPIKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""

        LLMProfileStore.migrateLegacySingleKey(
            currentProvider: resolvedProvider,
            apiKey: legacyAPIKey,
            baseURL: legacyBaseURL,
            model: legacyModel,
            scope: .evolution
        )
        LLMProfileStore.repairDuplicateLegacyKeys(
            legacyAPIKey: legacyAPIKey,
            legacyBaseURL: legacyBaseURL,
            activeProvider: resolvedProvider,
            scope: .evolution
        )
        LLMProfileStore.seedBookScopeIfNeeded(activeEvolutionProvider: resolvedProvider)

        let profile = LLMProfileStore.profile(for: resolvedProvider, scope: .evolution)
        baseURL = profile.baseURL.isEmpty ? legacyBaseURL : profile.baseURL
        model = profile.model.isEmpty ? legacyModel : profile.model
        apiKey = profile.apiKey

        let storedBookProvider = UserDefaults.standard.string(forKey: Keys.bookProvider)
        let resolvedBookProvider = LLMProvider(rawValue: storedBookProvider ?? "") ?? .ollama // 读书默认本地
        bookProvider = resolvedBookProvider
        let bookProfile = LLMProfileStore.profile(for: resolvedBookProvider, scope: .book)
        bookBaseURL = UserDefaults.standard.string(forKey: Keys.bookBaseURL)
            ?? (bookProfile.baseURL.isEmpty ? resolvedBookProvider.defaultBaseURL : bookProfile.baseURL)
        bookModel = UserDefaults.standard.string(forKey: Keys.bookModel)
            ?? (bookProfile.model.isEmpty ? resolvedBookProvider.defaultModel : bookProfile.model)
        bookApiKey = UserDefaults.standard.string(forKey: Keys.bookApiKey) ?? bookProfile.apiKey
        let storedBookContext = UserDefaults.standard.object(forKey: Keys.bookContextPercent) as? Double
        bookContextPercent = storedBookContext ?? 50

        let storedSource = UserDefaults.standard.string(forKey: Keys.explanationSource)
        explanationSource = ExplanationSource(rawValue: storedSource ?? "") ?? .llm
        let resolvedCursorKey = CursorAPIKeyStore.resolveStoredKey()
        cursorAPIKey = resolvedCursorKey
        if !resolvedCursorKey.isEmpty {
            CursorAPIKeyStore.save(resolvedCursorKey) // 统一写回钥匙串，避免只在 Defaults 里
        }
        cursorModel = Self.sanitizeCursorModel(
            UserDefaults.standard.string(forKey: Keys.cursorModel) ?? CursorModelOption.composer25.rawValue
        )
        cursorBridgePath = UserDefaults.standard.string(forKey: Keys.cursorBridgePath) ?? CursorService.defaultBridgeDirectory()?.path ?? ""
        let storedContext = UserDefaults.standard.object(forKey: Keys.cursorContextPercent) as? Double
        cursorContextPercent = storedContext ?? 50
        let storedLLMContext = UserDefaults.standard.object(forKey: Keys.llmContextPercent) as? Double
        llmContextPercent = storedLLMContext ?? 50
        if UserDefaults.standard.object(forKey: Keys.autoEvolutionEnabled) != nil {
            autoEvolutionEnabled = UserDefaults.standard.bool(forKey: Keys.autoEvolutionEnabled)
        } else {
            autoEvolutionEnabled = true // 没写过这个键默认开自动升级
        }
        explanationVoiceID = SpeechVoiceStore.selectedVoiceID
        let storedSpeechMode = UserDefaults.standard.string(forKey: Keys.speechEngineMode)
        speechEngineMode = SpeechEngineMode.migrated(from: storedSpeechMode)
        let storedLanguageMode = UserDefaults.standard.string(forKey: Keys.speechLanguageMode)
        speechLanguageMode = SpeechLanguageMode(rawValue: storedLanguageMode ?? "") ?? .deep
        translationTargetLanguage = TranslationTargetLanguageStore.load()
        appLanguage = BookAppLanguage.migrated(from: UserDefaults.standard.string(forKey: Keys.appLanguage))
        normalizeExplanationVoiceSelection()
    }

    /// 设置页打开时刷新可用声，丢掉失效 id。
    func reloadExplanationVoices() {
        normalizeExplanationVoiceSelection()
    }

    /// 当前 id 不在可选列表里则落到第一支可用声。
    private func normalizeExplanationVoiceSelection() {
        SpeechVoiceStore.normalizeStoredSelection()
        let selectable = SpeechVoiceCatalog.groupedSelectableOptions().flatMap(\.voices)
        guard !selectable.contains(where: { $0.id == explanationVoiceID }) else { return }
        if let first = selectable.first {
            explanationVoiceID = first.id
        }
    }

    var explanationVoiceLabel: String {
        SpeechVoiceCatalog.option(for: explanationVoiceID)?.displayName ?? "默认"
    }

    /// 使用时解析「跟随界面语言」，不要在点选时写死。
    var resolvedTranslationTargetLanguage: TranslationTargetLanguage {
        translationTargetLanguage.resolved(appLanguage: appLanguage)
    }

    var selectedCursorModel: CursorModelOption {
        get { CursorModelOption(rawValue: resolvedCursorModel) ?? .composer25 }
        set { cursorModel = newValue.rawValue }
    }

    /// 送给 cursor-bridge 的公开模型 id，滤掉 crsr_* 等内部 id。
    var resolvedCursorModel: String {
        Self.sanitizeCursorModel(cursorModel)
    }

    /// 空、内部 id、旧 composer-2 别名都收到 composer25；带连字符的未知公开 id 原样放行。
    static func sanitizeCursorModel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return CursorModelOption.composer25.rawValue }
        if trimmed.hasPrefix("crsr_") { return CursorModelOption.composer25.rawValue }
        if trimmed == "composer-2" || trimmed == "composer-2-fast" { return CursorModelOption.composer25.rawValue }
        if CursorModelOption(rawValue: trimmed) != nil { return trimmed }
        if trimmed.contains("-"), !trimmed.contains("_") { return trimmed }
        return CursorModelOption.composer25.rawValue
    }

    var llmConfiguration: LLMConfiguration {
        LLMProfileStore.resolvedConfiguration(for: provider, scope: .evolution)
    }

    var bookLLMConfiguration: LLMConfiguration {
        LLMProfileStore.resolvedConfiguration(for: bookProvider, scope: .book)
    }

    var evolutionLLMConfiguration: LLMConfiguration {
        llmConfiguration // 进化走同一套进化档案，名字给调用方读
    }

    /// 桥目录无效则 nil，调用方应提示未配置。
    var cursorConfiguration: CursorConfiguration? {
        let bridgeURL: URL?
        if cursorBridgePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bridgeURL = CursorService.defaultBridgeDirectory()
        } else {
            bridgeURL = URL(fileURLWithPath: cursorBridgePath, isDirectory: true)
        }

        guard let bridgeURL else { return nil }

        return CursorConfiguration(
            apiKey: effectiveCursorAPIKey,
            model: resolvedCursorModel,
            bridgeDirectory: bridgeURL,
            workingDirectory: CursorService.defaultProjectDirectory()?.path ?? FileManager.default.currentDirectoryPath
        )
    }

    /// 把当前进化提供商的空字段填成默认值，已有档案不覆盖。
    func applyProviderDefaults() {
        let profile = LLMProfileStore.profile(for: provider, scope: .evolution)
        if profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseURL = provider.defaultBaseURL
        } else {
            baseURL = profile.baseURL
        }
        if profile.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model = provider.defaultModel
        } else {
            model = profile.model
        }
        apiKey = profile.apiKey
    }

    func applyBookProviderDefaults() {
        let profile = LLMProfileStore.profile(for: bookProvider, scope: .book)
        if profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bookBaseURL = bookProvider.defaultBaseURL
        } else {
            bookBaseURL = profile.baseURL
        }
        if profile.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bookModel = bookProvider.defaultModel
        } else {
            bookModel = profile.model
        }
        bookApiKey = profile.apiKey
    }

    /// 切换进化提供商时灌入该档案；抑制 didSet 以免写回旧值。
    func loadLLMProfile(for provider: LLMProvider) {
        suppressLLMProfilePersistence = true
        defer { suppressLLMProfilePersistence = false }

        let profile = LLMProfileStore.profile(for: provider, scope: .evolution)
        baseURL = profile.baseURL.isEmpty ? provider.defaultBaseURL : profile.baseURL
        model = profile.model.isEmpty ? provider.defaultModel : profile.model
        apiKey = profile.apiKey
    }

    func loadBookProfile(for provider: LLMProvider) {
        suppressBookProfilePersistence = true
        defer { suppressBookProfilePersistence = false }

        let profile = LLMProfileStore.profile(for: provider, scope: .book)
        bookBaseURL = profile.baseURL.isEmpty ? provider.defaultBaseURL : profile.baseURL
        bookModel = profile.model.isEmpty ? provider.defaultModel : profile.model
        bookApiKey = profile.apiKey
    }

    func persistActiveLLMProfile(for provider: LLMProvider) {
        LLMProfileStore.save(
            LLMProfile(apiKey: apiKey, baseURL: baseURL, model: model),
            for: provider,
            scope: .evolution
        )
    }

    func persistBookProfile(for provider: LLMProvider) {
        LLMProfileStore.save(
            LLMProfile(apiKey: bookApiKey, baseURL: bookBaseURL, model: bookModel),
            for: provider,
            scope: .book
        )
    }

    var configuredLLMProviders: [LLMProvider] {
        LLMProfileStore.configuredProviders(scope: .evolution)
    }

    var configuredBookProviders: [LLMProvider] {
        LLMProfileStore.configuredProviders(scope: .book)
    }

    var isLLMConfigured: Bool {
        LLMProfileStore.isConfigured(for: provider, scope: .evolution)
    }

    var isBookLLMConfigured: Bool {
        LLMProfileStore.isConfigured(for: bookProvider, scope: .book)
    }

    var llmDisplayLabel: String {
        LLMConnector.displayLabel(provider: provider, model: model)
    }

    var bookLLMDisplayLabel: String {
        LLMConnector.displayLabel(provider: bookProvider, model: bookModel)
    }
}

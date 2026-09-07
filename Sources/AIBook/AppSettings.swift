import Foundation

enum SpeechEngineMode: String, CaseIterable, Identifiable, Codable {
    case fast = "快速"
    case balanced = "平衡"
    case natural = "自然"
    case relaxed = "舒缓"

    var id: String { rawValue }

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

enum SpeechLanguageMode: String, CaseIterable, Identifiable, Codable {
    case efficient = "高效"
    case balanced = "平衡"
    case deep = "深度"

    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var provider: LLMProvider {
        didSet {
            guard provider != oldValue else { return }
            guard !suppressLLMProfilePersistence else { return }
            persistActiveLLMProfile(for: oldValue)
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

    @Published var autoEvolutionEnabled: Bool {
        didSet { UserDefaults.standard.set(autoEvolutionEnabled, forKey: Keys.autoEvolutionEnabled) }
    }

    @Published var explanationVoiceID: String {
        didSet { SpeechVoiceStore.selectedVoiceID = explanationVoiceID }
    }

    @Published var speechEngineMode: SpeechEngineMode {
        didSet { UserDefaults.standard.set(speechEngineMode.rawValue, forKey: Keys.speechEngineMode) }
    }

    @Published var speechLanguageMode: SpeechLanguageMode {
        didSet { UserDefaults.standard.set(speechLanguageMode.rawValue, forKey: Keys.speechLanguageMode) }
    }

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
        static let autoEvolutionEnabled = "aiBook.autoEvolutionEnabled"
        static let speechEngineMode = "aiBook.speechEngineMode"
        static let speechLanguageMode = "aiBook.speechLanguageMode"
    }

    private var suppressLLMProfilePersistence = false

    private init() {
        suppressLLMProfilePersistence = true
        defer { suppressLLMProfilePersistence = false }

        let storedProvider = UserDefaults.standard.string(forKey: Keys.provider)
        let resolvedProvider = LLMProvider(rawValue: storedProvider ?? "") ?? .openAI
        provider = resolvedProvider

        let legacyBaseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? resolvedProvider.defaultBaseURL
        let legacyModel = UserDefaults.standard.string(forKey: Keys.model) ?? resolvedProvider.defaultModel
        let legacyAPIKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? ""

        LLMProfileStore.migrateLegacySingleKey(
            currentProvider: resolvedProvider,
            apiKey: legacyAPIKey,
            baseURL: legacyBaseURL,
            model: legacyModel
        )
        LLMProfileStore.repairDuplicateLegacyKeys(
            legacyAPIKey: legacyAPIKey,
            legacyBaseURL: legacyBaseURL,
            activeProvider: resolvedProvider
        )

        let profile = LLMProfileStore.profile(for: resolvedProvider)
        baseURL = profile.baseURL.isEmpty ? legacyBaseURL : profile.baseURL
        model = profile.model.isEmpty ? legacyModel : profile.model
        apiKey = profile.apiKey

        let storedSource = UserDefaults.standard.string(forKey: Keys.explanationSource)
        explanationSource = ExplanationSource(rawValue: storedSource ?? "") ?? .llm
        cursorAPIKey = UserDefaults.standard.string(forKey: Keys.cursorAPIKey) ?? CursorAPIKeyStore.resolveStoredKey()
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
            autoEvolutionEnabled = true
        }
        explanationVoiceID = SpeechVoiceStore.selectedVoiceID
        let storedSpeechMode = UserDefaults.standard.string(forKey: Keys.speechEngineMode)
        speechEngineMode = SpeechEngineMode.migrated(from: storedSpeechMode)
        let storedLanguageMode = UserDefaults.standard.string(forKey: Keys.speechLanguageMode)
        speechLanguageMode = SpeechLanguageMode(rawValue: storedLanguageMode ?? "") ?? .deep
        normalizeExplanationVoiceSelection()
    }

    func reloadExplanationVoices() {
        normalizeExplanationVoiceSelection()
    }

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

    var selectedCursorModel: CursorModelOption {
        get { CursorModelOption(rawValue: resolvedCursorModel) ?? .composer25 }
        set { cursorModel = newValue.rawValue }
    }

    /// Public Cursor model id sent to cursor-bridge (filters invalid internal ids like crsr_*).
    var resolvedCursorModel: String {
        Self.sanitizeCursorModel(cursorModel)
    }

    static func sanitizeCursorModel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return CursorModelOption.composer25.rawValue }
        if trimmed.hasPrefix("crsr_") { return CursorModelOption.composer25.rawValue }
        if CursorModelOption(rawValue: trimmed) != nil { return trimmed }
        if trimmed.contains("-"), !trimmed.contains("_") { return trimmed }
        return CursorModelOption.composer25.rawValue
    }

    var llmConfiguration: LLMConfiguration {
        LLMProfileStore.resolvedConfiguration(for: provider)
    }

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

    func applyProviderDefaults() {
        let profile = LLMProfileStore.profile(for: provider)
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

    func loadLLMProfile(for provider: LLMProvider) {
        suppressLLMProfilePersistence = true
        defer { suppressLLMProfilePersistence = false }

        let profile = LLMProfileStore.profile(for: provider)
        baseURL = profile.baseURL.isEmpty ? provider.defaultBaseURL : profile.baseURL
        model = profile.model.isEmpty ? provider.defaultModel : profile.model
        apiKey = profile.apiKey
    }

    func persistActiveLLMProfile(for provider: LLMProvider) {
        LLMProfileStore.save(
            LLMProfile(apiKey: apiKey, baseURL: baseURL, model: model),
            for: provider
        )
    }

    var configuredLLMProviders: [LLMProvider] {
        LLMProfileStore.configuredProviders()
    }

    var isLLMConfigured: Bool {
        LLMProfileStore.isConfigured(for: provider)
    }

    var llmDisplayLabel: String {
        LLMConnector.displayLabel(provider: provider, model: model)
    }
}

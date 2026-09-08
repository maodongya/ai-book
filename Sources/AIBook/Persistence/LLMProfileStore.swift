import Foundation

/// Per-provider LLM credentials so switching providers does not reuse the wrong API Key.
struct LLMProfile: Codable, Equatable {
    var apiKey: String
    var baseURL: String
    var model: String

    static func defaults(for provider: LLMProvider) -> LLMProfile {
        LLMProfile(
            apiKey: "",
            baseURL: provider.defaultBaseURL,
            model: provider.defaultModel
        )
    }
}

enum LLMProfileStore {
    private static let legacyStorageKey = "aiBook.llmProfiles"
    private static let scopedStorageKey = "aiBook.llmProfilesByScope"

    static func sanitizedKey(_ apiKey: String) -> String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvedConfiguration(
        for provider: LLMProvider,
        scope: LLMProfileScope = .evolution
    ) -> LLMConfiguration {
        var profile = profile(for: provider, scope: scope)
        if provider == .qwen {
            profile = QwenBailianConfig.repairProfile(profile)
        } else if provider == .ollama {
            profile = OllamaConfig.repairProfile(profile)
        }

        let baseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey: String
        if provider == .qwen {
            apiKey = QwenBailianConfig.resolveAPIKey(stored: profile.apiKey)
        } else {
            apiKey = sanitizedKey(profile.apiKey)
        }

        return LLMConfiguration(
            provider: provider,
            baseURL: baseURL.isEmpty ? provider.defaultBaseURL : baseURL,
            model: model.isEmpty ? provider.defaultModel : model,
            apiKey: apiKey
        )
    }

    static func isConfigured(for provider: LLMProvider, scope: LLMProfileScope = .evolution) -> Bool {
        let configuration = resolvedConfiguration(for: provider, scope: scope)
        return LLMConnector.isConfigured(provider: provider, apiKey: configuration.apiKey)
    }

    static func loadAll(scope: LLMProfileScope) -> [String: LLMProfile] {
        loadScoped()[scope.rawValue] ?? [:]
    }

    static func profile(for provider: LLMProvider, scope: LLMProfileScope = .evolution) -> LLMProfile {
        let stored = loadAll(scope: scope)[provider.rawValue] ?? .defaults(for: provider)
        if provider == .qwen {
            return QwenBailianConfig.repairProfile(stored)
        }
        if provider == .ollama {
            return OllamaConfig.repairProfile(stored)
        }
        return stored
    }

    static func save(_ profile: LLMProfile, for provider: LLMProvider, scope: LLMProfileScope) {
        var scoped = loadScoped()
        var bucket = scoped[scope.rawValue] ?? [:]
        bucket[provider.rawValue] = profile
        scoped[scope.rawValue] = bucket
        persistScoped(scoped)
    }

    static func configuredProviders(scope: LLMProfileScope) -> [LLMProvider] {
        LLMProvider.allCases.filter { isConfigured(for: $0, scope: scope) }
    }

    static func migrateLegacySingleKey(
        currentProvider: LLMProvider,
        apiKey: String,
        baseURL: String,
        model: String,
        scope: LLMProfileScope = .evolution
    ) {
        let trimmedKey = sanitizedKey(apiKey)
        guard !trimmedKey.isEmpty else { return }
        var scoped = loadScoped()
        var bucket = scoped[scope.rawValue] ?? [:]
        guard bucket.isEmpty else { return }
        bucket[currentProvider.rawValue] = LLMProfile(apiKey: trimmedKey, baseURL: baseURL, model: model)
        scoped[scope.rawValue] = bucket
        persistScoped(scoped)
    }

    /// Clears a legacy key that was accidentally copied to multiple providers (e.g. OpenAI key on 通义千问).
    static func repairDuplicateLegacyKeys(
        legacyAPIKey: String,
        legacyBaseURL: String,
        activeProvider: LLMProvider,
        scope: LLMProfileScope = .evolution
    ) {
        let trimmedLegacy = sanitizedKey(legacyAPIKey)
        guard !trimmedLegacy.isEmpty else { return }

        var scoped = loadScoped()
        var bucket = scoped[scope.rawValue] ?? [:]
        let matchingProviders = LLMProvider.allCases.filter {
            sanitizedKey(bucket[$0.rawValue]?.apiKey ?? "") == trimmedLegacy
        }
        guard matchingProviders.count > 1 else { return }

        let legacyHost = URL(string: legacyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? ""
        let keeper = LLMProvider.allCases.first { provider in
            let profile = bucket[provider.rawValue] ?? .defaults(for: provider)
            let resolvedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let host = URL(string: resolvedBaseURL.isEmpty ? provider.defaultBaseURL : resolvedBaseURL)?.host ?? ""
            return !legacyHost.isEmpty && host == legacyHost
        } ?? activeProvider

        var changed = false
        for provider in matchingProviders where provider != keeper {
            var profile = bucket[provider.rawValue] ?? .defaults(for: provider)
            profile.apiKey = ""
            bucket[provider.rawValue] = profile
            changed = true
        }
        if changed {
            scoped[scope.rawValue] = bucket
            persistScoped(scoped)
        }
    }

    static func migrateLegacyFlatStorageIfNeeded() {
        guard UserDefaults.standard.data(forKey: scopedStorageKey) == nil else { return }
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let legacy = try? JSONDecoder().decode([String: LLMProfile].self, from: data),
              !legacy.isEmpty
        else { return }

        var scoped: [String: [String: LLMProfile]] = [:]
        scoped[LLMProfileScope.evolution.rawValue] = legacy
        persistScoped(scoped)
    }

    static func seedBookScopeIfNeeded(activeEvolutionProvider: LLMProvider) {
        var scoped = loadScoped()
        guard scoped[LLMProfileScope.book.rawValue] == nil else { return }

        if activeEvolutionProvider == .ollama {
            scoped[LLMProfileScope.book.rawValue] = scoped[LLMProfileScope.evolution.rawValue] ?? [:]
        } else {
            scoped[LLMProfileScope.book.rawValue] = [
                LLMProvider.ollama.rawValue: .defaults(for: .ollama)
            ]
        }
        persistScoped(scoped)
    }

    private static func loadScoped() -> [String: [String: LLMProfile]] {
        migrateLegacyFlatStorageIfNeeded()
        guard
            let data = UserDefaults.standard.data(forKey: scopedStorageKey),
            let decoded = try? JSONDecoder().decode([String: [String: LLMProfile]].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private static func persistScoped(_ scoped: [String: [String: LLMProfile]]) {
        guard let data = try? JSONEncoder().encode(scoped) else { return }
        UserDefaults.standard.set(data, forKey: scopedStorageKey)
    }
}

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
    private static let storageKey = "aiBook.llmProfiles"

    static func sanitizedKey(_ apiKey: String) -> String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvedConfiguration(for provider: LLMProvider) -> LLMConfiguration {
        var profile = profile(for: provider)
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

    static func isConfigured(for provider: LLMProvider) -> Bool {
        let configuration = resolvedConfiguration(for: provider)
        return LLMConnector.isConfigured(provider: provider, apiKey: configuration.apiKey)
    }

    static func loadAll() -> [String: LLMProfile] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: LLMProfile].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    static func profile(for provider: LLMProvider) -> LLMProfile {
        let stored = loadAll()[provider.rawValue] ?? .defaults(for: provider)
        if provider == .qwen {
            return QwenBailianConfig.repairProfile(stored)
        }
        if provider == .ollama {
            return OllamaConfig.repairProfile(stored)
        }
        return stored
    }

    static func save(_ profile: LLMProfile, for provider: LLMProvider) {
        var all = loadAll()
        all[provider.rawValue] = profile
        persist(all)
    }

    static func configuredProviders() -> [LLMProvider] {
        LLMProvider.allCases.filter { isConfigured(for: $0) }
    }

    static func migrateLegacySingleKey(currentProvider: LLMProvider, apiKey: String, baseURL: String, model: String) {
        let trimmedKey = sanitizedKey(apiKey)
        guard !trimmedKey.isEmpty else { return }
        var all = loadAll()
        // Only migrate the old single-key storage on first upgrade; never copy it to a newly selected provider.
        guard all.isEmpty else { return }
        all[currentProvider.rawValue] = LLMProfile(apiKey: trimmedKey, baseURL: baseURL, model: model)
        persist(all)
    }

    /// Clears a legacy key that was accidentally copied to multiple providers (e.g. OpenAI key on 通义千问).
    static func repairDuplicateLegacyKeys(legacyAPIKey: String, legacyBaseURL: String, activeProvider: LLMProvider) {
        let trimmedLegacy = sanitizedKey(legacyAPIKey)
        guard !trimmedLegacy.isEmpty else { return }

        var all = loadAll()
        let matchingProviders = LLMProvider.allCases.filter {
            sanitizedKey(all[$0.rawValue]?.apiKey ?? "") == trimmedLegacy
        }
        guard matchingProviders.count > 1 else { return }

        let legacyHost = URL(string: legacyBaseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? ""
        let keeper = LLMProvider.allCases.first { provider in
            let profile = all[provider.rawValue] ?? .defaults(for: provider)
            let resolvedBaseURL = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let host = URL(string: resolvedBaseURL.isEmpty ? provider.defaultBaseURL : resolvedBaseURL)?.host ?? ""
            return !legacyHost.isEmpty && host == legacyHost
        } ?? activeProvider

        var changed = false
        for provider in matchingProviders where provider != keeper {
            var profile = all[provider.rawValue] ?? .defaults(for: provider)
            profile.apiKey = ""
            all[provider.rawValue] = profile
            changed = true
        }
        if changed {
            persist(all)
        }
    }

    private static func persist(_ profiles: [String: LLMProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

import Foundation

@MainActor
final class CursorModelCatalog: ObservableObject {
    static let shared = CursorModelCatalog()

    @Published private(set) var models: [CursorModelInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let cursorService = CursorService()

    func refresh(force: Bool = false) async {
        let settings = AppSettings.shared
        guard settings.isCursorConfigured else {
            models = []
            return
        }
        guard let configuration = settings.cursorConfiguration else { return }
        if isLoading { return }
        if !force, !models.isEmpty { return }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let fetched = try await cursorService.listModels(configuration: configuration)
            if fetched.isEmpty {
                models = fallbackModels
            } else {
                models = fetched
            }
        } catch {
            lastError = error.localizedDescription
            if models.isEmpty {
                models = fallbackModels
            }
        }
    }

    private var fallbackModels: [CursorModelInfo] {
        CursorModelOption.allCases.map {
            CursorModelInfo(id: $0.rawValue, label: $0.label, description: nil)
        }
    }
}

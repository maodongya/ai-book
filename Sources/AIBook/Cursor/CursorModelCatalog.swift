import Foundation

/// 从 Cursor 桥拉模型列表，给设置页 Picker。失败或空列表回退到内置枚举。
@MainActor
final class CursorModelCatalog: ObservableObject {
    static let shared = CursorModelCatalog()

    @Published private(set) var models: [CursorModelInfo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let cursorService = CursorService()

    /// 拉列表。未配置 Cursor 则清空；非 force 且已有数据则跳过。
    func refresh(force: Bool = false) async {
        let settings = AppSettings.shared
        guard settings.isCursorConfigured else {
            models = [] // 没配 key/桥就不要展示过期列表
            return
        }
        guard let configuration = settings.cursorConfiguration else { return }
        if isLoading { return } // 防重入
        if !force, !models.isEmpty { return } // 已有缓存，设置页打开不打桥

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let fetched = try await cursorService.listModels(configuration: configuration)
            if fetched.isEmpty {
                models = fallbackModels // 桥回空数组时仍给内置项，避免 Picker 空白
            } else {
                models = fetched
            }
        } catch {
            lastError = error.localizedDescription
            if models.isEmpty {
                models = fallbackModels // 只有从未成功过才回退，成功过的旧列表留下
            }
        }
    }

    /// 内置 CursorModelOption，桥不可用时的保底。
    private var fallbackModels: [CursorModelInfo] {
        CursorModelOption.allCases.map {
            CursorModelInfo(id: $0.rawValue, label: $0.label, description: nil)
        }
    }
}

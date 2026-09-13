import Foundation

/// 启动时灌 Cursor / LLM 凭据，避免每次冷启动都弹要 key。
@MainActor
enum CursorAuthBootstrap {
    /// 启动入口：刷新已存的 Cursor key，桥路径为空则填默认目录。
    static func applyOnLaunch() {
        let settings = AppSettings.shared // 单例设置，这里只补缺，不重置用户改过的值
        settings.reloadCursorAPIKey() // 从钥匙串/落盘再读一遍，防止内存是空的

        if settings.cursorBridgePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let bridge = CursorService.defaultBridgeDirectory()?.path {
            settings.cursorBridgePath = bridge // 只在用户没填时写入默认桥目录
        }
    }
}

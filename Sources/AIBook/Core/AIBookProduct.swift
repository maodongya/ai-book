import Foundation

/// 产品身份：辅助读书应用的对外名称与定位。不负责窗口布局或功能开关。
enum AIBookProduct {
    /// 仓库与配置里的项目标识，须与目录名、包名稳定对应。
    static let slug = "ai-book"
    /// 窗口和关于页上的显示名，用户看见的是这个，不是 slug。
    static let displayName = "AIBook"
    /// 当前界面语言下的一句话标语，走目录以便八种语言一起改。
    static var tagline: String {
        BookL10n.string("app.tagline") // 从 String Catalog 取，禁止在这里写死中文标语
    }

    /// 主窗口标题：显示名 + 标语，语言切换后应跟着变。
    static var windowTitle: String {
        "\(displayName) · \(tagline)" // 中间点分隔，避免再引入第三份标题文案
    }

    /// 产品定位正文，关于页首行直接用，改定位只改这一处。
    static let positioning = """
    ai-book（\(displayName)）是一款辅助读书软件：左页阅读原文，右页提供与左页内容相关的 AI 讲解与问答。
    """

    /// 关于页多行：定位 + 源码位置 + 进化能力，顺序给用户扫读。
    static var aboutLines: [String] {
        [
            positioning.trimmingCharacters(in: .whitespacesAndNewlines), // 去掉多行字符串首尾空白，避免关于页多空行
            "项目标识 \(slug)，源码目录含 Package.swift 与 Sources/AIBook。", // 给开发者/关于页定位仓库，不是运行时路径检查
            "支持大模型 API 与 Cursor 本地对话，可由 AI 分析优化队列并一键升级。", // 点出进化能力，细节在 Evolution 包
        ]
    }
}

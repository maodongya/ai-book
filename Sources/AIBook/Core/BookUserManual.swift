import AppKit
import Foundation

/// 定位并打开《功能说明书》。只找文件、打开/揭示，不解析正文结构。
enum BookUserManual {
    /// 资源主文件名，与 docs/产品 和 Resources 里的副本必须同名。
    static let resourceName = "功能说明书"
    /// 说明书固定为 Markdown，改格式要同步打包脚本。
    static let resourceExtension = "md"

    /// 已安装 `.app` 走 `Bundle.main`；`swift run` 走 `Bundle.module`；再兜一层 SPM 嵌套 bundle。
    private static var resourceBundles: [Bundle] {
        var bundles: [Bundle] = [Bundle.main, Bundle.module] // 先正式包，再 SPM 模块包
        if let resourceURL = Bundle.main.resourceURL {
            let nested = Bundle(url: resourceURL.appendingPathComponent("AIBook_AIBook.bundle", isDirectory: true)) // SPM 打进 app 时的嵌套包名
            if let nested {
                bundles.append(nested) // 只有真实存在才加，避免空 Bundle 干扰查找
            }
        }
        return bundles
    }

    /// 说明书文件 URL：先搜各 bundle，开发态再回退到仓库路径。
    static var bundleURL: URL? {
        for bundle in resourceBundles {
            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url // 根目录下的 md
            }
            if let url = bundle.url(
                forResource: resourceName,
                withExtension: resourceExtension,
                subdirectory: "Resources"
            ) {
                return url // 有的布局放在 Resources 子目录
            }
        }
        return developmentManualURL // 打包资源缺失时读仓库，方便 `swift run`
    }

    /// 开发机上的仓库副本，优先 docs/产品（正文），其次 Sources 里给打包的那份。
    private static var developmentManualURL: URL? {
        guard let project = CursorService.defaultProjectDirectory() else { return nil } // 找不到项目根就放弃，避免乱扫磁盘
        let candidates = [ // 开发态优先仓库 docs/产品，与 Resources 副本对齐
            project.appendingPathComponent("docs/产品/功能说明书.md"), // 仓库正文，改文档看这里
            project.appendingPathComponent("Sources/AIBook/Resources/功能说明书.md"), // 打包副本，应与上一份同步
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } // 谁在用谁
    }

    /// 读说明书全文；找不到文件时返回带定位提示的兜底 Markdown，关于页仍能打开。
    static func loadMarkdown() -> String {
        guard let url = bundleURL,
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else {
            return """
            # AIBook 功能说明书

            未找到内置说明书文件。请从项目仓库打开 `docs/产品/功能说明书.md`，或重新安装应用。

            \(AIBookProduct.positioning)
            """ // 兜底仍带产品定位，避免空白窗
        }
        return text
    }

    /// 用系统默认编辑器打开说明书文件。找不到 URL 则静默返回。
    static func openInDefaultEditor() {
        guard let url = bundleURL else { return } // 没有文件不弹错，调用方已有菜单态
        NSWorkspace.shared.open(url) // 交给用户默认 md 应用
    }

    /// 在 Finder 里选中说明书，方便对照仓库副本。
    static func revealInFinder() {
        guard let url = bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url]) // 只揭示这一个文件
    }
}

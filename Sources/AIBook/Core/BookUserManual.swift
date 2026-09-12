import AppKit
import Foundation

enum BookUserManual {
    static let resourceName = "功能说明书"
    static let resourceExtension = "md"

    /// Installed `.app` uses `Bundle.main`; `swift run` puts resources in `Bundle.module`.
    private static var resourceBundles: [Bundle] {
        var bundles: [Bundle] = [Bundle.main, Bundle.module]
        if let resourceURL = Bundle.main.resourceURL {
            let nested = Bundle(url: resourceURL.appendingPathComponent("AIBook_AIBook.bundle", isDirectory: true))
            if let nested {
                bundles.append(nested)
            }
        }
        return bundles
    }

    static var bundleURL: URL? {
        for bundle in resourceBundles {
            if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
                return url
            }
            if let url = bundle.url(
                forResource: resourceName,
                withExtension: resourceExtension,
                subdirectory: "Resources"
            ) {
                return url
            }
        }
        return developmentManualURL
    }

    private static var developmentManualURL: URL? {
        guard let project = CursorService.defaultProjectDirectory() else { return nil }
        let candidates = [
            project.appendingPathComponent("功能说明书.md"),
            project.appendingPathComponent("Sources/AIBook/Resources/功能说明书.md"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func loadMarkdown() -> String {
        guard let url = bundleURL,
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else {
            return """
            # AIBook 功能说明书

            未找到内置说明书文件。请从项目仓库打开 `功能说明书.md`，或重新安装应用。

            \(AIBookProduct.positioning)
            """
        }
        return text
    }

    static func openInDefaultEditor() {
        guard let url = bundleURL else { return }
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder() {
        guard let url = bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

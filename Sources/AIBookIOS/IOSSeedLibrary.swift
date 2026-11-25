import Foundation

/// 安装包里的初始书籍。只负责从包内拷到文稿并选出默认打开的那一本，不读正文。
enum IOSSeedLibrary {
    /// 包内资源目录名。构建脚本把 `book/` 子文件夹拷到这里。
    static let folderName = "SeedBooks"
    /// 文稿库认的两种书。
    private static let bookExtensions: Set<String> = ["txt", "aibook"]

    /// 主包里的种子书根目录。没打进安装包时为空。
    static func bundledRoot(bundle: Bundle = .main) -> URL? {
        guard let resources = bundle.resourceURL else { return nil } // 没有资源目录就没有种子书
        let root = resources.appendingPathComponent(folderName, isDirectory: true) // SeedBooks 与可执行文件同级
        guard FileManager.default.fileExists(atPath: root.path) else { return nil } // 开发包没跑拷贝脚本时跳过
        return root
    }

    /// 把种子书按原文件夹拷进文稿。已存在的文件留下，避免盖掉测试时改过的稿。
    static func install(from seed: URL, into documents: URL, fileManager: FileManager = .default) throws -> URL? {
        var destinations: [URL] = [] // 拷完后仍指向文稿里的那一份
        for book in bookFiles(under: seed, fileManager: fileManager) {
            let destination = documents.appendingPathComponent(relativePath(of: book, under: seed)) // 保留「文件夹/书名」
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true) // 子文件夹可能还没有
                try fileManager.copyItem(at: book, to: destination) // 只补缺的，不覆盖
            }
            destinations.append(destination) // 默认打开用文稿副本，读到的是安装后的那本
        }
        return preferred(in: destinations) // 没有书时不强迫打开
    }

    /// 优先 `.aibook`，这样原文、译文、讲解一起进来。否则取排序后的第一份文本。
    static func preferred(in files: [URL]) -> URL? {
        let sorted = files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending } // 顺序稳定，不随目录枚举变
        if let bundle = sorted.first(where: { $0.pathExtension.lowercased() == "aibook" }) {
            return bundle // 包比散文本更适合当安装后的第一本
        }
        return sorted.first // 只有 txt 时仍打开一本
    }

    /// 某一层里的文件夹和书。文件夹排在前面，方便先点进一类书。
    static func libraryEntries(in folder: URL, fileManager: FileManager = .default) -> [URL] {
        let children = (try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? [] // 读不到目录就当空库
        let kept = children.filter { url in
            if isDirectory(url, fileManager: fileManager) { return true } // 书的文件夹要能点进去
            return bookExtensions.contains(url.pathExtension.lowercased()) // 散落的 txt、aibook 也列出
        }
        return kept.sorted { lhs, rhs in
            let leftDirectory = isDirectory(lhs, fileManager: fileManager)
            let rightDirectory = isDirectory(rhs, fileManager: fileManager)
            if leftDirectory != rightDirectory { return leftDirectory } // 文件夹先于单文件
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    /// 文件夹下面全部的书，含更深一层。
    static func bookFiles(under root: URL, fileManager: FileManager = .default) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] } // 目录打不开就没有书
        var files: [URL] = []
        for case let url as URL in enumerator {
            guard bookExtensions.contains(url.pathExtension.lowercased()) else { continue } // 跳过说明和系统垃圾文件
            files.append(url) // 收进这一棵目录下的书
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// 路径是不是目录。
    static func isDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        var directory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue // 文件不算文件夹
    }

    /// 种子根之后的相对路径，用来在文稿里摆回同样的文件夹。
    static func relativePath(of file: URL, under root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else { return file.lastPathComponent } // 不在这棵树下时只留文件名
        return String(filePath.dropFirst(prefix.count))
    }
}

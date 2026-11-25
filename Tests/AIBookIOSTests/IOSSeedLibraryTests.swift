import XCTest
@testable import AIBookIOS

/// 安装包里的初始书：按文件夹拷进文稿，并优先打开 `.aibook`。
final class IOSSeedLibraryTests: XCTestCase {
    /// 有 aibook 时不拿排在前面的 txt 当默认书。
    func testPreferredBookIsAnAIBookPackage() {
        let files = [
            URL(fileURLWithPath: "/books/a/a.txt"),
            URL(fileURLWithPath: "/books/m/m.aibook"),
            URL(fileURLWithPath: "/books/z/z.txt"),
        ]
        XCTAssertEqual(IOSSeedLibrary.preferred(in: files)?.lastPathComponent, "m.aibook")
    }

    /// 没有包时打开排序后的第一份文本。
    func testPreferredBookFallsBackToTheFirstText() {
        let files = [
            URL(fileURLWithPath: "/books/b.txt"),
            URL(fileURLWithPath: "/books/a.txt"),
        ]
        XCTAssertEqual(IOSSeedLibrary.preferred(in: files)?.lastPathComponent, "a.txt")
    }

    /// 子文件夹里的书会拷进文稿，已经改过的文件不被盖住。
    func testInstallKeepsFoldersAndDoesNotOverwriteEdits() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let seed = root.appendingPathComponent("SeedBooks", isDirectory: true)
        let documents = root.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: seed.appendingPathComponent("中庸", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        let source = seed.appendingPathComponent("中庸/中庸.aibook")
        try Data("打包".utf8).write(to: source)
        try Data("梦".utf8).write(to: seed.appendingPathComponent("中庸/附.txt"))
        let destination = documents.appendingPathComponent("中庸/中庸.aibook")
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("改过".utf8).write(to: destination)

        let opened = try IOSSeedLibrary.install(from: seed, into: documents, fileManager: fileManager)

        XCTAssertEqual(opened?.lastPathComponent, "中庸.aibook")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "改过")
        XCTAssertEqual(
            try String(contentsOf: documents.appendingPathComponent("中庸/附.txt"), encoding: .utf8),
            "梦"
        )
        try? fileManager.removeItem(at: root)
    }

    /// 文稿列表先给出文件夹，再给散落的文本。
    func testLibraryListsFoldersBeforeLooseFiles() throws {
        let fileManager = FileManager.default
        let folder = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: folder.appendingPathComponent("四书", isDirectory: true), withIntermediateDirectories: true)
        try Data("月光".utf8).write(to: folder.appendingPathComponent("静夜思.txt"))

        let names = IOSSeedLibrary.libraryEntries(in: folder, fileManager: fileManager).map(\.lastPathComponent)

        XCTAssertEqual(names, ["四书", "静夜思.txt"])
        try? fileManager.removeItem(at: folder)
    }
}

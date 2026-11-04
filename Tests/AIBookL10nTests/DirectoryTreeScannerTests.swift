import XCTest
@testable import AIBook

final class DirectoryTreeScannerTests: XCTestCase {
    func testScanListsOnlyTheOpenedLevelUntilExpanded() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }

        let scanned = try XCTUnwrap(DirectoryTreeScanner.scan(root: root))
        XCTAssertEqual(childNames(of: scanned), ["sub", "note.txt"])
        let sub = try XCTUnwrap(scanned.children?.first { $0.name == "sub" })
        XCTAssertNil(sub.children)

        let listed = try XCTUnwrap(DirectoryTreeScanner.children(in: sub.url))
        XCTAssertEqual(listed.map(\.name), ["later.txt"])
    }

    func testExpandedFolderRereadsDisk() throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let listed = try XCTUnwrap(DirectoryTreeScanner.scan(root: root))
        let subURL = try XCTUnwrap(listed.children?.first { $0.name == "sub" }?.url)
        try Data("new".utf8).write(to: subURL.appendingPathComponent("fresh.txt"))

        let scanned = try XCTUnwrap(DirectoryTreeScanner.scan(root: root, expandedPaths: [subURL.path]))
        let subNode = try XCTUnwrap(scanned.children?.first { $0.name == "sub" })
        XCTAssertEqual(subNode.children?.map(\.name), ["fresh.txt", "later.txt"])
    }

    private func makeTree() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sub = root.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: root.appendingPathComponent("note.txt"))
        try Data("b".utf8).write(to: sub.appendingPathComponent("later.txt"))
        return root
    }

    private func childNames(of node: DirectoryTreeNode) -> [String] {
        (node.children ?? []).map(\.name)
    }
}

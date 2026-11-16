import XCTest
@testable import AIBook

final class SecurityScopedFolderTests: XCTestCase {
    func testChildStaysInsideGrantAndSiblingDoesNot() {
        let root = URL(fileURLWithPath: "/books/shelf", isDirectory: true)
        XCTAssertTrue(FolderAccessPolicy.contains(candidate: root, root: root))
        XCTAssertTrue(FolderAccessPolicy.contains(
            candidate: URL(fileURLWithPath: "/books/shelf/note.txt"),
            root: root
        ))
        XCTAssertFalse(FolderAccessPolicy.contains(
            candidate: URL(fileURLWithPath: "/books/shelf-extra/note.txt"),
            root: root
        ))
        XCTAssertFalse(FolderAccessPolicy.contains(
            candidate: URL(fileURLWithPath: "/books"),
            root: root
        ))
    }

    func testExpandedPathsOutsideTheGrantAreDropped() {
        let root = URL(fileURLWithPath: "/books/shelf", isDirectory: true)
        let kept = FolderAccessPolicy.pathsInside(
            root: root,
            paths: ["/books/shelf", "/books/shelf/chapters", "/books/other", "/books/shelf-extra"]
        )
        XCTAssertEqual(kept, Set(["/books/shelf", "/books/shelf/chapters"]))
    }

    func testPathOnlyRootIsNotRestoredEvenWhenTheFolderExists() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let stored = DirectoryBrowserPersistence.StoredRoot(
            id: UUID(),
            urlPath: folder.path,
            bookmarkData: nil,
            expandedPaths: [folder.path]
        )
        let restored = DirectoryBrowserPersistence.restorable([stored]) { _ in folder }
        XCTAssertTrue(restored.isEmpty)
    }

    func testBookmarkRootRestoresOnlyInsideTheResolvedFolder() {
        let root = URL(fileURLWithPath: "/books/shelf", isDirectory: true)
        let bookmark = Data("grant".utf8)
        let stored = DirectoryBrowserPersistence.StoredRoot(
            id: UUID(),
            urlPath: "/unused/path",
            bookmarkData: bookmark,
            expandedPaths: ["/books/shelf/chapters", "/elsewhere"]
        )
        let restored = DirectoryBrowserPersistence.restorable([stored]) { data in
            data == bookmark ? root : nil
        }
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored[0].url, root.standardizedFileURL)
        XCTAssertEqual(Set(restored[0].expandedPaths), Set(["/books/shelf/chapters"]))
        XCTAssertEqual(restored[0].bookmarkData, bookmark)
    }

    func testTrashAllowsOnlyItemsInsideAGrantedFolder() {
        let root = URL(fileURLWithPath: "/books/shelf", isDirectory: true)
        XCTAssertTrue(DirectoryItemTrash.isInsideGrantedFolder(
            URL(fileURLWithPath: "/books/shelf/note.txt"),
            roots: [root]
        ))
        XCTAssertFalse(DirectoryItemTrash.isInsideGrantedFolder(
            URL(fileURLWithPath: "/tmp/note.txt"),
            roots: [root]
        ))
    }
}

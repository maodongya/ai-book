import XCTest
@testable import AIBook

final class DirectoryItemTrashTests: XCTestCase {
    func testContainsMatchesItemAndDescendantsOnly() {
        XCTAssertTrue(DirectoryItemTrash.contains(path: "/books/a", deletedPath: "/books/a"))
        XCTAssertTrue(DirectoryItemTrash.contains(path: "/books/a/b.txt", deletedPath: "/books/a"))
        XCTAssertFalse(DirectoryItemTrash.contains(path: "/books/ab", deletedPath: "/books/a"))
        XCTAssertFalse(DirectoryItemTrash.contains(path: "/books", deletedPath: "/books/a"))
    }
}

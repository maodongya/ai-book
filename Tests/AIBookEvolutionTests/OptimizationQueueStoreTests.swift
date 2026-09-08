import XCTest
@testable import AIBookEvolution

final class OptimizationQueueStoreTests: XCTestCase {
    func testMigrateCreatesUserItemsOnlyWhenJSONMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = OptimizationQueueStore(
            fileURL: directory.appendingPathComponent("optimization-queue.json")
        )
        let notes = "1、已完成：分栏\n2、增加朗读\n"
        let first = try store.migrateFromReadmeNotesIfNeeded(notes)
        XCTAssertEqual(first.items.count, 2)
        XCTAssertEqual(first.items[0].source, .user)
        XCTAssertEqual(first.items[0].status, .completed)
        XCTAssertEqual(first.items[1].status, .pending)

        var mutated = first
        mutated.items[1].title = "已被用户改过"
        try store.save(mutated)

        let second = try store.migrateFromReadmeNotesIfNeeded("1、全新笔记不应覆盖")
        XCTAssertEqual(second.items[1].title, "已被用户改过")
    }
}

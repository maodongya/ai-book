import XCTest
@testable import AIBookEvolution

/// JSON 已在就不再用 README 笔记覆盖用户改过的队列。
final class OptimizationQueueStoreTests: XCTestCase {
    /// 首次从笔记迁入；第二次有 JSON 必须忽略新笔记。
    func testMigrateCreatesUserItemsOnlyWhenJSONMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = OptimizationQueueStore(
            fileURL: directory.appendingPathComponent("optimization-queue.json")
        )
        let notes = "1、已完成：分栏\n2、增加朗读\n"
        let first = try store.migrateFromReadmeNotesIfNeeded(notes)
        XCTAssertEqual(first.items.count, 2) // 空 JSON 才从笔记建
        XCTAssertEqual(first.items[0].source, .user) // 笔记迁入算用户项，不是分析草稿
        XCTAssertEqual(first.items[0].status, .completed)
        XCTAssertEqual(first.items[1].status, .pending)

        var mutated = first
        mutated.items[1].title = "已被用户改过"
        try store.save(mutated)

        let second = try store.migrateFromReadmeNotesIfNeeded("1、全新笔记不应覆盖")
        XCTAssertEqual(second.items[1].title, "已被用户改过") // 已有 JSON 禁止笔记覆盖
    }
}

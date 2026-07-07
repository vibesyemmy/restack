// Tests/RestackCoreTests/AutoLayoutStoreTests.swift
import XCTest
@testable import RestackCore

final class AutoLayoutStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("restack-auto-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func snap(_ name: String) -> Snapshot {
        Snapshot(name: name, createdAt: Date(timeIntervalSince1970: 1), displays: [], windows: [])
    }

    func test_saveThenLoad_byConfigKey() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("builtin|EXT1"), forConfig: "builtin|EXT1")
        let loaded = try store.load(forConfig: "builtin|EXT1")
        XCTAssertEqual(loaded?.name, "builtin|EXT1")
    }

    func test_exists() throws {
        let store = AutoLayoutStore(directory: tempDir())
        XCTAssertFalse(store.exists(forConfig: "builtin"))
        try store.save(snap("builtin"), forConfig: "builtin")
        XCTAssertTrue(store.exists(forConfig: "builtin"))
    }

    func test_loadMissing_returnsNil() throws {
        let store = AutoLayoutStore(directory: tempDir())
        XCTAssertNil(try store.load(forConfig: "nope"))
    }

    func test_delete() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("k"), forConfig: "k")
        try store.delete(forConfig: "k")
        XCTAssertFalse(store.exists(forConfig: "k"))
    }

    func test_distinctKeysDoNotCollide() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("one"), forConfig: "builtin")
        try store.save(snap("two"), forConfig: "builtin|EXT1")
        XCTAssertEqual(try store.load(forConfig: "builtin")?.name, "one")
        XCTAssertEqual(try store.load(forConfig: "builtin|EXT1")?.name, "two")
    }
}

// Tests/RestackCoreTests/SnapshotStoreTests.swift
import XCTest
@testable import RestackCore

final class SnapshotStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("restack-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sample(_ name: String) -> Snapshot {
        Snapshot(name: name, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                 displays: [], windows: [])
    }

    func test_saveThenLoad_returnsEqualSnapshot() throws {
        let store = SnapshotStore(directory: tempDir())
        let snap = sample("Deep Work")
        try store.save(snap)
        let loaded = try store.load(id: snap.id)
        XCTAssertEqual(loaded, snap)
    }

    func test_list_returnsAllSavedSnapshots_sortedByCreatedAtDescending() throws {
        let store = SnapshotStore(directory: tempDir())
        let older = Snapshot(name: "Old", createdAt: Date(timeIntervalSince1970: 1000), displays: [], windows: [])
        let newer = Snapshot(name: "New", createdAt: Date(timeIntervalSince1970: 2000), displays: [], windows: [])
        try store.save(older); try store.save(newer)
        let list = try store.list()
        XCTAssertEqual(list.map(\.name), ["New", "Old"])
    }

    func test_delete_removesSnapshot() throws {
        let store = SnapshotStore(directory: tempDir())
        let snap = sample("Temp")
        try store.save(snap)
        try store.delete(id: snap.id)
        XCTAssertThrowsError(try store.load(id: snap.id))
    }
}

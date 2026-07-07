// Tests/RestackCoreTests/ActivityLogTests.swift
import XCTest
@testable import RestackCore

final class ActivityLogTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("restack-activity-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func event(_ trigger: ActivityEvent.Trigger, at seconds: TimeInterval, placed: Int = 3) -> ActivityEvent {
        ActivityEvent(timestamp: Date(timeIntervalSince1970: seconds), trigger: trigger,
                      configID: "builtin", snapshotName: "s", placed: placed, total: 4,
                      skips: ["com.x: no window"])
    }

    func test_appendThenRecent_roundTripsNewestFirst() throws {
        let log = ActivityLog(directory: tempDir())
        try log.append(event(.manual, at: 100))
        try log.append(event(.monitorChange, at: 200))
        let recent = log.recent(limit: 10)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent[0].trigger, .monitorChange)   // newest first
        XCTAssertEqual(recent[1].trigger, .manual)
        XCTAssertEqual(recent[0].skips, ["com.x: no window"])
    }

    func test_capTrimsOldestEvents() throws {
        let log = ActivityLog(directory: tempDir(), cap: 3)
        for i in 0..<5 { try log.append(event(.manual, at: TimeInterval(i), placed: i)) }
        let recent = log.recent(limit: 10)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.map(\.placed), [4, 3, 2])     // oldest two trimmed
    }

    func test_recentOnEmptyLog_returnsEmpty() {
        XCTAssertTrue(ActivityLog(directory: tempDir()).recent().isEmpty)
    }

    func test_limitRespected() throws {
        let log = ActivityLog(directory: tempDir())
        for i in 0..<10 { try log.append(event(.autosave, at: TimeInterval(i))) }
        XCTAssertEqual(log.recent(limit: 4).count, 4)
    }
}

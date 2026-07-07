// Tests/RestackCoreTests/ModelsTests.swift
import XCTest
@testable import RestackCore

final class ModelsTests: XCTestCase {
    func test_snapshot_jsonRoundTrip_isLossless() throws {
        let snap = Snapshot(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Deep Work",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            displays: [DisplaySnapshot(stableID: "D1", width: 3840, height: 2160, originX: 0, originY: 0)],
            windows: [WindowSnapshot(appBundleID: "com.apple.Safari", appName: "Safari",
                                     title: "Docs", x: 10, y: 20, width: 800, height: 600,
                                     displayID: "D1", indexWithinApp: 0)]
        )
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }
}

// Tests/RestackKitTests/CaptureEngineTests.swift
import XCTest
@testable import RestackKit
import RestackCore

private final class FakeCapture: WindowCapturing {
    let items: [CapturedWindow]
    init(_ items: [CapturedWindow]) { self.items = items }
    func captureAllWindows() -> [CapturedWindow] { items }
}

final class CaptureEngineTests: XCTestCase {
    func test_capture_buildsSnapshotWithDisplayAssignment() {
        let d1 = LiveDisplay(stableID: "D1", originX: 0, originY: 0, width: 1440, height: 900, isMain: true)
        let d2 = LiveDisplay(stableID: "D2", originX: 1440, originY: 0, width: 2560, height: 1440, isMain: false)
        let cap = FakeCapture([
            CapturedWindow(bundleID: "com.a", appName: "A", title: "Main",
                           frame: Frame(x: 100, y: 100, width: 800, height: 600), indexWithinApp: 0),
            CapturedWindow(bundleID: "com.a", appName: "A", title: "Second",
                           frame: Frame(x: 1600, y: 100, width: 800, height: 600), indexWithinApp: 1),
        ])
        let engine = CaptureEngine(capture: cap, displays: FakeDisplays([d1, d2]))
        let snap = engine.capture(name: "Deep Work", now: Date(timeIntervalSince1970: 42))
        XCTAssertEqual(snap.name, "Deep Work")
        XCTAssertEqual(snap.displays.map(\.stableID).sorted(), ["D1", "D2"])
        XCTAssertEqual(snap.windows.count, 2)
        // First window on D1 (x=100 within 0..1440), second on D2 (x=1600 within 1440..4000).
        XCTAssertEqual(snap.windows.first { $0.title == "Main" }?.displayID, "D1")
        XCTAssertEqual(snap.windows.first { $0.title == "Second" }?.displayID, "D2")
    }
}

// Tests/RestackKitTests/RestoreEngineTests.swift
import XCTest
@testable import RestackKit
import RestackCore

final class RestoreEngineTests: XCTestCase {
    private let d1 = LiveDisplay(stableID: "D1", originX: 0, originY: 0, width: 1000, height: 1000, isMain: true)

    private func snapshot(_ windows: [WindowSnapshot]) -> Snapshot {
        Snapshot(name: "S", createdAt: Date(timeIntervalSince1970: 0),
                 displays: [DisplaySnapshot(stableID: "D1", width: 1000, height: 1000, originX: 0, originY: 0)],
                 windows: windows)
    }
    private func win(_ bundle: String, _ title: String, _ idx: Int, x: Double) -> WindowSnapshot {
        WindowSnapshot(appBundleID: bundle, appName: bundle, title: title,
                       x: x, y: 0, width: 100, height: 100, displayID: "D1", indexWithinApp: idx)
    }

    func test_launchesMissingApp_thenPlacesItsWindow() {
        let live = LiveWindow(handleID: 7, title: "A", indexWithinApp: 0)
        let ws = FakeWorkspace(running: [], installed: ["com.a"])
        let windows = FakeWindows(eventual: ["com.a": [live]], appearAfter: ["com.a": 1])
        let engine = RestoreEngine(workspace: ws, windows: windows,
                                   displays: FakeDisplays([d1]), clock: FakeClock())
        let summary = engine.restore(snapshot(snapshotWindows()))
        XCTAssertEqual(ws.launched, ["com.a"])
        XCTAssertEqual(windows.setFrames.count, 1)
        XCTAssertEqual(windows.setFrames.first?.1, 7)          // handle
        XCTAssertEqual(summary.placedCount, 1)
    }

    func test_appNotInstalled_isSkippedWithReason() {
        let ws = FakeWorkspace(running: [], installed: [])     // not installed
        let engine = RestoreEngine(workspace: ws, windows: FakeWindows(),
                                   displays: FakeDisplays([d1]), clock: FakeClock())
        let summary = engine.restore(snapshot([win("com.ghost", "G", 0, x: 0)]))
        XCTAssertEqual(summary.placedCount, 0)
        XCTAssertEqual(summary.skipped.first?.app, "com.ghost")
    }

    func test_twoSameAppWindows_placedToCorrectSlots() {
        let w0 = LiveWindow(handleID: 10, title: "Left", indexWithinApp: 0)
        let w1 = LiveWindow(handleID: 20, title: "Right", indexWithinApp: 1)
        let ws = FakeWorkspace(running: ["com.a"], installed: ["com.a"])
        let windows = FakeWindows(eventual: ["com.a": [w1, w0]], appearAfter: ["com.a": 0]) // out of order
        let engine = RestoreEngine(workspace: ws, windows: windows,
                                   displays: FakeDisplays([d1]), clock: FakeClock())
        let snap = snapshot([win("com.a", "Left", 0, x: 0), win("com.a", "Right", 1, x: 500)])
        _ = engine.restore(snap)
        let leftPlacement = windows.setFrames.first { $0.1 == 10 }
        let rightPlacement = windows.setFrames.first { $0.1 == 20 }
        XCTAssertEqual(leftPlacement?.0.x, 0)
        XCTAssertEqual(rightPlacement?.0.x, 500)
    }

    // helper reused by first test
    private func snapshotWindows() -> [WindowSnapshot] { [win("com.a", "A", 0, x: 250)] }

    func test_runningButWindowlessApp_isReopenedThenPlaced() {
        // Browsers keep running after their last window closes: app "running", zero windows.
        // The engine must re-open it (macOS reopen -> new window) and then place it.
        let live = LiveWindow(handleID: 3, title: "T", indexWithinApp: 0)
        let ws = FakeWorkspace(running: ["com.b"], installed: ["com.b"])
        // First wait exhausts its polls (33 calls at 8s/0.25s); windows appear only after
        // call 35 — i.e. during the second, post-reopen wait.
        let windows = FakeWindows(eventual: ["com.b": [live]], appearAfter: ["com.b": 35])
        let engine = RestoreEngine(workspace: ws, windows: windows,
                                   displays: FakeDisplays([d1]), clock: FakeClock())
        let summary = engine.restore(snapshot([win("com.b", "T", 0, x: 100)]))
        XCTAssertEqual(ws.launched, ["com.b"])   // reopen attempted despite already running
        XCTAssertEqual(summary.placedCount, 1)
        XCTAssertTrue(summary.skipped.isEmpty)
    }
}

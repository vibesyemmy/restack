// Tests/RestackKitTests/IntegrationSmokeTests.swift
import XCTest
@testable import RestackKit
import RestackCore

/// Real-window smoke test. Requires Accessibility permission for the test runner and
/// TextEdit installed. Skipped unless RESTACK_INTEGRATION=1 is set.
final class IntegrationSmokeTests: XCTestCase {
    func test_capture_thenRestore_movesTextEditWindow() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RESTACK_INTEGRATION"] == "1",
                          "Set RESTACK_INTEGRATION=1 to run")
        let ws = NSWorkspaceController()
        let ax = AXWindowController()
        let displays = CGDisplayProvider()
        XCTAssertTrue(ws.launch(bundleID: "com.apple.TextEdit"))
        let waiter = WindowWaiter(windows: ax, clock: SystemClock(), timeout: 8, pollInterval: 0.3)
        let live = waiter.waitForWindows(bundleID: "com.apple.TextEdit")
        try XCTSkipIf(live.isEmpty, "TextEdit opened no window")

        // Move it to a known frame, capture, move away, restore, assert.
        ax.setFrame(Frame(x: 200, y: 200, width: 600, height: 400),
                    forWindowHandle: live[0].handleID, bundleID: "com.apple.TextEdit")
        let capture = CaptureEngine(capture: ax, displays: displays)
        let snap = capture.capture(name: "smoke", now: Date())
        ax.setFrame(Frame(x: 50, y: 50, width: 300, height: 300),
                    forWindowHandle: live[0].handleID, bundleID: "com.apple.TextEdit")
        let engine = RestoreEngine(workspace: ws, windows: ax, displays: displays, clock: SystemClock())
        let summary = engine.restore(snap)
        XCTAssertGreaterThanOrEqual(summary.placedCount, 1)
    }
}

// Tests/RestackCoreTests/DisplayResolverTests.swift
import XCTest
@testable import RestackCore

final class DisplayResolverTests: XCTestCase {
    private func slot(displayID: String, x: Double, y: Double, w: Double, h: Double) -> WindowSnapshot {
        WindowSnapshot(appBundleID: "com.x", appName: "X", title: "T",
                       x: x, y: y, width: w, height: h, displayID: displayID, indexWithinApp: 0)
    }
    private let main = LiveDisplay(stableID: "MAIN", originX: 0, originY: 0, width: 1440, height: 900, isMain: true)
    private let ext = LiveDisplay(stableID: "EXT", originX: 1440, originY: 0, width: 3840, height: 2160, isMain: false)

    func test_displayPresent_returnsSavedFrameUnchanged() {
        let r = DisplayResolver.resolve(slot: slot(displayID: "EXT", x: 1500, y: 100, w: 800, h: 600),
                                        available: [main, ext])
        XCTAssertEqual(r, Frame(x: 1500, y: 100, width: 800, height: 600))
    }

    func test_displayMissing_clampsOntoMainDisplay() {
        // Saved on EXT which is now gone. Should land within MAIN bounds (0,0,1440,900).
        let r = DisplayResolver.resolve(slot: slot(displayID: "EXT", x: 3000, y: 100, w: 800, h: 600),
                                        available: [main])
        XCTAssertGreaterThanOrEqual(r.x, main.originX)
        XCTAssertGreaterThanOrEqual(r.y, main.originY)
        XCTAssertLessThanOrEqual(r.x + r.width, main.originX + main.width)
        XCTAssertLessThanOrEqual(r.y + r.height, main.originY + main.height)
    }

    func test_windowLargerThanMain_isShrunkToFit() {
        let r = DisplayResolver.resolve(slot: slot(displayID: "EXT", x: 3000, y: 0, w: 5000, h: 4000),
                                        available: [main])
        XCTAssertLessThanOrEqual(r.width, main.width)
        XCTAssertLessThanOrEqual(r.height, main.height)
    }

    func test_noDisplaysAvailable_fallsBackToOrigin() {
        let r = DisplayResolver.resolve(slot: slot(displayID: "EXT", x: 3000, y: 100, w: 800, h: 600),
                                        available: [])
        XCTAssertEqual(r, Frame(x: 0, y: 0, width: 800, height: 600))
    }
}

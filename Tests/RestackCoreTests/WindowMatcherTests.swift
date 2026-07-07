// Tests/RestackCoreTests/WindowMatcherTests.swift
import XCTest
@testable import RestackCore

final class WindowMatcherTests: XCTestCase {
    private func win(_ title: String, _ idx: Int) -> WindowSnapshot {
        WindowSnapshot(appBundleID: "com.x", appName: "X", title: title,
                       x: 0, y: 0, width: 100, height: 100, displayID: "D1", indexWithinApp: idx)
    }

    func test_exactTitleMatch_pairsByTitle() {
        let saved = [win("Docs", 0), win("Mail", 1)]
        let live = [LiveWindow(handleID: 9, title: "Mail", indexWithinApp: 0),
                    LiveWindow(handleID: 8, title: "Docs", indexWithinApp: 1)]
        let pairs = WindowMatcher.match(saved: saved, live: live)
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs.first { $0.saved.title == "Docs" }?.live.handleID, 8)
        XCTAssertEqual(pairs.first { $0.saved.title == "Mail" }?.live.handleID, 9)
    }

    func test_duplicateTitles_fallBackToOrder() {
        let saved = [win("Untitled", 0), win("Untitled", 1)]
        let live = [LiveWindow(handleID: 100, title: "Untitled", indexWithinApp: 0),
                    LiveWindow(handleID: 200, title: "Untitled", indexWithinApp: 1)]
        let pairs = WindowMatcher.match(saved: saved, live: live)
        XCTAssertEqual(pairs.first { $0.saved.indexWithinApp == 0 }?.live.handleID, 100)
        XCTAssertEqual(pairs.first { $0.saved.indexWithinApp == 1 }?.live.handleID, 200)
    }

    func test_fewerLiveWindows_leavesSavedSlotUnmatched() {
        let saved = [win("A", 0), win("B", 1)]
        let live = [LiveWindow(handleID: 1, title: "A", indexWithinApp: 0)]
        let pairs = WindowMatcher.match(saved: saved, live: live)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.saved.title, "A")
    }

    func test_extraLiveWindows_areIgnored() {
        let saved = [win("A", 0)]
        let live = [LiveWindow(handleID: 1, title: "A", indexWithinApp: 0),
                    LiveWindow(handleID: 2, title: "Extra", indexWithinApp: 1)]
        let pairs = WindowMatcher.match(saved: saved, live: live)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.live.handleID, 1)
    }

    func test_eachLiveWindowUsedAtMostOnce() {
        let saved = [win("A", 0), win("A", 1)]
        let live = [LiveWindow(handleID: 1, title: "A", indexWithinApp: 0)]
        let pairs = WindowMatcher.match(saved: saved, live: live)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.live.handleID, 1)
    }

    func test_windowMatcher_emptyInputs_returnsEmpty() {
        XCTAssertEqual(WindowMatcher.match(saved: [], live: []), [])

        let saved = [win("A", 0), win("B", 1)]
        XCTAssertEqual(WindowMatcher.match(saved: saved, live: []), [])
    }
}

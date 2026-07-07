// Tests/RestackCoreTests/LayoutDiffTests.swift
import XCTest
@testable import RestackCore

final class LayoutDiffTests: XCTestCase {
    private func win(_ bundle: String, title: String, x: Double, display: String = "D1") -> WindowSnapshot {
        WindowSnapshot(appBundleID: bundle, appName: bundle, title: title,
                       x: x, y: 0, width: 100, height: 100, displayID: display, indexWithinApp: 0)
    }
    private func snap(_ windows: [WindowSnapshot]) -> Snapshot {
        Snapshot(name: "s", createdAt: Date(timeIntervalSince1970: 0), displays: [], windows: windows)
    }

    func test_titleChangeOnly_isNotALayoutChange() {
        let a = snap([win("com.a", title: "Tab One", x: 10)])
        let b = snap([win("com.a", title: "Tab Two", x: 10)])
        XCTAssertFalse(LayoutDiff.layoutChanged(a, b))
    }

    func test_movedWindow_isALayoutChange() {
        let a = snap([win("com.a", title: "T", x: 10)])
        let b = snap([win("com.a", title: "T", x: 300)])
        XCTAssertTrue(LayoutDiff.layoutChanged(a, b))
    }

    func test_addedWindow_isALayoutChange() {
        let a = snap([win("com.a", title: "T", x: 10)])
        let b = snap([win("com.a", title: "T", x: 10), win("com.b", title: "U", x: 50)])
        XCTAssertTrue(LayoutDiff.layoutChanged(a, b))
    }

    func test_windowOrderOnly_isNotALayoutChange() {
        let w1 = win("com.a", title: "T", x: 10)
        let w2 = win("com.b", title: "U", x: 50)
        XCTAssertFalse(LayoutDiff.layoutChanged(snap([w1, w2]), snap([w2, w1])))
    }

    func test_displayMoveOnly_isALayoutChange() {
        let a = snap([win("com.a", title: "T", x: 10, display: "D1")])
        let b = snap([win("com.a", title: "T", x: 10, display: "D2")])
        XCTAssertTrue(LayoutDiff.layoutChanged(a, b))
    }
}

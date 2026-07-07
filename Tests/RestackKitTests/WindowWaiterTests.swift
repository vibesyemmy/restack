// Tests/RestackKitTests/WindowWaiterTests.swift
import XCTest
@testable import RestackKit
import RestackCore

final class WindowWaiterTests: XCTestCase {
    func test_windowsAppearBeforeTimeout_returnsThem() {
        let win = LiveWindow(handleID: 1, title: "A", indexWithinApp: 0)
        let windows = FakeWindows(eventual: ["com.a": [win]], appearAfter: ["com.a": 2]) // appear on 3rd poll
        let waiter = WindowWaiter(windows: windows, clock: FakeClock(),
                                  timeout: 5.0, pollInterval: 0.5)
        let result = waiter.waitForWindows(bundleID: "com.a")
        XCTAssertEqual(result, [win])
    }

    func test_windowsNeverAppear_returnsEmptyAfterTimeout() {
        let windows = FakeWindows(eventual: ["com.a": []], appearAfter: ["com.a": 999])
        let waiter = WindowWaiter(windows: windows, clock: FakeClock(),
                                  timeout: 2.0, pollInterval: 0.5)
        let result = waiter.waitForWindows(bundleID: "com.a")
        XCTAssertTrue(result.isEmpty)
    }
}

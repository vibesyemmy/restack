// Tests/RestackCoreTests/AutosaveDeciderTests.swift
import XCTest
@testable import RestackCore

final class AutosaveDeciderTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func test_dueWhenNeverSaved() {
        XCTAssertTrue(AutosaveDecider.isDue(lastSavedAt: nil, now: at(0), interval: 45, inTransition: false))
    }

    func test_notDueDuringTransition() {
        XCTAssertFalse(AutosaveDecider.isDue(lastSavedAt: nil, now: at(0), interval: 45, inTransition: true))
    }

    func test_notDueBeforeInterval() {
        XCTAssertFalse(AutosaveDecider.isDue(lastSavedAt: at(0), now: at(30), interval: 45, inTransition: false))
    }

    func test_dueAfterInterval() {
        XCTAssertTrue(AutosaveDecider.isDue(lastSavedAt: at(0), now: at(45), interval: 45, inTransition: false))
    }
}

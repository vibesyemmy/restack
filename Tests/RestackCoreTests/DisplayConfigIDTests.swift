// Tests/RestackCoreTests/DisplayConfigIDTests.swift
import XCTest
@testable import RestackCore

final class DisplayConfigIDTests: XCTestCase {
    private func d(_ id: String) -> LiveDisplay {
        LiveDisplay(stableID: id, originX: 0, originY: 0, width: 100, height: 100, isMain: false)
    }

    func test_orderIndependent() {
        let a = DisplayConfigID.make(from: [d("builtin"), d("EXT1")])
        let b = DisplayConfigID.make(from: [d("EXT1"), d("builtin")])
        XCTAssertEqual(a, b)
    }

    func test_singleDisplay() {
        XCTAssertEqual(DisplayConfigID.make(from: [d("builtin")]), "builtin")
    }

    func test_multiDisplayJoinedSorted() {
        XCTAssertEqual(DisplayConfigID.make(from: [d("EXT1"), d("builtin")]), "EXT1|builtin")
    }

    func test_empty() {
        XCTAssertEqual(DisplayConfigID.make(from: []), "")
    }
}

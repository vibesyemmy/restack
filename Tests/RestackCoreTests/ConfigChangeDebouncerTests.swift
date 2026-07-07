// Tests/RestackCoreTests/ConfigChangeDebouncerTests.swift
import XCTest
@testable import RestackCore

final class ConfigChangeDebouncerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func test_emitsAfterSteadyInterval() {
        let deb = ConfigChangeDebouncer(interval: 2.0, initialConfig: "A")
        deb.record("B", at: at(0))
        XCTAssertNil(deb.poll(now: at(1)))          // not steady long enough
        XCTAssertEqual(deb.poll(now: at(2)), "B")   // steady >= 2s -> emit
        XCTAssertNil(deb.poll(now: at(3)))          // already emitted, nothing new
    }

    func test_absorbsFlapping() {
        let deb = ConfigChangeDebouncer(interval: 2.0, initialConfig: "A")
        deb.record("B", at: at(0))
        deb.record("A", at: at(1))     // flapped back before settling
        deb.record("B", at: at(1.5))
        XCTAssertNil(deb.poll(now: at(2.0)))        // B only steady since 1.5, not 2s yet
        XCTAssertEqual(deb.poll(now: at(3.5)), "B") // now steady 2s
    }

    func test_suppressesNoOpBackToInitial() {
        let deb = ConfigChangeDebouncer(interval: 2.0, initialConfig: "A")
        deb.record("B", at: at(0))
        deb.record("A", at: at(1))     // settled back on the already-current config
        XCTAssertNil(deb.poll(now: at(5)))          // equals lastEmitted "A" -> no emit
    }

    func test_emitsSequentialDistinctConfigs() {
        let deb = ConfigChangeDebouncer(interval: 1.0, initialConfig: "A")
        deb.record("B", at: at(0))
        XCTAssertEqual(deb.poll(now: at(1)), "B")
        deb.record("C", at: at(2))
        XCTAssertEqual(deb.poll(now: at(3)), "C")
    }
}

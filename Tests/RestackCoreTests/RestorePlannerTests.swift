// Tests/RestackCoreTests/RestorePlannerTests.swift
import XCTest
@testable import RestackCore

final class RestorePlannerTests: XCTestCase {
    private func win(_ bundle: String, _ title: String, _ idx: Int) -> WindowSnapshot {
        WindowSnapshot(appBundleID: bundle, appName: bundle, title: title,
                       x: 0, y: 0, width: 100, height: 100, displayID: "D1", indexWithinApp: idx)
    }
    private func snapshot(_ windows: [WindowSnapshot]) -> Snapshot {
        Snapshot(name: "S", createdAt: Date(timeIntervalSince1970: 0),
                 displays: [DisplaySnapshot(stableID: "D1", width: 100, height: 100, originX: 0, originY: 0)],
                 windows: windows)
    }

    func test_appNotRunning_isMarkedForLaunch() {
        let plan = RestorePlanner.plan(snapshot: snapshot([win("com.a", "A", 0)]), runningBundleIDs: [])
        XCTAssertEqual(plan.appsToLaunch, ["com.a"])
    }

    func test_appAlreadyRunning_isNotLaunched() {
        let plan = RestorePlanner.plan(snapshot: snapshot([win("com.a", "A", 0)]), runningBundleIDs: ["com.a"])
        XCTAssertTrue(plan.appsToLaunch.isEmpty)
    }

    func test_planGroupsWindowsByApp() {
        let plan = RestorePlanner.plan(
            snapshot: snapshot([win("com.a", "A1", 0), win("com.a", "A2", 1), win("com.b", "B1", 0)]),
            runningBundleIDs: ["com.b"])
        XCTAssertEqual(Set(plan.appPlans.map(\.bundleID)), ["com.a", "com.b"])
        let aPlan = plan.appPlans.first { $0.bundleID == "com.a" }
        XCTAssertEqual(aPlan?.windows.count, 2)
        XCTAssertEqual(aPlan?.needsLaunch, true)
    }
}

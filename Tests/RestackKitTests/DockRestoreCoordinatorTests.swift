// Tests/RestackKitTests/DockRestoreCoordinatorTests.swift
import XCTest
@testable import RestackKit
import RestackCore

final class DockRestoreCoordinatorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1000)
    private func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    private let builtin = LiveDisplay(stableID: "builtin", originX: 0, originY: 0, width: 1440, height: 900, isMain: true)
    private let ext = LiveDisplay(stableID: "EXT1", originX: 1440, originY: 0, width: 2560, height: 1440, isMain: false)

    /// Build a coordinator whose CaptureEngine/RestoreEngine run against the given fakes.
    private func makeCoordinator(displays: FakeDisplays, store: FakeAutoLayoutStore,
                                 notifier: FakeNotifier, windows: FakeWindows,
                                 workspace: FakeWorkspace, capturer: FakeCapturer)
        -> DockRestoreCoordinator {
        let capture = CaptureEngine(capture: capturer, displays: displays)
        let restore = RestoreEngine(workspace: workspace, windows: windows, displays: displays,
                                    clock: FakeClock(), timeout: 1, pollInterval: 0.1)
        return DockRestoreCoordinator(displays: displays, capture: capture, restore: restore,
                                      store: store, notifier: notifier,
                                      debounceInterval: 2.0, autosaveInterval: 45.0)
    }

    func test_changeToConfigWithSavedLayout_restoresAndNotifies() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()
        // Pre-seed a saved layout for the docked config.
        store.byKey["EXT1|builtin"] = Snapshot(name: "docked", createdAt: at(0),
            displays: [], windows: [WindowSnapshot(appBundleID: "com.a", appName: "A", title: "T",
                x: 0, y: 0, width: 100, height: 100, displayID: "EXT1", indexWithinApp: 0)])
        let notifier = FakeNotifier()
        let live = LiveWindow(handleID: 1, title: "T", indexWithinApp: 0)
        let windows = FakeWindows(eventual: ["com.a": [live]], appearAfter: ["com.a": 0])
        let workspace = FakeWorkspace(running: ["com.a"], installed: ["com.a"])
        let coord = makeCoordinator(displays: displays, store: store, notifier: notifier,
                                    windows: windows, workspace: workspace,
                                    capturer: FakeCapturer([]))
        coord.start(now: at(0))                       // baseline builtin, no restore
        displays.displays = [builtin, ext]            // dock
        coord.observeDisplaysChanged(now: at(1))
        coord.tick(now: at(3))                        // steady >= 2s -> emit + restore

        XCTAssertEqual(notifier.postedCount, 1)
        XCTAssertFalse(windows.setFrames.isEmpty)     // RestoreEngine placed the saved window
    }

    func test_changeToUnknownConfig_doesNotRestore() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()             // empty
        let notifier = FakeNotifier()
        let windows = FakeWindows()
        let coord = makeCoordinator(displays: displays, store: store, notifier: notifier,
                                    windows: windows, workspace: FakeWorkspace(),
                                    capturer: FakeCapturer([]))
        coord.start(now: at(0))
        displays.displays = [builtin, ext]
        coord.observeDisplaysChanged(now: at(1))
        coord.tick(now: at(3))

        XCTAssertEqual(notifier.postedCount, 0)
        XCTAssertTrue(windows.setFrames.isEmpty)
    }

    func test_undo_reappliesBaseline() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()
        store.byKey["EXT1|builtin"] = Snapshot(name: "docked", createdAt: at(0), displays: [],
            windows: [WindowSnapshot(appBundleID: "com.a", appName: "A", title: "T",
                x: 0, y: 0, width: 100, height: 100, displayID: "EXT1", indexWithinApp: 0)])
        // Capturer returns the current (pre-restore) window so the Undo baseline is non-empty.
        let capturer = FakeCapturer([CapturedWindow(bundleID: "com.a", appName: "A", title: "T",
            frame: Frame(x: 5, y: 5, width: 50, height: 50), indexWithinApp: 0)])
        let live = LiveWindow(handleID: 1, title: "T", indexWithinApp: 0)
        let windows = FakeWindows(eventual: ["com.a": [live]], appearAfter: ["com.a": 0])
        let coord = makeCoordinator(displays: displays, store: store, notifier: FakeNotifier(),
                                    windows: windows, workspace: FakeWorkspace(running: ["com.a"], installed: ["com.a"]),
                                    capturer: capturer)
        coord.start(now: at(0))
        displays.displays = [builtin, ext]
        coord.observeDisplaysChanged(now: at(1))
        coord.tick(now: at(3))                        // auto-restore, captures baseline
        let framesAfterRestore = windows.setFrames.count
        XCTAssertTrue(coord.undoLastRestore())        // re-applies baseline
        XCTAssertGreaterThan(windows.setFrames.count, framesAfterRestore)
        XCTAssertFalse(coord.undoLastRestore())       // second undo: nothing to undo
    }

    func test_autosave_savesCurrentConfigLayout() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()
        let capturer = FakeCapturer([CapturedWindow(bundleID: "com.a", appName: "A", title: "T",
            frame: Frame(x: 0, y: 0, width: 100, height: 100), indexWithinApp: 0)])
        let coord = makeCoordinator(displays: displays, store: store, notifier: FakeNotifier(),
                                    windows: FakeWindows(), workspace: FakeWorkspace(), capturer: capturer)
        coord.start(now: at(0))
        coord.tick(now: at(50))                       // >= 45s since start -> autosave due
        XCTAssertTrue(store.exists(forConfig: "builtin"))
    }

    func test_noOpChange_doesNothing() {
        let displays = FakeDisplays([builtin])
        let notifier = FakeNotifier()
        let coord = makeCoordinator(displays: displays, store: FakeAutoLayoutStore(), notifier: notifier,
                                    windows: FakeWindows(), workspace: FakeWorkspace(), capturer: FakeCapturer([]))
        coord.start(now: at(0))
        coord.observeDisplaysChanged(now: at(1))      // same config as baseline
        coord.tick(now: at(4))
        XCTAssertEqual(notifier.postedCount, 0)
    }

    func test_autosaveWithLayoutChange_ticksNotifier() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()
        // Previously saved layout has the window at x:0; current capture has it at x:200.
        store.byKey["builtin"] = Snapshot(name: "builtin", createdAt: at(0), displays: [],
            windows: [WindowSnapshot(appBundleID: "com.a", appName: "A", title: "Old",
                x: 0, y: 0, width: 100, height: 100, displayID: "builtin", indexWithinApp: 0)])
        let capturer = FakeCapturer([CapturedWindow(bundleID: "com.a", appName: "A", title: "Old",
            frame: Frame(x: 200, y: 0, width: 100, height: 100), indexWithinApp: 0)])
        let notifier = FakeNotifier()
        let coord = makeCoordinator(displays: displays, store: store, notifier: notifier,
                                    windows: FakeWindows(), workspace: FakeWorkspace(), capturer: capturer)
        coord.start(now: at(0))
        coord.tick(now: at(50))                       // autosave due; layout moved
        XCTAssertEqual(notifier.autosavedCount, 1)
        XCTAssertEqual(notifier.postedCount, 0)       // no restore notification
    }

    func test_autosaveTitleChurnOnly_staysQuiet() {
        let displays = FakeDisplays([builtin])
        let store = FakeAutoLayoutStore()
        // Same placement, different title -> not a layout change, no tick.
        store.byKey["builtin"] = Snapshot(name: "builtin", createdAt: at(0), displays: [],
            windows: [WindowSnapshot(appBundleID: "com.a", appName: "A", title: "Tab One",
                x: 0, y: 0, width: 100, height: 100, displayID: "builtin", indexWithinApp: 0)])
        let capturer = FakeCapturer([CapturedWindow(bundleID: "com.a", appName: "A", title: "Tab Two",
            frame: Frame(x: 0, y: 0, width: 100, height: 100), indexWithinApp: 0)])
        let notifier = FakeNotifier()
        let coord = makeCoordinator(displays: displays, store: store, notifier: notifier,
                                    windows: FakeWindows(), workspace: FakeWorkspace(), capturer: capturer)
        coord.start(now: at(0))
        coord.tick(now: at(50))                       // autosave due; only the title differs
        XCTAssertEqual(notifier.autosavedCount, 0)
    }
}

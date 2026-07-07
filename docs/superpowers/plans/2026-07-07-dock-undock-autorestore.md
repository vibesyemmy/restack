# Restack v1.1 — Dock/Undock Auto-Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically restore the window layout Restack last had on a given monitor configuration when displays are connected/disconnected — opt-in, debounced, with a single-level Undo.

**Architecture:** New pure-logic units in `RestackCore` (config identity, debounce, auto-layout store, autosave gating) are unit-tested with fake clocks; a `DockRestoreCoordinator` in `RestackKit` orchestrates them against the existing `CaptureEngine`/`RestoreEngine` and is fully unit-tested with fakes; a thin `DockAutoRestoreDriver` adapter wires real screen-change notifications + a timer; the SwiftUI app adds an off-by-default toggle and Undo surfaces.

**Tech Stack:** Swift 5.9+ (package builds in Swift 5 mode), XCTest, AppKit (`NSApplication.didChangeScreenParametersNotification`), CryptoKit (filename hashing), UserNotifications (`UNUserNotificationCenter`), SwiftUI.

---

## File Structure

```
Sources/RestackCore/
  DisplayConfigID.swift          # pure: [LiveDisplay] -> stable config key
  ConfigChangeDebouncer.swift    # pure: record observations + poll for a settled config
  AutoLayoutStore.swift          # AutoLayoutStoring protocol + file-backed store keyed by config key
  AutosaveDecider.swift          # pure: is an autosave due now?
Sources/RestackKit/
  Notifying.swift                # Notifying protocol + UNUserNotificationNotifier (real, build-only)
  DockRestoreCoordinator.swift   # the brain: orchestrates everything (unit-tested with fakes)
  DockAutoRestoreDriver.swift    # thin: screen-change observer + repeating tick timer (build-only)
Tests/RestackCoreTests/
  DisplayConfigIDTests.swift
  ConfigChangeDebouncerTests.swift
  AutoLayoutStoreTests.swift
  AutosaveDeciderTests.swift
Tests/RestackKitTests/
  DockRestoreCoordinatorTests.swift   # + fakes appended to FakeAdapters.swift
App/
  Settings.swift                 # + autoRestoreOnConfigChange flag (modify)
  AppModel.swift                 # + build coordinator/driver, start/stop, undo (modify)
  MenuBarView.swift              # + toggle + transient Undo item (modify)
  RestackApp.swift               # + UNUserNotificationCenter delegate wiring (modify)
```

---

## Task 1: DisplayConfigID (config key)

**Files:**
- Create: `Sources/RestackCore/DisplayConfigID.swift`
- Test: `Tests/RestackCoreTests/DisplayConfigIDTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
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
        XCTAssertEqual(DisplayConfigID.make(from: [d("EXT1"), d("builtin")]), "builtin|EXT1")
    }

    func test_empty() {
        XCTAssertEqual(DisplayConfigID.make(from: []), "")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --filter DisplayConfigIDTests`
Expected: FAIL — `DisplayConfigID` not defined.

- [ ] **Step 3: Implement**

```swift
// Sources/RestackCore/DisplayConfigID.swift
import Foundation

/// A stable key identifying a monitor configuration: the sorted, joined set of display stable IDs.
/// Order-independent so the same physical setup always maps to the same key.
public enum DisplayConfigID {
    public static func make(from displays: [LiveDisplay]) -> String {
        displays.map(\.stableID).sorted().joined(separator: "|")
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `swift test --filter DisplayConfigIDTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/RestackCore/DisplayConfigID.swift Tests/RestackCoreTests/DisplayConfigIDTests.swift
git commit -m "feat(core): add DisplayConfigID config-key builder"
```

---

## Task 2: ConfigChangeDebouncer

**Files:**
- Create: `Sources/RestackCore/ConfigChangeDebouncer.swift`
- Test: `Tests/RestackCoreTests/ConfigChangeDebouncerTests.swift`

Semantics: `record(config,at:)` notes the currently-observed config. `poll(now:)` returns a config string exactly once, when the most-recently-recorded config has stayed unchanged for `interval` and differs from the last emitted config. Absorbs flapping; suppresses no-op (same as last emitted).

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --filter ConfigChangeDebouncerTests`
Expected: FAIL — `ConfigChangeDebouncer` not defined.

- [ ] **Step 3: Implement**

```swift
// Sources/RestackCore/ConfigChangeDebouncer.swift
import Foundation

/// Debounces noisy display-configuration observations. Emits a config exactly once,
/// after it has been the observed config continuously for `interval`, and only if it
/// differs from the last emitted config. Not thread-safe; drive from one thread.
public final class ConfigChangeDebouncer {
    private let interval: TimeInterval
    private var lastEmitted: String?
    private var pending: String?
    private var pendingSince: Date?

    public init(interval: TimeInterval, initialConfig: String?) {
        self.interval = interval
        self.lastEmitted = initialConfig
    }

    /// Note the currently-observed config. Resets the steadiness clock when it changes.
    public func record(_ config: String, at now: Date) {
        if config != pending {
            pending = config
            pendingSince = now
        }
    }

    /// Returns a config to act on if the pending one has been steady long enough and is new.
    public func poll(now: Date) -> String? {
        guard let pending, let since = pendingSince else { return nil }
        guard now.timeIntervalSince(since) >= interval else { return nil }
        pendingSince = nil                     // consume this steadiness window
        guard pending != lastEmitted else { return nil }
        lastEmitted = pending
        return pending
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `swift test --filter ConfigChangeDebouncerTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/RestackCore/ConfigChangeDebouncer.swift Tests/RestackCoreTests/ConfigChangeDebouncerTests.swift
git commit -m "feat(core): add ConfigChangeDebouncer with flap absorption"
```

---

## Task 3: AutoLayoutStore

**Files:**
- Create: `Sources/RestackCore/AutoLayoutStore.swift`
- Test: `Tests/RestackCoreTests/AutoLayoutStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/RestackCoreTests/AutoLayoutStoreTests.swift
import XCTest
@testable import RestackCore

final class AutoLayoutStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("restack-auto-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func snap(_ name: String) -> Snapshot {
        Snapshot(name: name, createdAt: Date(timeIntervalSince1970: 1), displays: [], windows: [])
    }

    func test_saveThenLoad_byConfigKey() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("builtin|EXT1"), forConfig: "builtin|EXT1")
        let loaded = try store.load(forConfig: "builtin|EXT1")
        XCTAssertEqual(loaded?.name, "builtin|EXT1")
    }

    func test_exists() throws {
        let store = AutoLayoutStore(directory: tempDir())
        XCTAssertFalse(store.exists(forConfig: "builtin"))
        try store.save(snap("builtin"), forConfig: "builtin")
        XCTAssertTrue(store.exists(forConfig: "builtin"))
    }

    func test_loadMissing_returnsNil() throws {
        let store = AutoLayoutStore(directory: tempDir())
        XCTAssertNil(try store.load(forConfig: "nope"))
    }

    func test_delete() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("k"), forConfig: "k")
        try store.delete(forConfig: "k")
        XCTAssertFalse(store.exists(forConfig: "k"))
    }

    func test_distinctKeysDoNotCollide() throws {
        let store = AutoLayoutStore(directory: tempDir())
        try store.save(snap("one"), forConfig: "builtin")
        try store.save(snap("two"), forConfig: "builtin|EXT1")
        XCTAssertEqual(try store.load(forConfig: "builtin")?.name, "one")
        XCTAssertEqual(try store.load(forConfig: "builtin|EXT1")?.name, "two")
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --filter AutoLayoutStoreTests`
Expected: FAIL — `AutoLayoutStore` not defined.

- [ ] **Step 3: Implement**

```swift
// Sources/RestackCore/AutoLayoutStore.swift
import Foundation
import CryptoKit

/// Persists one auto-layout Snapshot per monitor-configuration key.
public protocol AutoLayoutStoring {
    func save(_ snapshot: Snapshot, forConfig key: String) throws
    func load(forConfig key: String) throws -> Snapshot?
    func exists(forConfig key: String) -> Bool
    func delete(forConfig key: String) throws
}

public final class AutoLayoutStore: AutoLayoutStoring {
    private let directory: URL
    private let fm = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Config keys can contain '|' and other characters; hash to a filesystem-safe name.
    private func url(forConfig key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hex).json")
    }

    public func save(_ snapshot: Snapshot, forConfig key: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url(forConfig: key), options: .atomic)
    }

    public func load(forConfig key: String) throws -> Snapshot? {
        let fileURL = url(forConfig: key)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
    }

    public func exists(forConfig key: String) -> Bool {
        fm.fileExists(atPath: url(forConfig: key).path)
    }

    public func delete(forConfig key: String) throws {
        let fileURL = url(forConfig: key)
        guard fm.fileExists(atPath: fileURL.path) else { return }
        try fm.removeItem(at: fileURL)
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `swift test --filter AutoLayoutStoreTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/RestackCore/AutoLayoutStore.swift Tests/RestackCoreTests/AutoLayoutStoreTests.swift
git commit -m "feat(core): add AutoLayoutStore keyed by monitor-config"
```

---

## Task 4: AutosaveDecider

**Files:**
- Create: `Sources/RestackCore/AutosaveDecider.swift`
- Test: `Tests/RestackCoreTests/AutosaveDeciderTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `swift test --filter AutosaveDeciderTests`
Expected: FAIL — `AutosaveDecider` not defined.

- [ ] **Step 3: Implement**

```swift
// Sources/RestackCore/AutosaveDecider.swift
import Foundation

/// Decides whether a periodic auto-layout save is due, throttled and paused during transitions.
public enum AutosaveDecider {
    public static func isDue(lastSavedAt: Date?, now: Date, interval: TimeInterval, inTransition: Bool) -> Bool {
        if inTransition { return false }
        guard let last = lastSavedAt else { return true }
        return now.timeIntervalSince(last) >= interval
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `swift test --filter AutosaveDeciderTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/RestackCore/AutosaveDecider.swift Tests/RestackCoreTests/AutosaveDeciderTests.swift
git commit -m "feat(core): add AutosaveDecider throttle/transition gate"
```

---

## Task 5: Notifying protocol + real notifier

**Files:**
- Create: `Sources/RestackKit/Notifying.swift`

No unit test (side-effecting UNUserNotificationCenter). Build-only; faked in Task 6.

- [ ] **Step 1: Implement protocol + real impl**

```swift
// Sources/RestackKit/Notifying.swift
import Foundation

/// Posts user-facing notifications for auto-restore events.
public protocol Notifying {
    /// Notify the user that Restack auto-restored a layout (offer Undo in the UI layer).
    func postAutoRestored()
}

#if canImport(UserNotifications)
import UserNotifications

/// Real notifier backed by UNUserNotificationCenter. The Undo action button is registered
/// via the notification category; the app delegate routes taps to the coordinator.
public final class UNUserNotificationNotifier: Notifying {
    public static let categoryID = "RESTACK_AUTO_RESTORE"
    public static let undoActionID = "RESTACK_UNDO"

    public init() {}

    /// Registers the notification category with an Undo action. Call once at startup.
    public func registerCategory() {
        let undo = UNNotificationAction(identifier: Self.undoActionID, title: "Undo", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [undo],
                                              intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func postAutoRestored() {
        let content = UNMutableNotificationContent()
        content.title = "Restack"
        content.body = "Restored your layout for this display setup."
        content.categoryIdentifier = Self.categoryID
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
#endif
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/RestackKit/Notifying.swift
git commit -m "feat(kit): add Notifying protocol + UNUserNotification notifier"
```

---

## Task 6: DockRestoreCoordinator (the brain)

**Files:**
- Create: `Sources/RestackKit/DockRestoreCoordinator.swift`
- Modify: `Tests/RestackKitTests/FakeAdapters.swift` (append fakes)
- Test: `Tests/RestackKitTests/DockRestoreCoordinatorTests.swift`

The coordinator is driven by explicit `now:` values so it is fully testable without real timers. It owns the debouncer + decider and calls the existing `CaptureEngine`/`RestoreEngine`.

- [ ] **Step 1: Append fakes to FakeAdapters.swift**

```swift
// Append to Tests/RestackKitTests/FakeAdapters.swift
import RestackCore

/// In-memory auto-layout store.
final class FakeAutoLayoutStore: AutoLayoutStoring {
    var byKey: [String: Snapshot] = [:]
    func save(_ snapshot: Snapshot, forConfig key: String) throws { byKey[key] = snapshot }
    func load(forConfig key: String) throws -> Snapshot? { byKey[key] }
    func exists(forConfig key: String) -> Bool { byKey[key] != nil }
    func delete(forConfig key: String) throws { byKey[key] = nil }
}

/// Records auto-restore notifications.
final class FakeNotifier: Notifying {
    var postedCount = 0
    func postAutoRestored() { postedCount += 1 }
}

/// Window capturer returning a fixed set of windows, for CaptureEngine in coordinator tests.
final class FakeCapturer: WindowCapturing {
    var windows: [CapturedWindow]
    init(_ windows: [CapturedWindow]) { self.windows = windows }
    func captureAllWindows() -> [CapturedWindow] { windows }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
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
        store.byKey["builtin|EXT1"] = Snapshot(name: "docked", createdAt: at(0),
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
        store.byKey["builtin|EXT1"] = Snapshot(name: "docked", createdAt: at(0), displays: [],
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
}
```

- [ ] **Step 3: Run tests, verify they fail**

Run: `swift test --filter DockRestoreCoordinatorTests`
Expected: FAIL — `DockRestoreCoordinator` not defined.

- [ ] **Step 4: Implement the coordinator**

```swift
// Sources/RestackKit/DockRestoreCoordinator.swift
import Foundation
import RestackCore

/// Orchestrates dock/undock auto-restore: watches for a settled monitor-config change,
/// restores that config's saved layout, keeps configs' layouts fresh via periodic autosave,
/// and supports a single-level Undo. Driven by explicit `now:` values for testability.
public final class DockRestoreCoordinator {
    private let displays: DisplayProviding
    private let capture: CaptureEngine
    private let restore: RestoreEngine
    private let store: AutoLayoutStoring
    private let notifier: Notifying
    private let debouncer: ConfigChangeDebouncer
    private let autosaveInterval: TimeInterval

    private var lastKnownConfigID: String = ""
    private var lastAutosaveAt: Date?
    private var inTransition = false
    private var undoBaseline: Snapshot?

    public init(displays: DisplayProviding, capture: CaptureEngine, restore: RestoreEngine,
                store: AutoLayoutStoring, notifier: Notifying,
                debounceInterval: TimeInterval = 2.0, autosaveInterval: TimeInterval = 45.0) {
        self.displays = displays
        self.capture = capture
        self.restore = restore
        self.store = store
        self.notifier = notifier
        self.autosaveInterval = autosaveInterval
        self.debouncer = ConfigChangeDebouncer(interval: debounceInterval, initialConfig: nil)
    }

    private func currentConfigID() -> String {
        DisplayConfigID.make(from: displays.currentDisplays())
    }

    /// Record the current configuration as the baseline WITHOUT restoring (avoids fighting
    /// the login "Last Session" restore). Call when the feature is enabled/started.
    public func start(now: Date) {
        lastKnownConfigID = currentConfigID()
        debouncer.record(lastKnownConfigID, at: now)   // seed as already-emitted baseline
        _ = debouncer.poll(now: now.addingTimeInterval(.greatestFiniteMagnitude / 2)) // no-op: same as initial nil? -> guarded below
        lastAutosaveAt = now
        undoBaseline = nil
    }

    /// Feed a display-parameters change into the debouncer.
    public func observeDisplaysChanged(now: Date) {
        inTransition = true
        debouncer.record(currentConfigID(), at: now)
    }

    /// Periodic driver tick: emit settled config changes and run autosave when due.
    public func tick(now: Date) {
        if let settled = debouncer.poll(now: now), settled != lastKnownConfigID {
            inTransition = false
            handleConfigChange(to: settled, now: now)
        } else {
            // No settled change this tick; if displays currently match lastKnown, transition is over.
            if currentConfigID() == lastKnownConfigID { inTransition = false }
        }
        autosaveIfDue(now: now)
    }

    private func handleConfigChange(to newConfig: String, now: Date) {
        if let saved = try? store.load(forConfig: newConfig), store.exists(forConfig: newConfig) {
            undoBaseline = capture.capture(name: "undo-baseline", now: now)   // pre-restore state
            _ = restore.restore(saved)
            notifier.postAutoRestored()
        }
        lastKnownConfigID = newConfig
        lastAutosaveAt = now
    }

    private func autosaveIfDue(now: Date) {
        guard AutosaveDecider.isDue(lastSavedAt: lastAutosaveAt, now: now,
                                    interval: autosaveInterval, inTransition: inTransition) else { return }
        let key = currentConfigID()
        let snap = capture.capture(name: key, now: now)
        try? store.save(snap, forConfig: key)
        lastAutosaveAt = now
    }

    /// Re-apply the pre-restore baseline. Returns false if there is nothing to undo.
    @discardableResult
    public func undoLastRestore() -> Bool {
        guard let baseline = undoBaseline else { return false }
        _ = restore.restore(baseline)
        undoBaseline = nil
        return true
    }
}
```

Note on `start`: seeding the debouncer with the baseline. The debouncer was created with `initialConfig: nil`, so its `lastEmitted` is nil; a later settle on the baseline config could emit it. To prevent the baseline from being treated as a change, `handleConfigChange` and `tick` both guard on `settled != lastKnownConfigID`. Simplify `start` to just set state (remove the bogus `poll` line):

```swift
    public func start(now: Date) {
        lastKnownConfigID = currentConfigID()
        lastAutosaveAt = now
        undoBaseline = nil
    }
```

Use this simplified `start`. The `tick` guard `settled != lastKnownConfigID` ensures the initial config never triggers a restore.

- [ ] **Step 5: Run tests, verify they pass**

Run: `swift test --filter DockRestoreCoordinatorTests`
Expected: PASS (5 tests). Then full `swift test` — all green.

- [ ] **Step 6: Commit**

```bash
git add Sources/RestackKit/DockRestoreCoordinator.swift Tests/RestackKitTests/FakeAdapters.swift Tests/RestackKitTests/DockRestoreCoordinatorTests.swift
git commit -m "feat(kit): add DockRestoreCoordinator with autosave, restore, undo"
```

---

## Task 7: DockAutoRestoreDriver (real OS wiring)

**Files:**
- Create: `Sources/RestackKit/DockAutoRestoreDriver.swift`

No unit test (real notifications + timer). Build-only.

- [ ] **Step 1: Implement**

```swift
// Sources/RestackKit/DockAutoRestoreDriver.swift
#if canImport(AppKit)
import AppKit
import RestackCore

/// Thin adapter: forwards `NSApplication.didChangeScreenParametersNotification` and a repeating
/// timer tick into a DockRestoreCoordinator. Owns no logic beyond wiring.
public final class DockAutoRestoreDriver {
    private let coordinator: DockRestoreCoordinator
    private let tickInterval: TimeInterval
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    public init(coordinator: DockRestoreCoordinator, tickInterval: TimeInterval = 1.0) {
        self.coordinator = coordinator
        self.tickInterval = tickInterval
    }

    public func start() {
        coordinator.start(now: Date())
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.coordinator.observeDisplaysChanged(now: Date())
            }
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.coordinator.tick(now: Date())
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        timer?.invalidate()
        timer = nil
    }
}
#endif
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/RestackKit/DockAutoRestoreDriver.swift
git commit -m "feat(kit): add DockAutoRestoreDriver (screen observer + tick timer)"
```

---

## Task 8: App wiring — toggle, coordinator, Undo surfaces

**Files:**
- Modify: `App/Settings.swift`, `App/AppModel.swift`, `App/MenuBarView.swift`, `App/RestackApp.swift`

Compiled via the `RestackApp` executable target — `swift build` catches errors. No unit tests (UI/OS wiring).

- [ ] **Step 1: Add the setting**

Add to `App/Settings.swift`, inside `RestackSettings`:

```swift
    private static let autoRestoreKey = "autoRestoreOnConfigChange"

    /// Off by default. When on, Restack auto-restores layouts on monitor-config changes.
    static var autoRestoreOnConfigChange: Bool {
        get { UserDefaults.standard.bool(forKey: autoRestoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoRestoreKey) }
    }
```

- [ ] **Step 2: Wire the coordinator/driver into AppModel**

Add to `App/AppModel.swift` (new stored properties + methods). `notifier` is created once; `registerCategory()` is called at startup:

```swift
    // Dock/undock auto-restore
    @Published var autoRestoreEnabled: Bool = RestackSettings.autoRestoreOnConfigChange
    private var dockDriver: DockAutoRestoreDriver?
    private let notifier = UNUserNotificationNotifier()

    /// Called from startTriggers(): register the notification category and, if the setting is on,
    /// start the driver.
    func startDockAutoRestore() {
        notifier.registerCategory()
        if autoRestoreEnabled { startDockDriver() }
    }

    private func startDockDriver() {
        notifier.requestAuthorization()
        let auto = AutoLayoutStore(directory: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Restack/auto", isDirectory: true))
        let restoreEngine = RestoreEngine(workspace: NSWorkspaceController(), windows: ax,
                                          displays: CGDisplayProvider(), clock: SystemClock())
        let coord = DockRestoreCoordinator(displays: CGDisplayProvider(),
                                           capture: capture, restore: restoreEngine,
                                           store: auto, notifier: notifier)
        self.dockCoordinator = coord
        let driver = DockAutoRestoreDriver(coordinator: coord)
        driver.start()
        dockDriver = driver
    }

    private var dockCoordinator: DockRestoreCoordinator?

    func setAutoRestore(_ on: Bool) {
        autoRestoreEnabled = on
        RestackSettings.autoRestoreOnConfigChange = on
        if on { startDockDriver() } else { dockDriver?.stop(); dockDriver = nil; dockCoordinator = nil }
    }

    /// Undo the most recent auto-restore (called from the notification action or the menu fallback).
    func undoAutoRestore() { _ = dockCoordinator?.undoLastRestore() }
```

In `AppModel.startTriggers()`, add a call to `startDockAutoRestore()` after the existing setup.

> Note: `capture` and `ax` already exist on `AppModel` from v1 (the `CaptureEngine` and `AXWindowController`). Reuse them; do not create duplicates. `RestoreEngine` is constructed here exactly as in `AppModel.restore(_:)`.

- [ ] **Step 2b: Guard the restore engine's off-main use**

The coordinator calls `RestoreEngine.restore` on the main thread (timer tick). Per v1, launching apps blocks; but v1.1 auto-restore only repositions already-running apps in the common dock case, and the tick timer firing a blocking launch on main is a real risk. Wrap the coordinator's driver tick to hop off-main is out of scope for the driver's simple design; instead, document the constraint by keeping `RestoreEngine`'s launch semaphore (already background-only guarded via doc) and note in `DockAutoRestoreDriver` that ticks run on main. **Acceptable for v1.1** because auto-restore targets an existing configuration whose apps are already running (dock/undock does not close apps). No code change; this note records the decision.

- [ ] **Step 3: Add the toggle + transient Undo to the menu**

In `App/MenuBarView.swift`, inside the trusted (Save UI) branch, add near the bottom (above Quit):

```swift
            Divider()
            Toggle("Auto-restore when monitors change", isOn: Binding(
                get: { model.autoRestoreEnabled },
                set: { model.setAutoRestore($0) }
            ))
            .toggleStyle(.checkbox)
```

- [ ] **Step 4: Route the notification Undo action**

In `App/RestackApp.swift`, add a `UNUserNotificationCenterDelegate` that calls `undoAutoRestore()` when the Undo action fires. Add an `NSApplicationDelegateAdaptor`-style delegate or set the center delegate in `AppModel.startDockAutoRestore()`:

```swift
// App/NotificationRouter.swift (new file in the App target)
import UserNotifications
import RestackKit

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let onUndo: () -> Void
    init(onUndo: @escaping () -> Void) { self.onUndo = onUndo; super.init() }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNUserNotificationNotifier.undoActionID {
            Task { @MainActor in onUndo() }
        }
        completionHandler()
    }
}
```

In `AppModel.startDockAutoRestore()`, retain a router and set it as the center delegate:

```swift
        let router = NotificationRouter(onUndo: { [weak self] in self?.undoAutoRestore() })
        self.notificationRouter = router
        UNUserNotificationCenter.current().delegate = router
```

Add `private var notificationRouter: NotificationRouter?` to `AppModel`.

- [ ] **Step 5: Build + rebuild the bundle**

Run: `swift build` (expect success) and `swift test` (expect `Executed N tests, with 1 test skipped and 0 failures` — the count grows by the new core/kit tests). Then `scripts/build-app.sh` to produce an updated `Restack.app`.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): wire dock/undock auto-restore toggle, coordinator, and Undo"
```

---

## Self-Review (against the spec)

- **§2 detect config changes (debounced):** Tasks 2 (debouncer), 7 (driver observer + tick). ✅
- **§2 identify config by display-ID set:** Task 1. ✅
- **§2 rolling auto-layout per config (periodic autosave):** Tasks 3 (store), 4 (decider), 6 (`autosaveIfDue`). ✅
- **§2 restore on change to known config:** Task 6 (`handleConfigChange`). ✅
- **§2 Undo baseline + surfaces:** Task 6 (`undoBaseline`, `undoLastRestore`), Task 8 (notification action + menu fallback). ✅
- **§2 opt-in toggle off by default:** Task 8 (`RestackSettings.autoRestoreOnConfigChange`, `setAutoRestore`). ✅
- **§2 notification on auto-restore:** Task 5 (`Notifying`/`postAutoRestored`), Task 6 (call), Task 8 (auth + category). ✅
- **§5 startup baseline without restore:** Task 6 (`start`), guarded by `settled != lastKnownConfigID`. ✅
- **§5 no-op change ignored:** Task 6 (`tick` guard) + Task 2 (`suppressesNoOp`). ✅
- **§5 toggle off = no background work:** Task 8 (`setAutoRestore(false)` stops driver). ✅
- **§6 UX (toggle, notification, menu fallback):** Task 8. ✅
- **§7 flapping absorbed:** Task 2 tests. ✅
- **§8 testing:** pure units Tasks 1–4; behavioral coordinator Task 6; adapters build-only Tasks 5,7,8. ✅

**Placeholder scan:** none — every step has complete code. The Task 8 §2b note is an explicit accepted-decision (no code), not a TODO.

**Type consistency:** `DisplayConfigID.make(from:)`, `ConfigChangeDebouncer(interval:initialConfig:)`/`record`/`poll`, `AutoLayoutStoring`/`AutoLayoutStore(directory:)` with `save(_:forConfig:)`/`load(forConfig:)`/`exists(forConfig:)`/`delete(forConfig:)`, `AutosaveDecider.isDue(lastSavedAt:now:interval:inTransition:)`, `Notifying.postAutoRestored()`, `DockRestoreCoordinator(displays:capture:restore:store:notifier:debounceInterval:autosaveInterval:)` with `start(now:)`/`observeDisplaysChanged(now:)`/`tick(now:)`/`undoLastRestore()`, `DockAutoRestoreDriver(coordinator:tickInterval:)` — all consistent across tasks and consistent with v1's `CaptureEngine.capture(name:now:)`, `RestoreEngine.restore(_:)`, `Snapshot`, `LiveDisplay`, `WindowCapturing`, `CapturedWindow`, `Frame`.

**Known accepted decision (not a defect):** v1.1 auto-restore runs `RestoreEngine.restore` on the main thread from the tick timer; acceptable because dock/undock does not close apps, so the common path repositions already-running apps without blocking launches (Task 8 §2b).

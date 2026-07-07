// Tests/RestackKitTests/FakeAdapters.swift
import Foundation
@testable import RestackKit
import RestackCore

final class FakeWorkspace: WorkspaceControlling {
    var running: Set<String>
    var installed: Set<String>
    var launched: [String] = []
    init(running: Set<String> = [], installed: Set<String> = []) {
        self.running = running; self.installed = installed
    }
    func runningBundleIDs() -> Set<String> { running }
    func isInstalled(bundleID: String) -> Bool { installed.contains(bundleID) }
    func launch(bundleID: String) -> Bool {
        guard installed.contains(bundleID) else { return false }
        launched.append(bundleID); running.insert(bundleID); return true
    }
}

final class FakeWindows: WindowControlling {
    /// bundleID -> the windows that will appear after `appearAfter` calls to windows(forBundleID:)
    var eventual: [String: [LiveWindow]]
    var appearAfter: [String: Int]
    private var calls: [String: Int] = [:]
    var setFrames: [(Frame, Int, String)] = []
    init(eventual: [String: [LiveWindow]] = [:], appearAfter: [String: Int] = [:]) {
        self.eventual = eventual; self.appearAfter = appearAfter
    }
    func windows(forBundleID bundleID: String) -> [LiveWindow] {
        calls[bundleID, default: 0] += 1
        let threshold = appearAfter[bundleID] ?? 0
        return (calls[bundleID] ?? 0) > threshold ? (eventual[bundleID] ?? []) : []
    }
    func setFrame(_ frame: Frame, forWindowHandle handle: Int, bundleID: String) {
        setFrames.append((frame, handle, bundleID))
    }
}

final class FakeDisplays: DisplayProviding {
    var displays: [LiveDisplay]
    init(_ displays: [LiveDisplay]) { self.displays = displays }
    func currentDisplays() -> [LiveDisplay] { displays }
}

final class FakeClock: Clock {
    private var t = Date(timeIntervalSince1970: 0)
    func now() -> Date { t }
    func sleep(_ interval: TimeInterval) { t = t.addingTimeInterval(interval) }
}

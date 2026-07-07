// Sources/RestackKit/RestoreEngine.swift
import Foundation
import RestackCore

public final class RestoreEngine {
    private let workspace: WorkspaceControlling
    private let windows: WindowControlling
    private let displays: DisplayProviding
    private let waiter: WindowWaiter

    public init(workspace: WorkspaceControlling, windows: WindowControlling,
                displays: DisplayProviding, clock: Clock,
                timeout: TimeInterval = 8.0, pollInterval: TimeInterval = 0.25) {
        self.workspace = workspace; self.windows = windows; self.displays = displays
        self.waiter = WindowWaiter(windows: windows, clock: clock,
                                   timeout: timeout, pollInterval: pollInterval)
    }

    @discardableResult
    public func restore(_ snapshot: Snapshot) -> RestoreSummary {
        var summary = RestoreSummary(totalWindows: snapshot.windows.count)
        let available = displays.currentDisplays()
        let plan = RestorePlanner.plan(snapshot: snapshot,
                                       runningBundleIDs: workspace.runningBundleIDs())

        for appPlan in plan.appPlans {
            // Launch if needed.
            if appPlan.needsLaunch {
                guard workspace.isInstalled(bundleID: appPlan.bundleID),
                      workspace.launch(bundleID: appPlan.bundleID) else {
                    for _ in appPlan.windows {
                        summary.recordSkipped(app: appPlan.bundleID, reason: "app not installed")
                    }
                    continue
                }
            }
            // Wait for windows.
            var live = waiter.waitForWindows(bundleID: appPlan.bundleID)
            if live.isEmpty {
                // Apps like browsers keep running after their last window closes, so the
                // app is "running" but windowless and there is nothing to place. Re-opening
                // it fires macOS's reopen event, which makes such apps create a new window.
                _ = workspace.launch(bundleID: appPlan.bundleID)
                live = waiter.waitForWindows(bundleID: appPlan.bundleID)
            }
            if live.isEmpty {
                for _ in appPlan.windows {
                    summary.recordSkipped(app: appPlan.bundleID, reason: "no windows appeared")
                }
                continue
            }
            // Match saved slots to live windows.
            let pairs = WindowMatcher.match(saved: appPlan.windows, live: live)
            let matchedSlots = Set(pairs.map(\.saved.indexWithinApp))
            for pair in pairs {
                let frame = DisplayResolver.resolve(slot: pair.saved, available: available)
                windows.setFrame(frame, forWindowHandle: pair.live.handleID, bundleID: appPlan.bundleID)
                summary.recordPlaced()
            }
            for slot in appPlan.windows where !matchedSlots.contains(slot.indexWithinApp) {
                summary.recordSkipped(app: appPlan.bundleID, reason: "no matching window")
            }
        }
        return summary
    }
}

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
        if let saved = try? store.load(forConfig: newConfig) {
            undoBaseline = capture.capture(name: "undo-baseline", now: now)   // pre-restore state
            let summary = restore.restore(saved)
            notifier.postAutoRestored()
            notifier.postActivity(ActivityEvent(
                timestamp: now, trigger: .monitorChange, configID: newConfig,
                snapshotName: saved.name, placed: summary.placedCount, total: summary.totalWindows,
                skips: summary.skipped.map { "\($0.app): \($0.reason)" }))
        }
        lastKnownConfigID = newConfig
        lastAutosaveAt = now
    }

    private func autosaveIfDue(now: Date) {
        guard AutosaveDecider.isDue(lastSavedAt: lastAutosaveAt, now: now,
                                    interval: autosaveInterval, inTransition: inTransition) else { return }
        let key = currentConfigID()
        let snap = capture.capture(name: key, now: now)
        let previous = try? store.load(forConfig: key)
        try? store.save(snap, forConfig: key)
        // Quiet UI tick when the saved layout actually changed (first capture counts —
        // it's the "setup captured, safe to unplug" signal). Title churn never fires this.
        if previous == nil || LayoutDiff.layoutChanged(previous!, snap) {
            notifier.postLayoutAutosaved()
            notifier.postActivity(ActivityEvent(
                timestamp: now, trigger: .autosave, configID: key,
                snapshotName: key, placed: snap.windows.count, total: snap.windows.count))
        }
        lastAutosaveAt = now
    }

    /// Re-apply the pre-restore baseline. Returns false if there is nothing to undo.
    @discardableResult
    public func undoLastRestore(now: Date = Date()) -> Bool {
        guard let baseline = undoBaseline else { return false }
        let summary = restore.restore(baseline)
        undoBaseline = nil
        notifier.postActivity(ActivityEvent(
            timestamp: now, trigger: .undo, configID: lastKnownConfigID,
            snapshotName: baseline.name, placed: summary.placedCount, total: summary.totalWindows,
            skips: summary.skipped.map { "\($0.app): \($0.reason)" }))
        return true
    }
}

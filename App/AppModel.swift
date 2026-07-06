// App/AppModel.swift
import Foundation
import AppKit
import RestackCore
import RestackKit
import ApplicationServices

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [Snapshot] = []
    @Published var lastSummary: RestoreSummary?

    private let store: SnapshotStore
    private let capture: CaptureEngine
    private let ax = AXWindowController()
    private var isRestoring = false

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Restack/snapshots", isDirectory: true)
        self.store = SnapshotStore(directory: dir)
        self.capture = CaptureEngine(capture: ax, displays: CGDisplayProvider())
        refresh()
        startTriggers()
    }

    func refresh() { snapshots = (try? store.list()) ?? [] }

    func save(name: String) {
        let snap = capture.capture(name: name, now: Date())
        try? store.save(snap)
        refresh()
    }

    /// Runs the (potentially multi-second) restore off the main thread.
    ///
    /// `RestoreEngine.restore` launches apps and polls for their windows via
    /// `NSWorkspaceController.launch`, which blocks its calling thread on a semaphore
    /// while waiting for `NSWorkspace.openApplication` to complete, and `WindowWaiter`
    /// then sleeps/polls synchronously. Calling this directly from a SwiftUI button
    /// action on the main thread would hang the UI (and risks deadlocking if the
    /// completion handler itself needs the main thread). Dispatch the engine work to a
    /// background queue and publish the result back on the main actor.
    func restore(_ snapshot: Snapshot) {
        guard !isRestoring else { return }
        isRestoring = true
        let ax = self.ax
        DispatchQueue.global(qos: .userInitiated).async {
            let engine = RestoreEngine(workspace: NSWorkspaceController(), windows: ax,
                                       displays: CGDisplayProvider(), clock: SystemClock())
            let summary = engine.restore(snapshot)
            DispatchQueue.main.async { [weak self] in
                self?.lastSummary = summary
                self?.refresh()
                self?.isRestoring = false
            }
        }
    }

    func delete(_ snapshot: Snapshot) { try? store.delete(id: snapshot.id); refresh() }
}

// MARK: - Accessibility trust

extension AppModel {
    var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

    func promptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}

// MARK: - Triggers (auto-save on quit, auto-restore on login)

extension AppModel {
    func saveLastSession(reusing id: UUID?) {
        var snap = capture.capture(name: RestackSettings.lastSessionName, now: Date())
        if let id { snap.id = id }
        try? store.save(snap)
        refresh()
    }

    /// Registers the login item, installs the auto-save-on-quit observer, and schedules
    /// the delayed login-restore.
    ///
    /// This lives on `AppModel` rather than in `RestackApp.init()` because `@StateObject`
    /// wrappers are not accessible inside a SwiftUI `App`'s `init()` (the state object
    /// isn't installed yet), so `model` can't be captured there. Calling this once from
    /// `AppModel.init()` (after `refresh()`) gives identical runtime behavior and compiles
    /// cleanly.
    func startTriggers() {
        Triggers.setLaunchAtLogin(true)

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Triggers.autoSaveLastSession(model: self)
            }
        }

        // Auto-restore shortly after launch (windows/services settle).
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                Triggers.restoreOnLoginIfNeeded(model: self)
            }
        }
    }
}

// App/AppModel.swift
import Foundation
import AppKit
@preconcurrency import RestackCore
import RestackKit
import ApplicationServices
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshots: [Snapshot] = []
    @Published var lastSummary: RestoreSummary?
    @Published var isTrusted: Bool = AXIsProcessTrusted()

    private let store: SnapshotStore
    private let capture: CaptureEngine
    private let ax = AXWindowController()
    private var isRestoring = false
    private var permissionWatchTimer: Timer?

    // Dock/undock auto-restore
    @Published var autoRestoreEnabled: Bool = RestackSettings.autoRestoreOnConfigChange
    private var dockDriver: DockAutoRestoreDriver?
    private var dockCoordinator: DockRestoreCoordinator?
    private var notificationRouter: NotificationRouter?
    private let notifier = UNUserNotificationNotifier()

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

// MARK: - Dock/undock auto-restore

extension AppModel {
    /// Called from startTriggers(): register the notification category and, if the setting is
    /// on, start the driver.
    func startDockAutoRestore() {
        notifier.registerCategory()
        let router = NotificationRouter(onUndo: { [weak self] in self?.undoAutoRestore() })
        self.notificationRouter = router
        UNUserNotificationCenter.current().delegate = router
        if autoRestoreEnabled { startDockDriver() }
    }

    /// Builds a dedicated `AXWindowController` + engines for the coordinator so its
    /// capture/restore traffic never races with a manual `restore(_:)` call on the shared
    /// `ax` controller used elsewhere in `AppModel`.
    private func startDockDriver() {
        dockDriver?.stop()            // idempotent: never leave a prior driver's timer/observer running
        notifier.requestAuthorization()
        let dockAX = AXWindowController()
        let dockCapture = CaptureEngine(capture: dockAX, displays: CGDisplayProvider())
        let dockRestore = RestoreEngine(workspace: NSWorkspaceController(), windows: dockAX,
                                        displays: CGDisplayProvider(), clock: SystemClock())
        let auto = AutoLayoutStore(directory: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Restack/auto", isDirectory: true))
        let coord = DockRestoreCoordinator(displays: CGDisplayProvider(),
                                           capture: dockCapture, restore: dockRestore,
                                           store: auto, notifier: notifier)
        self.dockCoordinator = coord
        let driver = DockAutoRestoreDriver(coordinator: coord)
        driver.start()
        dockDriver = driver
    }

    func setAutoRestore(_ on: Bool) {
        autoRestoreEnabled = on
        RestackSettings.autoRestoreOnConfigChange = on
        if on {
            startDockDriver()
        } else {
            dockDriver?.stop()
            dockDriver = nil
            dockCoordinator = nil
        }
    }

    /// Undo the most recent auto-restore. Always routes through the driver's serial queue
    /// so Undo never races with an in-flight tick.
    func undoAutoRestore() { dockDriver?.requestUndo() }
}

// MARK: - Accessibility trust

extension AppModel {
    func promptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    /// Polls `AXIsProcessTrusted()` on a ~1s timer so the UI can react to permission
    /// being granted while the app is running, without requiring a relaunch. Only
    /// runs while untrusted; stops itself the moment trust is detected.
    func startPermissionWatch() {
        guard !isTrusted else { return }
        guard permissionWatchTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.isTrusted = true
                    self.permissionWatchTimer?.invalidate()
                    self.permissionWatchTimer = nil
                }
            }
        }
        permissionWatchTimer = timer
        RunLoop.main.add(timer, forMode: .common)
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
        startPermissionWatch()
        startDockAutoRestore()

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

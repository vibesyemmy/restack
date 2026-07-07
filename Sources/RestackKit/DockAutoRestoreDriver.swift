// Sources/RestackKit/DockAutoRestoreDriver.swift
#if canImport(AppKit)
import AppKit
import RestackCore

/// Thin adapter: forwards `NSApplication.didChangeScreenParametersNotification` and a repeating
/// timer tick into a DockRestoreCoordinator. Owns no logic beyond wiring.
///
/// All coordinator access is funneled through a dedicated serial background queue, never the
/// main thread: `RestoreEngine.restore` (invoked deep inside the coordinator) can block while
/// waiting for apps to launch and windows to appear, and running that on main would hang the UI.
/// The screen-parameters observer and the repeating timer are still registered on the main
/// run loop (required by `NotificationCenter`/`Timer`), but their closures immediately hop onto
/// `queue` before touching the coordinator, so all coordinator state stays single-threaded.
public final class DockAutoRestoreDriver {
    private let coordinator: DockRestoreCoordinator
    private let tickInterval: TimeInterval
    private let queue = DispatchQueue(label: "com.restack.dock-autorestore")
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    public init(coordinator: DockRestoreCoordinator, tickInterval: TimeInterval = 1.0) {
        self.coordinator = coordinator
        self.tickInterval = tickInterval
    }

    public func start() {
        queue.async { [weak self] in
            self?.coordinator.start(now: Date())
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.queue.async { self?.coordinator.observeDisplaysChanged(now: Date()) }
            }
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.queue.async { self?.coordinator.tick(now: Date()) }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    /// Re-apply the pre-restore baseline on the same serial queue as ticks, so Undo never
    /// races with an in-flight tick.
    public func requestUndo() {
        queue.async { [weak self] in
            _ = self?.coordinator.undoLastRestore()
        }
    }

    public func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        timer?.invalidate()
        timer = nil
    }
}
#endif

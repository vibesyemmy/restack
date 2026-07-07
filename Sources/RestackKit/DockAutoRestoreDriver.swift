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

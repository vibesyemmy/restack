// Sources/RestackKit/WindowWaiter.swift
import Foundation
import RestackCore

public final class WindowWaiter {
    private let windows: WindowControlling
    private let clock: Clock
    private let timeout: TimeInterval
    private let pollInterval: TimeInterval

    public init(windows: WindowControlling, clock: Clock,
                timeout: TimeInterval = 8.0, pollInterval: TimeInterval = 0.25) {
        self.windows = windows; self.clock = clock
        self.timeout = timeout; self.pollInterval = pollInterval
    }

    /// Poll until the app reports at least one window, or the timeout elapses.
    public func waitForWindows(bundleID: String) -> [LiveWindow] {
        let deadline = clock.now().addingTimeInterval(timeout)
        while true {
            let found = windows.windows(forBundleID: bundleID)
            if !found.isEmpty { return found }
            if clock.now() >= deadline { return [] }
            clock.sleep(pollInterval)
        }
    }
}

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

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

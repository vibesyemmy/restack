// Sources/RestackCore/WindowMatcher.swift
import Foundation

public struct WindowPair: Equatable {
    public let saved: WindowSnapshot
    public let live: LiveWindow
}

public enum WindowMatcher {
    /// Match saved window slots to live windows of the SAME app.
    /// Pass 1: exact title match (each live window consumed once).
    /// Pass 2: remaining saved slots take remaining live windows in index order.
    public static func match(saved: [WindowSnapshot], live: [LiveWindow]) -> [WindowPair] {
        var remainingLive = live.sorted { $0.indexWithinApp < $1.indexWithinApp }
        var pairs: [WindowPair] = []
        var unmatchedSaved: [WindowSnapshot] = []

        // Pass 1: exact title.
        for slot in saved.sorted(by: { $0.indexWithinApp < $1.indexWithinApp }) {
            if let i = remainingLive.firstIndex(where: { $0.title == slot.title }) {
                pairs.append(WindowPair(saved: slot, live: remainingLive.remove(at: i)))
            } else {
                unmatchedSaved.append(slot)
            }
        }
        // Pass 2: order fallback.
        for slot in unmatchedSaved {
            guard !remainingLive.isEmpty else { break }
            pairs.append(WindowPair(saved: slot, live: remainingLive.removeFirst()))
        }
        return pairs
    }
}

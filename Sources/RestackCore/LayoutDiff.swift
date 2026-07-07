// Sources/RestackCore/LayoutDiff.swift
import Foundation

/// Compares two snapshots by LAYOUT only: the multiset of (app, frame, display) window
/// placements. Window titles, snapshot names, ids, and timestamps are ignored — title
/// churn (e.g. switching browser tabs) must never register as a layout change.
public enum LayoutDiff {
    public static func layoutChanged(_ a: Snapshot, _ b: Snapshot) -> Bool {
        placementKeys(a) != placementKeys(b)
    }

    /// Sorted (not Set) so duplicate identical placements keep their multiplicity.
    private static func placementKeys(_ s: Snapshot) -> [String] {
        s.windows.map { w in
            "\(w.appBundleID)|\(w.displayID)|\(w.x)|\(w.y)|\(w.width)|\(w.height)"
        }.sorted()
    }
}

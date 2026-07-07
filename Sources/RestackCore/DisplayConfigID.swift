// Sources/RestackCore/DisplayConfigID.swift
import Foundation

/// A stable key identifying a monitor configuration: the sorted, joined set of display stable IDs.
/// Order-independent so the same physical setup always maps to the same key.
public enum DisplayConfigID {
    public static func make(from displays: [LiveDisplay]) -> String {
        displays.map(\.stableID).sorted().joined(separator: "|")
    }
}

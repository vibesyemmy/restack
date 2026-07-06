// Sources/RestackCore/DisplayResolver.swift
import Foundation

public struct Frame: Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public enum DisplayResolver {
    /// Resolve a saved window slot to a concrete target frame given the displays available NOW.
    /// If the saved display is still present, return the saved frame unchanged.
    /// If it is gone, clamp (and if needed shrink) the window to fit the main display.
    public static func resolve(slot: WindowSnapshot, available: [LiveDisplay]) -> Frame {
        if available.contains(where: { $0.stableID == slot.displayID }) {
            return Frame(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
        }
        let target = available.first(where: { $0.isMain }) ?? available.first
        guard let d = target else {
            return Frame(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
        }
        let w = min(slot.width, d.width)
        let h = min(slot.height, d.height)
        let x = clamp(slot.x, lower: d.originX, upper: d.originX + d.width - w)
        let y = clamp(slot.y, lower: d.originY, upper: d.originY + d.height - h)
        return Frame(x: x, y: y, width: w, height: h)
    }

    private static func clamp(_ v: Double, lower: Double, upper: Double) -> Double {
        max(lower, min(v, max(lower, upper)))
    }
}

// Sources/RestackKit/DisplayProviding.swift
import RestackCore

public protocol DisplayProviding {
    func currentDisplays() -> [LiveDisplay]
}

#if canImport(AppKit)
import AppKit
import CoreGraphics

public final class CGDisplayProvider: DisplayProviding {
    public init() {}
    public func currentDisplays() -> [LiveDisplay] {
        let mainID = CGMainDisplayID()
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.map { id in
            let b = CGDisplayBounds(id)
            // Stable per-monitor identity: prefer serial+vendor+model; fall back to CGDisplay UUID.
            let stable = displayStableID(id)
            return LiveDisplay(stableID: stable, originX: b.origin.x, originY: b.origin.y,
                               width: b.size.width, height: b.size.height, isMain: id == mainID)
        }
    }

    private func displayStableID(_ id: CGDirectDisplayID) -> String {
        let vendor = CGDisplayVendorNumber(id), model = CGDisplayModelNumber(id), serial = CGDisplaySerialNumber(id)
        if vendor != 0 || model != 0 || serial != 0 { return "V\(vendor)-M\(model)-S\(serial)" }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "CG\(id)"
    }
}
#endif

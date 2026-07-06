// Sources/RestackKit/CaptureEngine.swift
import Foundation
import RestackCore

public final class CaptureEngine {
    private let capture: WindowCapturing
    private let displays: DisplayProviding

    public init(capture: WindowCapturing, displays: DisplayProviding) {
        self.capture = capture; self.displays = displays
    }

    public func capture(name: String, now: Date) -> Snapshot {
        let liveDisplays = displays.currentDisplays()
        let displaySnaps = liveDisplays.map {
            DisplaySnapshot(stableID: $0.stableID, width: $0.width, height: $0.height,
                            originX: $0.originX, originY: $0.originY)
        }
        let windows = capture.captureAllWindows().map { w -> WindowSnapshot in
            let displayID = displayContaining(frame: w.frame, in: liveDisplays)
            return WindowSnapshot(appBundleID: w.bundleID, appName: w.appName, title: w.title,
                                  x: w.frame.x, y: w.frame.y, width: w.frame.width, height: w.frame.height,
                                  displayID: displayID, indexWithinApp: w.indexWithinApp)
        }
        return Snapshot(name: name, createdAt: now, displays: displaySnaps, windows: windows)
    }

    /// Choose the display whose bounds contain the window's center; fall back to main/first.
    private func displayContaining(frame: Frame, in displays: [LiveDisplay]) -> String {
        let cx = frame.x + frame.width / 2, cy = frame.y + frame.height / 2
        if let hit = displays.first(where: {
            cx >= $0.originX && cx < $0.originX + $0.width &&
            cy >= $0.originY && cy < $0.originY + $0.height
        }) { return hit.stableID }
        return (displays.first(where: \.isMain) ?? displays.first)?.stableID ?? ""
    }
}

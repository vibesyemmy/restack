// Sources/RestackKit/WindowControlling.swift
import RestackCore

/// Reads/moves windows of other apps. Handle is opaque (adapter-defined).
public protocol WindowControlling {
    /// Live windows for a running app, in enumeration order.
    func windows(forBundleID bundleID: String) -> [LiveWindow]
    /// Move/resize a window identified by its handle to a frame (global coords, top-left origin).
    func setFrame(_ frame: Frame, forWindowHandle handle: Int, bundleID: String)
}

public struct CapturedWindow: Equatable {
    public let bundleID: String
    public let appName: String
    public let title: String
    public let frame: Frame
    public let indexWithinApp: Int
    public init(bundleID: String, appName: String, title: String,
                frame: Frame, indexWithinApp: Int) {
        self.bundleID = bundleID; self.appName = appName; self.title = title
        self.frame = frame; self.indexWithinApp = indexWithinApp
    }
}

public protocol WindowCapturing {
    /// All on-screen windows of all regular running apps, with global frames.
    func captureAllWindows() -> [CapturedWindow]
}

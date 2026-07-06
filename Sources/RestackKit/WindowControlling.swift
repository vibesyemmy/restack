// Sources/RestackKit/WindowControlling.swift
import RestackCore

/// Reads/moves windows of other apps. Handle is opaque (adapter-defined).
public protocol WindowControlling {
    /// Live windows for a running app, in enumeration order.
    func windows(forBundleID bundleID: String) -> [LiveWindow]
    /// Move/resize a window identified by its handle to a frame (global coords, top-left origin).
    func setFrame(_ frame: Frame, forWindowHandle handle: Int, bundleID: String)
}

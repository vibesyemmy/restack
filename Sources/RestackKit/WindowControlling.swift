// Sources/RestackKit/WindowControlling.swift
import RestackCore

/// Reads/moves windows of other apps. Handle is opaque (adapter-defined).
public protocol WindowControlling {
    /// Live windows for a running app, in enumeration order.
    func windows(forBundleID bundleID: String) -> [LiveWindow]
    /// Move/resize a window identified by its handle to a frame (global coords, top-left origin).
    ///
    /// Handles are only valid until the next `windows(forBundleID:)` call for that bundle;
    /// `setFrame` operates on the elements captured by the most recent `windows(forBundleID:)`
    /// call for the given `bundleID`.
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

#if canImport(AppKit)
import AppKit
import ApplicationServices

public final class AXWindowController: WindowControlling, WindowCapturing {
    public init() {}

    /// Cache of the exact `AXUIElement`s returned by the most recent `windows(forBundleID:)`
    /// call for each bundle ID, keyed by bundleID. `setFrame` indexes into this cache by
    /// handle rather than re-enumerating the app's AX windows, to avoid a TOCTOU race where
    /// the window list changes between `windows(forBundleID:)` and `setFrame`.
    private var handleCache: [String: [AXUIElement]] = [:]

    private func axWindows(forBundleID bundleID: String) -> [(el: AXUIElement, title: String)] {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) else { return [] }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.map { ($0, axString($0, kAXTitleAttribute) ?? "") }
    }

    public func windows(forBundleID bundleID: String) -> [LiveWindow] {
        let elements = axWindows(forBundleID: bundleID)
        handleCache[bundleID] = elements.map(\.el)
        return elements.enumerated().map { idx, w in
            LiveWindow(handleID: idx, title: w.title, indexWithinApp: idx)
        }
    }

    /// Moves/resizes the window identified by `handle`, using the `AXUIElement` captured by
    /// the most recent `windows(forBundleID:)` call for this `bundleID` (does not re-enumerate).
    public func setFrame(_ frame: Frame, forWindowHandle handle: Int, bundleID: String) {
        guard let els = handleCache[bundleID], handle >= 0, handle < els.count else { return }
        let el = els[handle]
        var size = CGSize(width: frame.width, height: frame.height)
        var pos = CGPoint(x: frame.x, y: frame.y)
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sizeVal)
        }
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, posVal)
        }
    }

    public func captureAllWindows() -> [CapturedWindow] {
        var out: [CapturedWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier else { continue }
            let name = app.localizedName ?? bundleID
            for (idx, w) in axWindows(forBundleID: bundleID).enumerated() {
                guard let frame = axFrame(w.el) else { continue }
                out.append(CapturedWindow(bundleID: bundleID, appName: name, title: w.title,
                                          frame: frame, indexWithinApp: idx))
            }
        }
        return out
    }

    private func axString(_ el: AXUIElement, _ attr: String) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v as? String
    }
    private func axFrame(_ el: AXUIElement) -> Frame? {
        var posV: CFTypeRef?, sizeV: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posV) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeV) == .success,
              let posRef = posV, CFGetTypeID(posRef) == AXValueGetTypeID(),
              let sizeRef = sizeV, CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        let posValue = posRef as! AXValue
        let sizeValue = sizeRef as! AXValue
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posValue, .cgPoint, &point)
        AXValueGetValue(sizeValue, .cgSize, &size)
        return Frame(x: point.x, y: point.y, width: size.width, height: size.height)
    }
}
#endif

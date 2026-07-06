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

#if canImport(AppKit)
import AppKit
import ApplicationServices

public final class AXWindowController: WindowControlling, WindowCapturing {
    public init() {}

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
        axWindows(forBundleID: bundleID).enumerated().map { idx, w in
            LiveWindow(handleID: idx, title: w.title, indexWithinApp: idx)
        }
    }

    public func setFrame(_ frame: Frame, forWindowHandle handle: Int, bundleID: String) {
        let wins = axWindows(forBundleID: bundleID)
        guard handle >= 0, handle < wins.count else { return }
        let el = wins[handle].el
        var pos = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)
        if let posVal = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(el, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(el, kAXSizeAttribute as CFString, sizeVal)
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
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeV) == .success
        else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posV as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeV as! AXValue, .cgSize, &size)
        return Frame(x: point.x, y: point.y, width: size.width, height: size.height)
    }
}
#endif

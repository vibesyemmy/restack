// Sources/RestackKit/WorkspaceControlling.swift
import RestackCore

public protocol WorkspaceControlling {
    func runningBundleIDs() -> Set<String>
    func isInstalled(bundleID: String) -> Bool
    /// Launch an app; returns false if it cannot be launched (e.g. not installed).
    func launch(bundleID: String) -> Bool
}

#if canImport(AppKit)
import AppKit

public final class NSWorkspaceController: WorkspaceControlling {
    public init() {}
    public func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.bundleIdentifier })
    }
    public func isInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
    public func launch(bundleID: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        var ok = true
        let sem = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, err in
            ok = (err == nil); sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
        return ok
    }
}
#endif

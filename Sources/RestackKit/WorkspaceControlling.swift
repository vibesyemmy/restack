// Sources/RestackKit/WorkspaceControlling.swift
import RestackCore

public protocol WorkspaceControlling {
    func runningBundleIDs() -> Set<String>
    func isInstalled(bundleID: String) -> Bool
    /// Launch an app; returns false if it cannot be launched (e.g. not installed).
    func launch(bundleID: String) -> Bool
}

// App/Settings.swift
import Foundation

enum RestackSettings {
    private static let key = "loginRestoreSnapshotID"
    static let lastSessionName = "Last Session"

    /// Which snapshot restores on login. nil => the auto-maintained "Last Session".
    static var loginTargetID: UUID? {
        get { UserDefaults.standard.string(forKey: key).flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: key) }
    }

    private static let autoRestoreKey = "autoRestoreOnConfigChange"

    /// Off by default. When on, Restack auto-restores layouts on monitor-config changes.
    static var autoRestoreOnConfigChange: Bool {
        get { UserDefaults.standard.bool(forKey: autoRestoreKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoRestoreKey) }
    }
}

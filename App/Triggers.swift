// App/Triggers.swift
import AppKit
import ServiceManagement
import RestackCore

@MainActor
enum Triggers {
    /// Register/unregister the app as a login item so it can auto-restore after reboot.
    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { NSLog("Restack login item error: \(error)") }
    }

    /// Overwrite the "Last Session" snapshot from the current setup.
    static func autoSaveLastSession(model: AppModel) {
        // Reuse an existing "Last Session" id if present so it stays a single rolling snapshot.
        let existing = model.snapshots.first { $0.name == RestackSettings.lastSessionName }
        model.saveLastSession(reusing: existing?.id)
    }

    /// On launch, if this was a login launch, restore the configured target.
    static func restoreOnLoginIfNeeded(model: AppModel) {
        let target: Snapshot?
        if let id = RestackSettings.loginTargetID {
            target = model.snapshots.first { $0.id == id }
        } else {
            target = model.snapshots.first { $0.name == RestackSettings.lastSessionName }
        }
        if let snap = target { model.restore(snap) }
    }
}

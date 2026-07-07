// App/RestackApp.swift
import SwiftUI

@main
struct RestackApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            // Pulses briefly after an auto-restore; bounces once per layout autosave.
            if #available(macOS 14.0, *) {
                Image(systemName: "square.stack.3d.up")
                    .symbolEffect(.pulse, options: .repeating, isActive: model.restorePulse)
                    .symbolEffect(.bounce, value: model.saveBounce)
            } else {
                // macOS 13 fallback: no symbol effects; swap to the filled variant instead.
                Image(systemName: model.restorePulse ? "square.stack.3d.up.fill" : "square.stack.3d.up")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

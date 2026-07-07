// App/RestackApp.swift
import SwiftUI

@main
struct RestackApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            // Rotating arrows while a restore is in flight; pulses briefly after an
            // auto-restore; bounces once per layout autosave.
            if #available(macOS 14.0, *) {
                Image(systemName: model.isRestoringNow
                        ? "arrow.triangle.2.circlepath" : "square.stack.3d.up")
                    .symbolEffect(.pulse, options: .repeating,
                                  isActive: model.isRestoringNow || model.restorePulse)
                    .symbolEffect(.bounce, value: model.saveBounce)
            } else {
                // macOS 13 fallback: no symbol effects; swap symbols only.
                Image(systemName: model.isRestoringNow
                        ? "arrow.triangle.2.circlepath"
                        : (model.restorePulse ? "square.stack.3d.up.fill" : "square.stack.3d.up"))
            }
        }
        .menuBarExtraStyle(.window)
    }
}

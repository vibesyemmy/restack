// App/RestackApp.swift
import SwiftUI

@main
struct RestackApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Restack", systemImage: "square.stack.3d.up") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

// App/OnboardingView.swift
import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enable Accessibility").font(.headline)
            Text("Restack needs Accessibility permission to read and move your app windows.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Grant Permission…") { model.promptForAccessibility() }
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("Quit Restack") { NSApplication.shared.terminate(nil) }
        }
        .padding(12).frame(width: 320)
    }
}

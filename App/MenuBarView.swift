// App/MenuBarView.swift
import SwiftUI
import AppKit
import RestackCore

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @State private var newName = ""

    /// "09:12 · Monitor change · 7/8 restored" — hover shows skip reasons.
    private func activityLine(_ e: ActivityEvent) -> String {
        let time = e.timestamp.formatted(date: .omitted, time: .shortened)
        let what: String
        switch e.trigger {
        case .manual:        what = "Manual restore"
        case .login:         what = "Login restore"
        case .monitorChange: what = "Monitor change"
        case .undo:          what = "Undo"
        case .autosave:      what = "Layout saved"
        }
        let counts = e.trigger == .autosave
            ? "\(e.total) window\(e.total == 1 ? "" : "s")"
            : "\(e.placed)/\(e.total) restored"
        return "\(time) · \(what) · \(counts)"
    }

    var body: some View {
        Group {
            if model.isTrusted {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Restack").font(.headline)

                    HStack {
                        TextField("Name this workspace", text: $newName)
                        Button("Save") {
                            guard !newName.isEmpty else { return }
                            model.save(name: newName); newName = ""
                        }
                    }

                    Divider()

                    if model.snapshots.isEmpty {
                        Text("No saved workspaces yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.snapshots) { snap in
                            HStack {
                                Text(snap.name)
                                Spacer()
                                Button("Restore") { model.restore(snap) }
                                Button(role: .destructive) { model.delete(snap) } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }

                    if let s = model.lastSummary {
                        Divider()
                        Text(s.headline).font(.caption).foregroundStyle(.secondary)
                    }

                    Divider()
                    Toggle("Auto-restore when monitors change", isOn: Binding(
                        get: { model.autoRestoreEnabled },
                        set: { model.setAutoRestore($0) }
                    ))
                    .toggleStyle(.checkbox)

                    if model.showUndoRow {
                        Button("Undo last auto-restore") {
                            model.undoAutoRestore()
                            model.showUndoRow = false
                        }
                    }

                    if !model.recentEvents.isEmpty {
                        Divider()
                        Text("Recent Activity").font(.caption).bold()
                        ForEach(model.recentEvents.prefix(5)) { event in
                            Text(activityLine(event))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .help(event.skips.isEmpty ? "" : event.skips.joined(separator: "\n"))
                        }
                    }

                    Divider()
                    Button("Quit Restack") { NSApplication.shared.terminate(nil) }
                }
                .padding(12)
                .frame(width: 320)
            } else {
                OnboardingView(model: model)
            }
        }
    }
}

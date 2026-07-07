// App/MenuBarView.swift
import SwiftUI
import AppKit
import RestackCore

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @State private var newName = ""

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

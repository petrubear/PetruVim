import SwiftUI
import AppKit
import LaunchAtLogin

struct SettingsView: View {
    @State private var includedIDs: [String] = []
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LaunchAtLogin.Toggle("Launch at Login")
                .padding(.bottom, 4)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Included Applications")
                    .font(.headline)
                Text("Vim keys are active only in these apps. When the list is empty, Vim keys work everywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if includedIDs.isEmpty {
                Text("No apps added — Vim keys active everywhere.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                List {
                    ForEach(includedIDs, id: \.self) { bundleID in
                        HStack {
                            IncludedAppRow(bundleID: bundleID)
                            Spacer()
                            Button("Remove") {
                                IncludedAppsStore.shared.remove(bundleID: bundleID)
                                reload()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(minHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                Button("Add App…") {
                    showingAppPicker = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 440, height: 390)
        .onAppear { reload() }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                alreadyIncluded: Set(includedIDs),
                onSelect: { bundleID in
                    IncludedAppsStore.shared.add(bundleID: bundleID)
                    reload()
                    showingAppPicker = false
                },
                onDismiss: { showingAppPicker = false }
            )
        }
    }

    private func reload() {
        includedIDs = IncludedAppsStore.shared.includedBundleIDs
    }
}

// MARK: - Row showing one included app

private struct IncludedAppRow: View {
    let bundleID: String
    @State private var app: NSRunningApplication?

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon = app?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(app?.localizedName ?? bundleID)
                    .font(.body)
                if app != nil {
                    Text(bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        }
    }
}

// MARK: - App picker sheet

private struct AppPickerView: View {
    let alreadyIncluded: Set<String>
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return app.activationPolicy == .regular
                    && id != Bundle.main.bundleIdentifier
                    && !alreadyIncluded.contains(id)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select an app to include:")
                .font(.headline)

            if runningApps.isEmpty {
                Text("No eligible running apps found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                List(runningApps, id: \.bundleIdentifier) { app in
                    Button {
                        if let id = app.bundleIdentifier { onSelect(id) }
                    } label: {
                        HStack(spacing: 8) {
                            Group {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .interpolation(.high)
                                } else {
                                    Image(systemName: "app")
                                        .resizable()
                                }
                            }
                            .frame(width: 20, height: 20)

                            Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { onDismiss() }
            }
        }
        .padding()
        .frame(width: 360, height: 420)
    }
}

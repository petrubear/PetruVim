import SwiftUI
import AppKit
import LaunchAtLogin

struct SettingsView: View {
    @State private var excludedIDs: [String] = []
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LaunchAtLogin.Toggle("Launch at Login")
                .padding(.bottom, 4)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Excluded Applications")
                    .font(.headline)
                Text("PetruVim will pass keys through to these apps unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if excludedIDs.isEmpty {
                Text("No apps excluded.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                List {
                    ForEach(excludedIDs, id: \.self) { bundleID in
                        HStack {
                            ExcludedAppRow(bundleID: bundleID)
                            Spacer()
                            Button("Remove") {
                                ExcludedAppsStore.shared.remove(bundleID: bundleID)
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
                alreadyExcluded: Set(excludedIDs),
                onSelect: { bundleID in
                    ExcludedAppsStore.shared.add(bundleID: bundleID)
                    reload()
                    showingAppPicker = false
                },
                onDismiss: { showingAppPicker = false }
            )
        }
    }

    private func reload() {
        excludedIDs = ExcludedAppsStore.shared.excludedBundleIDs
    }
}

// MARK: - Row showing one excluded app

private struct ExcludedAppRow: View {
    let bundleID: String

    private var app: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

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
    }
}

// MARK: - App picker sheet

private struct AppPickerView: View {
    let alreadyExcluded: Set<String>
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return app.activationPolicy == .regular
                    && id != Bundle.main.bundleIdentifier
                    && !alreadyExcluded.contains(id)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select an app to exclude:")
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

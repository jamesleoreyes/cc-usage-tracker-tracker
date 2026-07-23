import AppKit
import ServiceManagement
import Sparkle
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var autoCheckForUpdates = false

    // The updater lives on the app delegate; nil under `swift run`
    // (bare executable, updater never started).
    private var updater: SPUUpdater? {
        (NSApp.delegate as? AppDelegate)?.updaterController.updater
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            GroupBox("General") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at login", isOn: $appState.settings.launchAtLogin)
                        .onChange(of: appState.settings.launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                    Toggle("Automatically check for updates", isOn: $autoCheckForUpdates)
                        .onChange(of: autoCheckForUpdates) { _, newValue in
                            updater?.automaticallyChecksForUpdates = newValue
                        }
                        .disabled(updater == nil)
                        .onAppear {
                            autoCheckForUpdates = updater?.automaticallyChecksForUpdates ?? false
                        }
                }
                .padding(4)
            }

            GroupBox("About") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Registry data is updated automatically via GitHub Actions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastRefresh = appState.lastRefreshDate {
                        Text("Last checked: \(lastRefresh.relativeDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 340, height: 270)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var tokenText: String = ""
    @State private var hasToken: Bool = false
    @Environment(\.dismiss) private var dismiss

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

            // GitHub Token
            GroupBox("GitHub Personal Access Token") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional. Increases API rate limit from 60 to 5,000 req/hr.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        SecureField("ghp_...", text: $tokenText)
                            .textFieldStyle(.roundedBorder)

                        if hasToken {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        Button(hasToken ? "Update" : "Save") {
                            saveToken()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if hasToken {
                            Button("Remove") {
                                removeToken()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(4)
            }

            // Refresh interval
            GroupBox("Refresh Interval") {
                Picker("Metadata refresh", selection: $appState.settings.refreshIntervalMinutes) {
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                }
                .pickerStyle(.segmented)
                .padding(4)
            }

            // Discovery
            GroupBox("Discovery") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Search for new trackers", isOn: $appState.settings.discoveryEnabled)

                    if appState.settings.discoveryEnabled {
                        Picker("Polling interval", selection: $appState.settings.discoveryIntervalHours) {
                            Text("1 hr").tag(1)
                            Text("6 hr").tag(6)
                            Text("12 hr").tag(12)
                            Text("24 hr").tag(24)
                        }
                        .pickerStyle(.segmented)
                    }

                    Toggle("Show notifications for new discoveries", isOn: $appState.settings.notificationsEnabled)
                }
                .padding(4)
            }

            // Launch at login
            GroupBox("General") {
                Toggle("Launch at login", isOn: $appState.settings.launchAtLogin)
                    .onChange(of: appState.settings.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
                    .padding(4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 480)
        .onAppear {
            hasToken = KeychainService.load(key: "github-pat") != nil
        }
    }

    private func saveToken() {
        guard !tokenText.isEmpty else { return }
        try? KeychainService.save(key: "github-pat", value: tokenText)
        hasToken = true
        tokenText = ""
    }

    private func removeToken() {
        KeychainService.delete(key: "github-pat")
        hasToken = false
        tokenText = ""
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

import SwiftUI

struct PopoverContentView: View {
    @Bindable var appState: AppState
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                HStack {
                    Text("CC Usage Tracker Tracker")
                        .font(.headline)
                    Spacer()
                    if appState.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text("It does not track your Claude usage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: $appState.searchText)
                    .textFieldStyle(.plain)
                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Filter + sort
            FilterBar(appState: appState)
                .padding(.bottom, 8)

            Divider()

            // Project list
            TrackerListView(appState: appState)

            Divider()

            // Stats
            StatsView(appState: appState)
        }
        .frame(width: 480, height: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $showAbout) {
            AboutView(trackerCount: appState.projects.count)
        }
    }
}

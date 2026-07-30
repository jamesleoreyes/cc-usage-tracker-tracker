import SwiftUI

struct PopoverContentView: View {
    @Bindable var appState: AppState
    var onRefresh: () -> Void = {}
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            FilterBar(appState: appState)
                .padding(.bottom, 10)

            Divider()

            TrackerListView(appState: appState)

            Divider()

            StatsView(appState: appState, onRefresh: onRefresh)
        }
        .frame(width: 500, height: 640)
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CC Usage Tracker Tracker")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("It does not track your Claude usage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appState.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search \(appState.projects.count.formatted()) trackers…", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.callout)
            if !appState.searchText.isEmpty {
                Button {
                    appState.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

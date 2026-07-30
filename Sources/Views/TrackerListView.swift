import SwiftUI

struct TrackerListView: View {
    @Bindable var appState: AppState

    var body: some View {
        if appState.filteredProjects.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.filteredProjects) { project in
                        VStack(spacing: 0) {
                            TrackerRowView(
                                project: project,
                                isExpanded: appState.expandedProjectID == project.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if appState.expandedProjectID == project.id {
                                        appState.expandedProjectID = nil
                                    } else {
                                        appState.expandedProjectID = project.id
                                    }
                                }
                            }

                            if appState.expandedProjectID == project.id {
                                TrackerDetailView(project: project)
                                    .transition(.opacity)
                            }

                            Divider()
                                .padding(.leading, 66)
                                .opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "binoculars")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)
            Text("No trackers match")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Somehow, out of \(appState.projects.count.formatted()) of them.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Clear filters") {
                appState.searchText = ""
                appState.selectedCategory = nil
            }
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

import SwiftUI

struct PendingReviewView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(.orange)
                Text("\(appState.pendingProjects.count) new potential tracker\(appState.pendingProjects.count == 1 ? "" : "s") found")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)

            ForEach(appState.pendingProjects) { project in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("by \(project.author)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Add") {
                        addProject(project)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Dismiss") {
                        dismissProject(project)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Link(destination: project.repoURL) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.05))
    }

    private func addProject(_ project: TrackerProject) {
        appState.projects.append(project)
        appState.pendingProjects.removeAll { $0.id == project.id }
        saveCacheState()
    }

    private func dismissProject(_ project: TrackerProject) {
        appState.dismissedIDs.insert(project.id)
        appState.pendingProjects.removeAll { $0.id == project.id }
        saveCacheState()
    }

    private func saveCacheState() {
        let cachedData = CachedData(
            projects: appState.projects,
            dismissedIDs: appState.dismissedIDs
        )
        CacheService.save(cachedData)
    }
}

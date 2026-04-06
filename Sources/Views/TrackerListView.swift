import SwiftUI

struct TrackerListView: View {
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.filteredProjects) { project in
                    VStack(spacing: 0) {
                        TrackerRowView(project: project)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
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
                            .padding(.leading, 64)
                    }
                }
            }
        }
    }
}

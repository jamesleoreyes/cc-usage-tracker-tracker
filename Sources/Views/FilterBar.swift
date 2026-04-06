import SwiftUI

struct FilterBar: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            // Category pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    CategoryPill(
                        title: "All",
                        count: appState.projects.count,
                        isSelected: appState.selectedCategory == nil
                    ) {
                        appState.selectedCategory = nil
                    }

                    ForEach(appState.categoryCounts, id: \.0) { category, count in
                        CategoryPill(
                            title: category.shortName,
                            count: count,
                            isSelected: appState.selectedCategory == category
                        ) {
                            appState.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Sort controls
            HStack(spacing: 4) {
                Text("Sort:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        appState.sortOrder = order
                    } label: {
                        Text(order.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                appState.sortOrder == order
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CategoryPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension TrackerCategory {
    var shortName: String {
        switch self {
        case .macosNative: "macOS"
        case .electron: "Desktop"
        case .cli: "CLI"
        case .terminalUI: "TUI"
        case .browserExtension: "Browser"
        case .webDashboard: "Web"
        case .mobile: "Mobile"
        case .statusline: "Statusline"
        case .ubersicht: "Übersicht"
        case .vscodeExtension: "VS Code"
        case .neovimPlugin: "Neovim"
        case .raycast: "Raycast"
        case .tmux: "Tmux"
        case .waybar: "Waybar"
        case .desktopOverlay: "Overlay"
        case .claudeCodePlugin: "CC Plugin"
        }
    }
}

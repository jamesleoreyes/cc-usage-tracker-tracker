import SwiftUI

struct FilterBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    CategoryChip(
                        title: "All",
                        count: appState.projects.count,
                        isSelected: appState.selectedCategory == nil
                    ) {
                        appState.selectedCategory = nil
                    }

                    ForEach(appState.categoryCounts, id: \.0) { category, count in
                        CategoryChip(
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

            // Sort lives in a compact menu instead of a whole row of buttons.
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        appState.sortOrder = order
                    } label: {
                        if appState.sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text(appState.sortOrder.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.trailing, 16)
            .help("Sort order")
        }
    }
}

struct CategoryChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(count.starAbbreviated)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary)
                    .monospacedDigit()
            }
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.5)),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
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
        case .other: "Other"
        }
    }
}

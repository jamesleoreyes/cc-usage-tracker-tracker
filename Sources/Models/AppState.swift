import Foundation

@MainActor
@Observable
final class AppState {
    var projects: [TrackerProject] = []
    var pendingProjects: [TrackerProject] = []
    var dismissedIDs: Set<String> = []
    var searchText: String = ""
    var selectedCategory: TrackerCategory? = nil
    var sortOrder: SortOrder = .stars
    var expandedProjectID: String? = nil
    var isRefreshing: Bool = false
    var lastRefreshDate: Date? = nil

    var filteredProjects: [TrackerProject] {
        var result = projects

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.author.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .stars:
            result.sort { ($0.stars ?? 0) > ($1.stars ?? 0) }
        case .recent:
            result.sort { ($0.lastCommitDate ?? .distantPast) > ($1.lastCommitDate ?? .distantPast) }
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .health:
            result.sort { $0.health.sortRank < $1.health.sortRank }
        }

        return result
    }

    var settings = AppSettings()

    var categoryCounts: [(TrackerCategory, Int)] {
        TrackerCategory.allCases.compactMap { category in
            let count = projects.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }
}

struct AppSettings {
    var refreshIntervalMinutes: Int = 30
    var discoveryEnabled: Bool = true
    var discoveryIntervalHours: Int = 6
    var notificationsEnabled: Bool = true
    var launchAtLogin: Bool = false
}

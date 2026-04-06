import SwiftUI

struct StatsView: View {
    let appState: AppState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Stats")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(spacing: 6) {
                    statRow("Total trackers", "\(appState.projects.count)")
                    statRow("Built with Claude", builtWithClaudeText)
                    statRow("Platform spread", platformSpread)
                    statRow("Top languages", topLanguages)
                    statRow("Categories", "\(categoriesWithProjects) active")

                    if let lastRefresh = appState.lastRefreshDate {
                        statRow("Last refresh", lastRefresh.relativeDescription)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Text("This app does not track your Claude usage.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.secondary.opacity(0.03))
    }

    private var builtWithClaudeText: String {
        let count = appState.projects.filter { $0.builtWithClaude == true }.count
        let total = appState.projects.count
        guard total > 0 else { return "0" }
        let pct = Int(Double(count) / Double(total) * 100)
        return "\(count) (\(pct)%)"
    }

    private var platformSpread: String {
        var counts: [String: Int] = [:]
        for project in appState.projects {
            for platform in project.platforms {
                counts[platform.rawValue, default: 0] += 1
            }
        }
        let sorted = counts.sorted { $0.value > $1.value }
        let top3 = sorted.prefix(3).map { "\($0.key): \($0.value)" }
        return top3.joined(separator: " · ")
    }

    private var topLanguages: String {
        var counts: [String: Int] = [:]
        for project in appState.projects where project.language != "Unknown" {
            counts[project.language, default: 0] += 1
        }
        let sorted = counts.sorted { $0.value > $1.value }
        let top3 = sorted.prefix(3).map { "\($0.key): \($0.value)" }
        return top3.joined(separator: " · ")
    }

    private var categoriesWithProjects: Int {
        Set(appState.projects.map(\.category)).count
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

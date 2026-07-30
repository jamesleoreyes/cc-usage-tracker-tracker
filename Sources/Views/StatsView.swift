import SwiftUI

struct StatsView: View {
    let appState: AppState
    var onRefresh: () -> Void = {}
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Stats")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lastRefresh = appState.lastRefreshDate {
                        Text("Updated \(lastRefresh.relativeDescription)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh now")

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 8) {
                    statTile(
                        value: appState.projects.count.formatted(),
                        label: "trackers",
                        detail: "\(activeCount.formatted()) active"
                    )

                    claudeTile

                    statTile(
                        value: topLanguage.0,
                        label: "top language",
                        detail: "\(topLanguage.1.formatted()) trackers"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Text("This app does not track your Claude usage.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 7)
            }
        }
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Tiles

    private func statTile(value: String, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var claudeTile: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                Text("\(builtWithClaudePercent)%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.claude)
            Text("built with Claude")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(builtWithClaudeCount.formatted()) confirmed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.claude.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data

    private var builtWithClaudeCount: Int {
        appState.projects.filter { $0.builtWithClaude == true }.count
    }

    private var builtWithClaudePercent: Int {
        let total = appState.projects.count
        guard total > 0 else { return 0 }
        return Int(Double(builtWithClaudeCount) / Double(total) * 100)
    }

    private var activeCount: Int {
        appState.projects.filter { $0.health == .green }.count
    }

    private var topLanguage: (String, Int) {
        var counts: [String: Int] = [:]
        for project in appState.projects where project.language != "Unknown" && !project.language.isEmpty {
            counts[project.language, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value }) else { return ("—", 0) }
        return (top.key, top.value)
    }
}

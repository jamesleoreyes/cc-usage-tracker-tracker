import SwiftUI

struct TrackerRowView: View {
    let project: TrackerProject
    let isExpanded: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Stars column — the default sort key, so it leads.
            VStack(spacing: 1) {
                Text(project.stars.map { $0.starAbbreviated } ?? "—")
                    .font(.system(.callout, weight: .semibold))
                    .monospacedDigit()
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.yellow.opacity(0.8))
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(project.name)
                        .font(.system(.body, weight: .semibold))
                        .lineLimit(1)

                    if project.builtWithClaude == true {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.claude)
                            .help("Built with Claude")
                    }
                }

                HStack(spacing: 5) {
                    Text(project.author)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(project.category.shortName)

                    if !project.language.isEmpty && project.language != "Unknown" {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.languageColor(project.language))
                                .frame(width: 7, height: 7)
                            Text(project.language)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if let lastCommit = project.lastCommitDate {
                Text(lastCommit.relativeDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            healthIndicator

            if isHovered || isExpanded {
                Link(destination: project.repoURL) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .background(.quaternary.opacity(0.6), in: Circle())
                }
                .help("Open on GitHub")
            } else {
                // Reserve the space so rows don't jiggle on hover.
                Color.clear.frame(width: 20, height: 20)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .background(
            (isHovered || isExpanded) ? Color.primary.opacity(0.05) : Color.clear
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var healthIndicator: some View {
        if project.health == .dead {
            Text("💀")
                .font(.caption)
                .help(project.health.label)
        } else {
            Circle()
                .fill(project.health.color)
                .frame(width: 8, height: 8)
                .help(project.health.label)
        }
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

import SwiftUI

struct TrackerRowView: View {
    let project: TrackerProject

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Stars
            VStack {
                Text(starText)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            .frame(width: 44)

            // Main content
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(project.name)
                        .font(.system(.body, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(project.health.symbol)
                        .font(.caption)
                }

                HStack(spacing: 6) {
                    Text(project.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text(project.category.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if !project.language.isEmpty && project.language != "Unknown" {
                        Text(project.language)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.tertiary.opacity(0.3))
                            .clipShape(Capsule())
                    }

                    if let lastCommit = project.lastCommitDate {
                        Text("Last commit: \(lastCommit.relativeDescription)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // GitHub link
            Link(destination: project.repoURL) {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }

    private var starText: String {
        guard let stars = project.stars else { return "—" }
        if stars >= 1000 {
            return String(format: "%.1fk", Double(stars) / 1000.0)
        }
        return "\(stars)"
    }
}

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

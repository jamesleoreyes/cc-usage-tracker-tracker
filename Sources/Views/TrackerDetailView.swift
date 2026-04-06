import SwiftUI

struct TrackerDetailView: View {
    let project: TrackerProject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full description
            Text(project.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Features
            if !project.features.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(project.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // Auth methods
            HStack(spacing: 4) {
                Text("Auth:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(project.authMethod, id: \.self) { method in
                    Text(method.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Metadata row
            HStack(spacing: 12) {
                if let issues = project.openIssues {
                    Label("\(issues) issues", systemImage: "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let release = project.latestRelease {
                    Label(release, systemImage: "tag")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if project.builtWithClaude == true {
                    Text("Built with Claude")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Platforms
            HStack(spacing: 4) {
                Text("Platforms:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(project.platforms, id: \.self) { platform in
                    Text(platform.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Open in GitHub button
            Button {
                NSWorkspace.shared.open(project.repoURL)
            } label: {
                Label("Open in GitHub", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.leading, 54)
        .padding(.trailing, 10)
        .padding(.bottom, 8)
    }
}

/// Simple flow layout for wrapping tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

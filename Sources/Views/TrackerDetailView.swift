import SwiftUI

struct TrackerDetailView: View {
    let project: TrackerProject

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !project.features.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(project.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                let platforms = project.platforms.filter { $0 != .unknown }
                if !platforms.isEmpty {
                    detailLine(
                        symbol: "macwindow",
                        text: platforms.map(\.rawValue).joined(separator: ", ")
                    )
                }

                let auth = project.authMethod.filter { $0 != .unknown }
                if !auth.isEmpty {
                    detailLine(symbol: "key.horizontal", text: auth.map(\.rawValue).joined(separator: ", "))
                }

                HStack(spacing: 12) {
                    if let issues = project.openIssues {
                        detailLine(symbol: "exclamationmark.circle", text: "\(issues) open issues")
                    }
                    if let release = project.latestRelease {
                        detailLine(symbol: "tag", text: release)
                    }
                }
            }

            HStack(spacing: 8) {
                Link(destination: project.repoURL) {
                    Label("Open on GitHub", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if project.builtWithClaude == true {
                    Label("Built with Claude", systemImage: "sparkle")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.claude.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.claude)
                }

                Spacer()
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func detailLine(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 13)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

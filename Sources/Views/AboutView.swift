import SwiftUI

struct AboutView: View {
    let trackerCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("CC Usage Tracker Tracker")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 4) {
                Text("It does not track your Claude usage.")
                    .font(.subheadline)
                Text("It tracks the people who do.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(width: 200)

            VStack(spacing: 4) {
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Currently tracking: \(trackerCount) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("""
            "You have \(trackerCount) options for monitoring
            your Claude rate limits.
            This is not one of them."
            """)
            .font(.caption)
            .italic()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Text("Built with Claude Code, obviously.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(30)
        .frame(width: 340)
    }
}

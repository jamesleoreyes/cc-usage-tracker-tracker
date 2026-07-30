import SwiftUI

// Shared visual vocabulary for the popover UI.
enum Theme {
    /// The one signature color: Claude's terracotta (#D97757), used for
    /// everything "Built with Claude" and as the app's accent thread.
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)

    /// GitHub-style language dot colors for the common languages in the
    /// registry; anything unmapped gets a stable hash-derived hue so two
    /// trackers in the same language always match.
    static func languageColor(_ language: String) -> Color {
        switch language {
        case "Swift": Color(red: 0.94, green: 0.32, blue: 0.21)
        case "TypeScript": Color(red: 0.19, green: 0.46, blue: 0.72)
        case "JavaScript": Color(red: 0.95, green: 0.87, blue: 0.35)
        case "Python": Color(red: 0.21, green: 0.44, blue: 0.65)
        case "Rust": Color(red: 0.87, green: 0.65, blue: 0.52)
        case "Go": Color(red: 0.00, green: 0.68, blue: 0.85)
        case "Shell": Color(red: 0.35, green: 0.88, blue: 0.32)
        case "Ruby": Color(red: 0.44, green: 0.08, blue: 0.09)
        case "C#": Color(red: 0.09, green: 0.53, blue: 0.02)
        case "Kotlin": Color(red: 0.66, green: 0.46, blue: 1.00)
        case "Java": Color(red: 0.69, green: 0.44, blue: 0.09)
        case "C++": Color(red: 0.95, green: 0.30, blue: 0.49)
        case "Lua": Color(red: 0.00, green: 0.00, blue: 0.50)
        case "HTML", "CSS": Color(red: 0.89, green: 0.30, blue: 0.14)
        case "Vue": Color(red: 0.25, green: 0.72, blue: 0.51)
        case "Dart": Color(red: 0.00, green: 0.71, blue: 0.92)
        default:
            Color(hue: Double(abs(language.hashValue % 360)) / 360.0, saturation: 0.55, brightness: 0.75)
        }
    }
}

extension HealthStatus {
    var color: Color {
        switch self {
        case .green: .green
        case .yellow: .yellow
        case .red: .red
        case .dead: .gray
        case .unknown: .gray.opacity(0.5)
        }
    }

    var label: String {
        switch self {
        case .green: "Active — commit within 30 days"
        case .yellow: "Aging — no commit in 30–90 days"
        case .red: "Stale or archived"
        case .dead: "Deleted from GitHub"
        case .unknown: "No commit data yet"
        }
    }
}

extension Int {
    /// 26742 -> "26.7k", 421 -> "421"
    var starAbbreviated: String {
        self >= 1000 ? String(format: "%.1fk", Double(self) / 1000.0) : "\(self)"
    }
}

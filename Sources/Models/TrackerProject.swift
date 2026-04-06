import Foundation

struct TrackerProject: Codable, Identifiable {
    let id: String                    // GitHub "owner/repo"
    let name: String
    let author: String
    let repoURL: URL
    let description: String
    let category: TrackerCategory
    let platforms: [Platform]
    let language: String
    let authMethod: [AuthMethod]
    let features: [String]
    let builtWithClaude: Bool?

    // Live metadata (updated via GitHub API)
    var stars: Int?
    var lastCommitDate: Date?
    var openIssues: Int?
    var latestRelease: String?
    var archived: Bool?
    var lastFetched: Date?
}

enum TrackerCategory: String, Codable, CaseIterable {
    case macosNative = "macOS Native"
    case electron = "Electron/Desktop"
    case cli = "CLI/Terminal"
    case browserExtension = "Browser Extension"
    case webDashboard = "Web Dashboard"
    case mobile = "Mobile"
    case statusline = "Statusline"
    case ubersicht = "Übersicht Widget"
}

enum Platform: String, Codable {
    case macos, windows, linux, android, ios, web, chromium, firefox
}

enum AuthMethod: String, Codable {
    case oauth = "OAuth Token"
    case sessionCookie = "Session Cookie"
    case sessionKey = "Session Key"
    case jsonlParsing = "JSONL Log Parsing"
    case apiKey = "API Key"
    case browserCookie = "Browser Cookie Auto-detect"
}

enum SortOrder: String, CaseIterable {
    case stars = "Stars"
    case recent = "Recent"
    case name = "Name"
    case health = "Health"
}

enum HealthStatus: Comparable {
    case green
    case yellow
    case red
    case dead
    case unknown

    var symbol: String {
        switch self {
        case .green: "🟢"
        case .yellow: "🟡"
        case .red: "🔴"
        case .dead: "💀"
        case .unknown: "⚪"
        }
    }

    var sortRank: Int {
        switch self {
        case .green: 0
        case .yellow: 1
        case .unknown: 2
        case .red: 3
        case .dead: 4
        }
    }
}

extension TrackerProject {
    var health: HealthStatus {
        if archived == true { return .red }
        guard let lastCommit = lastCommitDate else { return .unknown }
        let days = Calendar.current.dateComponents([.day], from: lastCommit, to: Date()).day ?? 0
        if days <= 30 { return .green }
        if days <= 90 { return .yellow }
        return .red
    }
}

import Foundation
import UserNotifications

actor DiscoveryService {
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com"

    private let searchQueries = [
        "claude+usage+widget",
        "claude+usage+tracker",
        "claude+usage+monitor",
        "claude+code+monitor"
    ]

    struct DiscoveredRepo: Sendable {
        let id: String          // "owner/repo"
        let name: String
        let author: String
        let repoURL: URL
        let description: String
        let language: String
        let stars: Int
    }

    func searchForNewTrackers(
        knownIDs: Set<String>,
        dismissedIDs: Set<String>,
        token: String?
    ) async -> [DiscoveredRepo] {
        var allResults: [String: DiscoveredRepo] = [:]

        for query in searchQueries {
            do {
                let repos = try await searchRepositories(query: query, token: token)
                for repo in repos {
                    if !knownIDs.contains(repo.id) && !dismissedIDs.contains(repo.id) {
                        allResults[repo.id] = repo
                    }
                }
            } catch {
                print("Discovery search error for '\(query)': \(error)")
            }
            // Stagger search requests
            try? await Task.sleep(for: .seconds(2))
        }

        return Array(allResults.values)
    }

    private func searchRepositories(query: String, token: String?) async throws -> [DiscoveredRepo] {
        var urlComponents = URLComponents(string: "\(baseURL)/search/repositories")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "per_page", value: "30")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> DiscoveredRepo? in
            guard let fullName = item["full_name"] as? String,
                  let name = item["name"] as? String,
                  let owner = item["owner"] as? [String: Any],
                  let login = owner["login"] as? String,
                  let htmlURL = item["html_url"] as? String,
                  let url = URL(string: htmlURL) else {
                return nil
            }
            return DiscoveredRepo(
                id: fullName,
                name: name,
                author: login,
                repoURL: url,
                description: item["description"] as? String ?? "",
                language: item["language"] as? String ?? "Unknown",
                stars: item["stargazers_count"] as? Int ?? 0
            )
        }
    }
}

@MainActor
enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func postNewTrackerNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CC Usage Tracker Tracker"
        content.body = "Found \(count) new potential Claude usage tracker\(count == 1 ? "" : "s")."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "new-trackers-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

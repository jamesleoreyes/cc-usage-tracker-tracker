import Foundation

actor GitHubService {
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com"
    private var rateLimitRemaining: Int = 60
    private var rateLimitReset: Date = .distantPast

    struct RepoMetadata: Sendable {
        let stars: Int
        let lastCommitDate: Date?
        let openIssues: Int
        let archived: Bool
    }

    func fetchRepoMetadata(owner: String, repo: String, token: String?) async throws -> RepoMetadata {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        updateRateLimit(from: response)

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        if http.statusCode == 404 {
            throw GitHubError.notFound
        }
        guard http.statusCode == 200 else {
            throw GitHubError.httpError(http.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let stars = json["stargazers_count"] as? Int ?? 0
        let openIssues = json["open_issues_count"] as? Int ?? 0
        let archived = json["archived"] as? Bool ?? false

        var lastCommitDate: Date?
        if let pushedAt = json["pushed_at"] as? String {
            lastCommitDate = ISO8601DateFormatter().date(from: pushedAt)
        }

        return RepoMetadata(
            stars: stars,
            lastCommitDate: lastCommitDate,
            openIssues: openIssues,
            archived: archived
        )
    }

    func fetchLatestRelease(owner: String, repo: String, token: String?) async throws -> String? {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        updateRateLimit(from: response)

        guard let http = response as? HTTPURLResponse else { return nil }
        guard http.statusCode == 200 else { return nil }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return json["tag_name"] as? String
    }

    func refreshProject(_ project: TrackerProject, token: String?) async -> TrackerProject {
        let parts = project.id.split(separator: "/")
        guard parts.count == 2 else { return project }
        let owner = String(parts[0])
        let repo = String(parts[1])

        var updated = project
        updated.lastFetched = Date()

        do {
            let metadata = try await fetchRepoMetadata(owner: owner, repo: repo, token: token)
            updated.stars = metadata.stars
            updated.lastCommitDate = metadata.lastCommitDate
            updated.openIssues = metadata.openIssues
            updated.archived = metadata.archived

            // Only fetch release if we have rate limit headroom
            if rateLimitRemaining > 10 {
                updated.latestRelease = try await fetchLatestRelease(owner: owner, repo: repo, token: token)
            }
        } catch GitHubError.notFound {
            // Mark as dead but keep in registry
            updated.archived = true
        } catch {
            // Keep existing data on error
        }

        return updated
    }

    var currentRateLimitRemaining: Int { rateLimitRemaining }

    private func updateRateLimit(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse else { return }
        if let remaining = http.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let value = Int(remaining) {
            rateLimitRemaining = value
        }
        if let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let epoch = TimeInterval(reset) {
            rateLimitReset = Date(timeIntervalSince1970: epoch)
        }
    }
}

enum GitHubError: Error {
    case invalidResponse
    case notFound
    case httpError(Int)
    case rateLimited
}

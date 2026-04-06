import Foundation

@MainActor
enum RegistryService {
    static let remoteRegistryURL = URL(
        string: "https://raw.githubusercontent.com/jamesleoreyes/cc-usage-tracker-tracker/main/Sources/Resources/tracker-registry.json"
    )!

    static func loadBundledRegistry() throws -> [TrackerProject] {
        guard let url = Bundle.module.url(forResource: "tracker-registry", withExtension: "json") else {
            throw RegistryError.missingBundledFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TrackerProject].self, from: data)
    }

    /// Fetch the latest registry from GitHub. Returns nil on failure.
    nonisolated static func fetchRemoteRegistry() async -> [TrackerProject]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteRegistryURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode([TrackerProject].self, from: data)
        } catch {
            print("Remote registry fetch failed: \(error)")
            return nil
        }
    }

    /// Merge two registries. `primary` wins for static fields; `secondary` provides live metadata fallback.
    static func merge(primary: [TrackerProject], secondary: [TrackerProject]) -> [TrackerProject] {
        let secondaryByID = Dictionary(secondary.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var result: [TrackerProject] = []

        for var project in primary {
            if let existing = secondaryByID[project.id] {
                // Preserve live metadata from secondary
                project.stars = existing.stars
                project.lastCommitDate = existing.lastCommitDate
                project.openIssues = existing.openIssues
                project.latestRelease = existing.latestRelease
                project.archived = existing.archived
                project.lastFetched = existing.lastFetched
            }
            result.append(project)
        }

        // Include any projects in secondary not present in primary (user-added)
        let primaryIDs = Set(primary.map(\.id))
        for project in secondary where !primaryIDs.contains(project.id) {
            result.append(project)
        }

        return result
    }
}

enum RegistryError: Error {
    case missingBundledFile
}

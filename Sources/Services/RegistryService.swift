import Foundation

@MainActor
enum RegistryService {
    static func loadBundledRegistry() throws -> [TrackerProject] {
        guard let url = Bundle.module.url(forResource: "tracker-registry", withExtension: "json") else {
            throw RegistryError.missingBundledFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TrackerProject].self, from: data)
    }

    /// Merge bundled registry (source of truth for static fields) with cached data (has live metadata).
    static func merge(bundled: [TrackerProject], cached: [TrackerProject]) -> [TrackerProject] {
        let cachedByID = Dictionary(cached.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var result: [TrackerProject] = []

        for var project in bundled {
            if let cached = cachedByID[project.id] {
                // Preserve live metadata from cache
                project.stars = cached.stars
                project.lastCommitDate = cached.lastCommitDate
                project.openIssues = cached.openIssues
                project.latestRelease = cached.latestRelease
                project.archived = cached.archived
                project.lastFetched = cached.lastFetched
            }
            result.append(project)
        }

        // Include any user-added projects not in the bundled registry
        let bundledIDs = Set(bundled.map(\.id))
        for project in cached where !bundledIDs.contains(project.id) {
            result.append(project)
        }

        return result
    }
}

enum RegistryError: Error {
    case missingBundledFile
}

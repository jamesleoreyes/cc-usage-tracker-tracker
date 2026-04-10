import Foundation

@MainActor
enum RegistryService {
    static let remoteRegistryURL = URL(
        string: "https://raw.githubusercontent.com/jamesleoreyes/cc-usage-tracker-tracker/main/Sources/Resources/tracker-registry.json"
    )!

    private static var decoder: JSONDecoder {
        makeISO8601Decoder()
    }

    /// Creates a JSONDecoder that handles ISO 8601 dates both with and without
    /// fractional seconds (e.g. "2026-04-10T21:51:17.883Z" and "2026-04-10T21:51:17Z").
    /// JavaScript's `Date.toISOString()` includes milliseconds, which Swift's
    /// built-in `.iso8601` strategy rejects — causing the entire decode to fail.
    nonisolated static func makeISO8601Decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid ISO 8601 date: \(string)"
            )
        }
        return decoder
    }

    static func loadBundledRegistry() throws -> [TrackerProject] {
        guard let url = Bundle.appBundle.url(forResource: "tracker-registry", withExtension: "json") else {
            throw RegistryError.missingBundledFile
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([TrackerProject].self, from: data)
    }

    /// Fetch the latest registry from GitHub. Returns nil on failure.
    nonisolated static func fetchRemoteRegistry() async -> [TrackerProject]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteRegistryURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try makeISO8601Decoder().decode([TrackerProject].self, from: data)
        } catch {
            print("Remote registry fetch failed: \(error)")
            return nil
        }
    }

    /// Merge registries. `primary` is the source of truth (remote registry with live metadata).
    /// `secondary` provides fallback data for any projects not yet in primary.
    static func merge(primary: [TrackerProject], secondary: [TrackerProject]) -> [TrackerProject] {
        var result = primary

        // Include any projects in secondary not present in primary
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

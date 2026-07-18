import Foundation

@MainActor
enum RegistryService {
    static let remoteRegistryURL = URL(
        string: "https://raw.githubusercontent.com/jamesleoreyes/cc-usage-tracker-tracker/main/Sources/Resources/tracker-registry.json"
    )!

    /// Wrapper that swallows a single entry's decode failure so one malformed
    /// entry can't take down the whole registry (which would silently freeze
    /// every installed app on its bundled copy).
    private struct FailableEntry: Decodable {
        let value: TrackerProject?
        init(from decoder: Decoder) {
            value = try? TrackerProject(from: decoder)
        }
    }

    /// Decode a registry array, dropping malformed entries instead of failing wholesale.
    nonisolated static func decodeRegistry(from data: Data) throws -> [TrackerProject] {
        let entries = try makeISO8601Decoder().decode([FailableEntry].self, from: data)
        let projects = entries.compactMap(\.value)
        let dropped = entries.count - projects.count
        if dropped > 0 {
            print("Registry decode: dropped \(dropped) malformed entr\(dropped == 1 ? "y" : "ies") of \(entries.count)")
        }
        return projects
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
        return try decodeRegistry(from: data)
    }

    /// Fetch the latest registry from GitHub. Returns nil on failure.
    nonisolated static func fetchRemoteRegistry() async -> [TrackerProject]? {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteRegistryURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try decodeRegistry(from: data)
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

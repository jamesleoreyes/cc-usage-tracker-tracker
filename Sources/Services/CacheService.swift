import Foundation

struct CachedData: Codable {
    var projects: [TrackerProject]
    var dismissedIDs: Set<String>
}

enum CacheService {
    private static let directoryName = "CCUsageTrackerTracker"
    private static let fileName = "cache.json"

    static var cacheDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(directoryName)
    }

    static var cacheFileURL: URL {
        cacheDirectoryURL.appendingPathComponent(fileName)
    }

    nonisolated static func load() -> CachedData? {
        let url = cacheFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedData.self, from: data)
        } catch {
            print("Cache load error: \(error)")
            return nil
        }
    }

    nonisolated static func save(_ cachedData: CachedData) {
        let url = cacheFileURL
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectoryURL,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cachedData)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Cache save error: \(error)")
        }
    }
}

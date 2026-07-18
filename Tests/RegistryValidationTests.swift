import XCTest
@testable import CCUsageTrackerTracker

/// Strict validation of the committed registry file.
///
/// The app decodes tolerantly (unknown enum values fall back, malformed entries
/// drop) so bad data can never brick installed apps. This suite is the opposite:
/// it fails on ANY irregularity, so a bad automated commit is caught in CI
/// before it ships to the live feed.
final class RegistryValidationTests: XCTestCase {
    static var registryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources/Resources/tracker-registry.json")
    }

    // The registry must only ever contain real values — fallback cases exist
    // for forward compatibility in the app, not as values automation may write.
    static let allowedCategories = Set(TrackerCategory.allCases.map(\.rawValue)).subtracting([TrackerCategory.other.rawValue])
    static let allowedPlatforms = Set([Platform.macos, .windows, .linux, .android, .ios, .web, .chromium, .firefox, .vscode, .neovim, .raycast, .tmux].map(\.rawValue))
    static let allowedAuthMethods = Set([AuthMethod.oauth, .sessionCookie, .sessionKey, .jsonlParsing, .apiKey, .browserCookie, .otel, .trafficCapture].map(\.rawValue))

    static let isoDate = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$"#)
    static let idPattern = try! NSRegularExpression(pattern: #"^[^/\s]+/[^/\s]+$"#)

    private func matches(_ regex: NSRegularExpression, _ string: String) -> Bool {
        regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }

    func testRegistryEntriesAreStrictlyValid() throws {
        let data = try Data(contentsOf: Self.registryURL)
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let entries = raw as? [[String: Any]] else {
            return XCTFail("Registry root is not an array of objects")
        }

        XCTAssertGreaterThan(entries.count, 3000, "Registry shrank suspiciously — truncated write?")

        var seenIDs = Set<String>()
        for (index, entry) in entries.enumerated() {
            let id = entry["id"] as? String ?? "<missing id>"
            let ctx = "[\(index)] \(id)"

            XCTAssertTrue(matches(Self.idPattern, id), "\(ctx): id is not owner/repo")
            XCTAssertTrue(seenIDs.insert(id.lowercased()).inserted, "\(ctx): duplicate id")

            for field in ["name", "author", "description", "language"] {
                XCTAssertTrue(entry[field] is String, "\(ctx): \(field) missing or not a string")
            }

            let url = entry["repoURL"] as? String ?? ""
            XCTAssertTrue(url.hasPrefix("https://"), "\(ctx): repoURL not https (\(url))")

            let category = entry["category"] as? String ?? "<missing>"
            XCTAssertTrue(Self.allowedCategories.contains(category), "\(ctx): unknown category \"\(category)\"")

            let platforms = entry["platforms"] as? [String]
            XCTAssertNotNil(platforms, "\(ctx): platforms missing or not a string array")
            for platform in platforms ?? [] {
                XCTAssertTrue(Self.allowedPlatforms.contains(platform), "\(ctx): unknown platform \"\(platform)\"")
            }

            let authMethods = entry["authMethod"] as? [String]
            XCTAssertNotNil(authMethods, "\(ctx): authMethod missing or not a string array")
            for method in authMethods ?? [] {
                XCTAssertTrue(Self.allowedAuthMethods.contains(method), "\(ctx): unknown authMethod \"\(method)\"")
            }

            XCTAssertTrue(entry["features"] is [String], "\(ctx): features missing or not a string array")

            if let built = entry["builtWithClaude"], !(built is NSNull) {
                XCTAssertTrue(built is Bool, "\(ctx): builtWithClaude is neither bool nor null")
            }

            for field in ["stars", "openIssues"] where entry[field] != nil && !(entry[field] is NSNull) {
                XCTAssertTrue(entry[field] is Int, "\(ctx): \(field) not an integer")
            }
            if let archived = entry["archived"], !(archived is NSNull) {
                XCTAssertTrue(archived is Bool, "\(ctx): archived not a bool")
            }
            for field in ["lastCommitDate", "lastFetched"] {
                if let value = entry[field], !(value is NSNull) {
                    guard let string = value as? String, matches(Self.isoDate, string) else {
                        XCTFail("\(ctx): \(field) is not an ISO 8601 date (\(entry[field] ?? "?"))")
                        continue
                    }
                }
            }
        }
    }

    /// The tolerant app decoder must not drop a single entry of the committed
    /// registry — if it does, automation wrote something structurally broken.
    func testTolerantDecoderDropsNothing() throws {
        let data = try Data(contentsOf: Self.registryURL)
        let rawCount = (try JSONSerialization.jsonObject(with: data) as? [Any])?.count ?? -1
        let projects = try RegistryService.decodeRegistry(from: data)

        XCTAssertEqual(projects.count, rawCount, "Tolerant decoder dropped \(rawCount - projects.count) entries")
        XCTAssertFalse(projects.contains { $0.category == .other }, "Registry contains an unrecognized category")
        XCTAssertFalse(projects.contains { $0.platforms.contains(.unknown) }, "Registry contains an unrecognized platform")
        XCTAssertFalse(projects.contains { $0.authMethod.contains(.unknown) }, "Registry contains an unrecognized auth method")
    }
}

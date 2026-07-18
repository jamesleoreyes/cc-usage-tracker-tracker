import XCTest
@testable import CCUsageTrackerTracker

/// The app-side decoder must survive registry data written by a NEWER app/schema
/// than this build: unknown enum values fall back, malformed entries drop, and
/// the rest of the feed keeps working.
final class DecoderToleranceTests: XCTestCase {
    private func entryJSON(
        id: String = "someone/some-tracker",
        category: String = "CLI/Terminal",
        platforms: String = #"["macos"]"#,
        authMethod: String = #"["JSONL Log Parsing"]"#,
        extra: String = ""
    ) -> String {
        """
        {
          "id": "\(id)",
          "name": "some-tracker",
          "author": "someone",
          "repoURL": "https://github.com/\(id)",
          "description": "Tracks the usage of the trackers of the usage",
          "category": "\(category)",
          "platforms": \(platforms),
          "language": "Swift",
          "authMethod": \(authMethod),
          "features": [],
          "builtWithClaude": null,
          "stars": 5,
          "lastCommitDate": "2026-07-01T12:00:00Z",
          "openIssues": 0,
          "archived": false,
          "lastFetched": "2026-07-18T02:29:32.797Z"\(extra)
        }
        """
    }

    private func decode(_ json: String) throws -> [TrackerProject] {
        try RegistryService.decodeRegistry(from: Data(json.utf8))
    }

    func testUnknownCategoryFallsBackToOther() throws {
        let projects = try decode("[\(entryJSON(category: "Quantum Abacus"))]")
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].category, .other)
    }

    func testUnknownPlatformAndAuthMethodFallBack() throws {
        let projects = try decode("[\(entryJSON(platforms: #"["macos", "templeos"]"#, authMethod: #"["JSONL Log Parsing", "Vibes"]"#))]")
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].platforms, [.macos, .unknown])
        XCTAssertEqual(projects[0].authMethod, [.jsonlParsing, .unknown])
    }

    func testMalformedEntryIsDroppedOthersSurvive() throws {
        let broken = #"{"id": "broken/entry", "stars": "not-a-number"}"#
        let projects = try decode("[\(entryJSON(id: "a/first")), \(broken), \(entryJSON(id: "b/second"))]")
        XCTAssertEqual(projects.map(\.id), ["a/first", "b/second"])
    }

    func testInvalidDateDropsOnlyThatEntry() throws {
        let badDate = entryJSON(id: "bad/date").replacingOccurrences(
            of: "2026-07-01T12:00:00Z", with: "yesterday-ish"
        )
        let projects = try decode("[\(badDate), \(entryJSON(id: "good/entry"))]")
        XCTAssertEqual(projects.map(\.id), ["good/entry"])
    }

    func testBothDateFormatsParse() throws {
        // JS Date.toISOString() writes fractional seconds; the GitHub API doesn't.
        let projects = try decode("[\(entryJSON())]")
        XCTAssertEqual(projects.count, 1)
        XCTAssertNotNil(projects[0].lastCommitDate)
        XCTAssertNotNil(projects[0].lastFetched)
    }

    func testEmptyRegistryDecodes() throws {
        XCTAssertEqual(try decode("[]").count, 0)
    }

    func testCorruptTopLevelStillThrows() {
        // Wholesale corruption must still throw so callers fall back to the bundled copy.
        XCTAssertThrowsError(try decode(#"{"not": "an array"#))
    }
}

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCUsageTrackerTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CCUsageTrackerTracker",
            path: "Sources",
            resources: [
                .process("Resources/tracker-registry.json")
            ]
        )
    ]
)

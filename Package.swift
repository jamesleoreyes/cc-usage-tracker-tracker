// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCUsageTrackerTracker",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "CCUsageTrackerTracker",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            resources: [
                .process("Resources/tracker-registry.json")
            ],
            linkerSettings: [
                // SwiftPM links Sparkle with a @loader_path rpath, which covers
                // `swift run` (the framework sits next to the binary in .build/).
                // The bundled app needs one more: Contents/MacOS/<binary> ->
                // Contents/Frameworks/Sparkle.framework.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "CCUsageTrackerTrackerTests",
            dependencies: ["CCUsageTrackerTracker"],
            path: "Tests"
        )
    ]
)

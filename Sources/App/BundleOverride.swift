import Foundation

// Override SPM's generated Bundle.module accessor.
// SPM looks at Bundle.main.bundleURL (the .app root), but we put the resource
// bundle in Contents/Resources/ for proper code signing. This accessor checks
// both locations.
extension Foundation.Bundle {
    static let appBundle: Bundle = {
        let bundleName = "CCUsageTrackerTracker_CCUsageTrackerTracker"

        // 1. Contents/Resources/ (proper .app bundle location)
        if let resourceURL = Bundle.main.resourceURL {
            let path = resourceURL.appendingPathComponent(bundleName + ".bundle").path
            if let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // 2. Bundle root (where SPM's default accessor looks)
        let mainPath = Bundle.main.bundleURL.appendingPathComponent(bundleName + ".bundle").path
        if let bundle = Bundle(path: mainPath) {
            return bundle
        }

        // 3. Build directory fallback (swift run / development)
        let buildPath = Bundle.main.bundleURL.appendingPathComponent(bundleName + ".bundle").path
        if let bundle = Bundle(path: buildPath) {
            return bundle
        }

        fatalError("Could not load resource bundle: \(bundleName)")
    }()
}

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    let appState = AppState()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Load bundled registry immediately (instant, offline)
        do {
            let bundled = try RegistryService.loadBundledRegistry()
            if let cached = CacheService.load() {
                appState.projects = RegistryService.merge(primary: bundled, secondary: cached.projects)
                appState.dismissedIDs = cached.dismissedIDs
            } else {
                appState.projects = bundled
            }
        } catch {
            print("Failed to load registry: \(error)")
        }

        statusBarController = StatusBarController(appState: appState, onRefresh: { [weak self] in
            self?.refreshFromRemote()
        })

        // Fetch latest registry from GitHub
        refreshFromRemote()

        // Check for registry updates every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromRemote()
            }
        }
    }

    func refreshFromRemote() {
        guard !appState.isRefreshing else { return }
        appState.isRefreshing = true

        Task {
            if let remote = await RegistryService.fetchRemoteRegistry() {
                let merged = RegistryService.merge(primary: remote, secondary: appState.projects)
                appState.projects = merged
                appState.lastRefreshDate = Date()

                // Cache for offline use
                let cachedData = CachedData(
                    projects: appState.projects,
                    dismissedIDs: appState.dismissedIDs
                )
                CacheService.save(cachedData)
            }

            appState.isRefreshing = false
        }
    }
}

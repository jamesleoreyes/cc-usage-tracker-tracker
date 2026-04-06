import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    let appState = AppState()
    let gitHubService = GitHubService()
    let discoveryService = DiscoveryService()
    private var refreshTimer: Timer?
    private var discoveryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Load bundled registry + cache immediately (fast, offline)
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
            self?.refreshAll()
        })

        // Request notification permission
        NotificationService.requestPermission()

        // Fetch latest registry from GitHub (non-blocking)
        fetchRemoteRegistry()

        // Initial metadata refresh
        refreshAll()

        // Periodic refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }

        // Discovery every 6 hours
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.runDiscovery()
            }
        }
    }

    private func fetchRemoteRegistry() {
        Task {
            guard let remote = await RegistryService.fetchRemoteRegistry() else { return }
            // Merge: remote registry is the new primary (latest curated data),
            // current projects provide live metadata
            let merged = RegistryService.merge(primary: remote, secondary: appState.projects)
            let oldCount = appState.projects.count
            appState.projects = merged
            if merged.count > oldCount {
                print("Registry updated: \(oldCount) -> \(merged.count) projects")
            }
        }
    }

    private var githubToken: String? {
        KeychainService.load(key: "github-pat")
    }

    func refreshAll() {
        guard !appState.isRefreshing else { return }
        appState.isRefreshing = true
        let token = githubToken

        Task {
            for i in appState.projects.indices {
                let project = appState.projects[i]
                let updated = await gitHubService.refreshProject(project, token: token)
                appState.projects[i] = updated

                // Stagger requests: 1.5s between each to stay under rate limit
                if i < appState.projects.count - 1 {
                    try? await Task.sleep(for: .milliseconds(1500))
                }
            }

            appState.isRefreshing = false
            appState.lastRefreshDate = Date()
            saveCache()
        }
    }

    func runDiscovery() {
        let token = githubToken
        Task {
            let knownIDs = Set(appState.projects.map(\.id))
            let discovered = await discoveryService.searchForNewTrackers(
                knownIDs: knownIDs,
                dismissedIDs: appState.dismissedIDs,
                token: token
            )

            if !discovered.isEmpty {
                let newPending = discovered.map { repo in
                    TrackerProject(
                        id: repo.id,
                        name: repo.name,
                        author: repo.author,
                        repoURL: repo.repoURL,
                        description: repo.description,
                        category: .cli, // Default, user will set correctly when adding
                        platforms: [],
                        language: repo.language,
                        authMethod: [],
                        features: [],
                        builtWithClaude: nil,
                        stars: repo.stars
                    )
                }

                // Only add truly new ones (not already in pending)
                let existingPendingIDs = Set(appState.pendingProjects.map(\.id))
                let brandNew = newPending.filter { !existingPendingIDs.contains($0.id) }

                if !brandNew.isEmpty {
                    appState.pendingProjects.append(contentsOf: brandNew)
                    NotificationService.postNewTrackerNotification(count: brandNew.count)
                }
            }
        }
    }

    private func saveCache() {
        let cachedData = CachedData(
            projects: appState.projects,
            dismissedIDs: appState.dismissedIDs
        )
        CacheService.save(cachedData)
    }
}

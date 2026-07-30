import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    let appState = AppState()
    private var refreshTimer: Timer?
    private var previewWindow: NSWindow?

    // Started only when running from a real .app bundle (see below), so
    // `swift run` dev builds neither crash nor show Sparkle errors.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // A bare `swift run` executable has no Info.plist, so no feed URL —
        // Sparkle stays dormant and the menu item disables itself.
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            updaterController.startUpdater()
        }

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

        statusBarController = StatusBarController(
            appState: appState,
            updaterController: updaterController,
            onRefresh: { [weak self] in
                self?.refreshFromRemote()
            }
        )

        // Fetch latest registry from GitHub
        refreshFromRemote()

        // Check for registry updates every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromRemote()
            }
        }

        // Dev affordance: CCUTT_PREVIEW_WINDOW=1 opens the popover content in a
        // plain window at a known frame, so the UI can be seen (and screenshot)
        // without clicking the status item.
        if ProcessInfo.processInfo.environment["CCUTT_PREVIEW_WINDOW"] != nil {
            let window = NSWindow(
                contentViewController: NSHostingController(
                    rootView: PopoverContentView(appState: appState, onRefresh: { [weak self] in
                        self?.refreshFromRemote()
                    })
                )
            )
            window.title = "UI Preview"
            window.styleMask = [.titled, .closable]
            // Pin to a known spot near the screen's top-left so tooling can
            // screenshot a fixed region.
            let screenTop = NSScreen.main?.frame.maxY ?? 900
            window.setFrameTopLeftPoint(NSPoint(x: 100, y: screenTop - 40))
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = window
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

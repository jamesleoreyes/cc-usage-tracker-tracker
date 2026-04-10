# CC Usage Tracker Tracker

A native macOS status bar app that discovers, catalogs, and monitors every open-source project people have built to track their Claude AI usage.

**It does not track your Claude usage.** It tracks the trackers that track Claude usage.

## Install

Download the latest `.dmg` from [Releases](../../releases), open it, and drag **CC Usage Tracker Tracker** to your Applications folder.

Since the app isn't notarized with an Apple Developer ID, macOS may block it on first launch. To fix this, run once after installing:

```bash
xattr -cr /Applications/CCUsageTrackerTracker.app
```

The app lives in your menu bar (no Dock icon). Look for the number.

## What It Does

- Shows the count of known Claude usage tracker projects in your menu bar
- Click to open a dashboard with every project listed, searchable, filterable, and sortable
- Live metadata (stars, last commit, health status) updated automatically via GitHub Actions
- New tracker projects discovered automatically every 6 hours via GitHub Search API

## Features

- **Status bar icon** showing live count of tracked projects
- **Popover dashboard** with search, category filters, and sort options
- **Health indicators**: green (active), yellow (aging), red (stale/archived), skull (deleted)
- **Expandable detail** per project: features, auth methods, platforms, GitHub link
- **Automated discovery**: a GitHub Action finds new trackers and opens PRs for review
- **Automated metadata**: a GitHub Action updates stars, commit dates, and health every 4 hours
- **Stats section**: language census, platform spread, "Built with Claude" percentage
- **Instant loading**: the app reads a single JSON registry — no API calls, no loading spinners

## How It Works

The app itself makes **zero GitHub API calls**. All the heavy lifting happens in GitHub Actions:

- **Discovery** (`discover-trackers.yml`): Runs every 6 hours, searches GitHub for new Claude usage tracker repos, and opens a PR for review.
- **Metadata** (`update-registry.yml`): Runs every 4 hours, fetches stars, commit dates, archived status, and releases for every repo, then commits the updated registry directly to `main`.

The app just fetches `tracker-registry.json` from this repo on launch and displays it. One HTTP request, instant results.

## Build from Source

Requires macOS 14+ (Sonoma) and Swift 6.

```bash
# Build the .app bundle
make app

# Or build the .dmg installer
make dmg

# Or just run it directly
make run
```

The `.app` lands in `build/CCUsageTrackerTracker.app` and the `.dmg` in `build/`.

For development, `swift build && swift run` works but notifications will be disabled (they require a real `.app` bundle).

## FAQ

> **Q: Does this track my Claude usage?**
> No.
>
> **Q: Can I add usage tracking as a feature?**
> No, but you can use this app to find a tracker that tracks your usage.
>
> **Q: Is this app tracked by itself?**
> No. This is a tracker tracker, not a tracker tracker tracker. Including itself would create a paradox.
>
> **Q: Was this built with Claude Code?**
> Yes, I used Claude Code to build a tracker that tracks Claude usage trackers. It's trackers all the way down.
>
> **Q: Why does this exist?**
> Because there are more Claude usage trackers than there are hours in the rate limit window, and someone needed to track them.

## License

MIT

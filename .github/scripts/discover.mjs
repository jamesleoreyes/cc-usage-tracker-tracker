#!/usr/bin/env node

// Discovers new Claude usage tracker repos on GitHub and adds them to the registry.
// Runs as a GitHub Action on a schedule.

import { readFileSync, writeFileSync } from "fs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const GITHUB_API = "https://api.github.com";
const TOKEN = process.env.GH_TOKEN;

// Targeted search queries — each should return mostly relevant results
const SEARCH_QUERIES = [
  // Exact-phrase searches (most precise)
  '"claude usage" tracker',
  '"claude usage" monitor',
  '"claude usage" widget',
  '"claude usage" bar',
  '"claude code" usage monitor',
  '"claude code" usage tracker',
  '"claude code" usage widget',
  '"claude code" statusline',
  '"claude code" status line',
  '"claude code" "rate limit"',
  '"claude code" "menu bar"',
  // CC-prefix (scoped to avoid CI/CD cctray)
  "ccusage claude",
  "ccowl claude",
  "ccflare claude",
  // Statusline / powerline
  '"claude" statusline',
  '"claude" powerline',
  // Platform-specific
  '"claude" "menu bar" usage',
  '"claude" waybar usage',
  '"claude" tmux usage',
  '"claude" raycast usage',
  // Metaphor names (paired with claude to reduce noise)
  '"claude" hud usage',
  '"claude" meter usage',
  '"claude" pulse usage',
  // Token tracking
  '"claude" "token tracker"',
];

// Topic-based searches (more precise than keyword search)
const TOPIC_QUERIES = [
  "topic:claude-usage",
  "topic:ccusage",
  "topic:claude-code-usage",
  "topic:claude-usage-tracker",
  "topic:claude-usage-monitor",
];

// A repo must match at least one STRONG signal to be considered
const STRONG_SIGNALS = [
  "usage tracker",
  "usage monitor",
  "usage widget",
  "usage bar",
  "usage overlay",
  "usage dashboard",
  "usage extension",
  "rate limit",
  "rate-limit",
  "burn rate",
  "token usage",
  "token tracker",
  "token monitor",
  "cost tracker",
  "cost monitor",
  "statusline",
  "status line",
  "status-line",
  "powerline",
  "menu bar",
  "menubar",
  "system tray",
  "waybar",
];

// Repos matching these patterns are almost certainly not usage trackers
const REJECT_PATTERNS = [
  // CI/CD cctray XML format (completely unrelated)
  /\bcctray\b.*\b(jenkins|ci|xml|feed|build|semaphore|gocd|bamboo)\b/i,
  /\b(jenkins|ci|xml|feed|build|semaphore|gocd|bamboo)\b.*\bcctray\b/i,
  // Personal dotfiles / configs
  /^\.?dotfiles$/i,
  /\bmy-config\b/i,
  // Not about tracking usage
  /\b(chatbot|chat bot|assistant|prompt|template|tutorial|course|awesome-list)\b/i,
  /\b(proxy|relay|gateway|bridge|forwarder)\b/i,
  /\b(session.?manager|session.?keeper|keepalive)\b/i,
  /\b(behavioral|controller|organizer|kanban)\b/i,
  // Generic tools that happen to mention Claude
  /\b(stock.?market|fraud|competitive.?intel|voice.?pilot)\b/i,
];

// Repo names that are known false positive patterns
const NAME_REJECT_PATTERNS = [
  /^dotfiles$/i,
  /^\.files$/i,
  /config$/i,
  /-config$/i,
  /^homebrew-/i, // Homebrew tap repos, not the apps themselves
];

async function githubFetch(url) {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "cc-usage-tracker-tracker-discovery",
  };
  if (TOKEN) headers.Authorization = `Bearer ${TOKEN}`;

  const res = await fetch(url, { headers });
  if (res.status === 403 || res.status === 429) {
    console.warn(`Rate limited on ${url}, skipping`);
    return null;
  }
  if (!res.ok) {
    console.warn(`HTTP ${res.status} on ${url}`);
    return null;
  }
  return res.json();
}

async function searchRepos(query) {
  const url = `${GITHUB_API}/search/repositories?q=${encodeURIComponent(query)}&sort=updated&per_page=30`;
  const data = await githubFetch(url);
  return data?.items ?? [];
}

function isLikelyTracker(repo) {
  const name = repo.name.toLowerCase();
  const desc = (repo.description ?? "").toLowerCase();
  const topics = (repo.topics ?? []).join(" ").toLowerCase();
  const text = `${name} ${desc} ${topics}`;

  // --- Hard rejects ---

  // Skip forks (they're copies, not original projects)
  if (repo.fork) return false;

  // Skip repos with no description (too risky, can't judge relevance)
  if (!repo.description || repo.description.trim().length < 10) return false;

  // Skip archived repos
  if (repo.archived) return false;

  // Skip name-based rejects
  if (NAME_REJECT_PATTERNS.some((p) => p.test(name))) return false;

  // Skip content-based rejects
  if (REJECT_PATTERNS.some((p) => p.test(text))) return false;

  // --- Must have Claude connection ---
  const hasClaude =
    text.includes("claude") ||
    text.includes("anthropic") ||
    // "ccusage" is specific enough to Claude Code
    name.includes("ccusage") ||
    topics.includes("ccusage") ||
    topics.includes("claude-usage");

  if (!hasClaude) return false;

  // --- Must have a strong usage-tracking signal ---
  const hasStrongSignal = STRONG_SIGNALS.some((s) => text.includes(s));

  // If name strongly suggests a tracker, that's also good enough
  const nameSignal =
    /usage/i.test(name) ||
    /monitor/i.test(name) ||
    /tracker/i.test(name) ||
    /widget/i.test(name) ||
    /statusline/i.test(name) ||
    /powerline/i.test(name) ||
    /meter/i.test(name);

  return hasStrongSignal || nameSignal;
}

function guessCategory(repo) {
  const text =
    `${repo.name} ${repo.description ?? ""} ${(repo.topics ?? []).join(" ")}`.toLowerCase();

  if (text.includes("statusline") || text.includes("status-line") || text.includes("powerline"))
    return "Statusline";
  if (text.includes("waybar")) return "Waybar Module";
  if (text.includes("tmux")) return "Tmux Plugin";
  if (text.includes("neovim") || text.includes("nvim")) return "Neovim Plugin";
  if (text.includes("vscode") || text.includes("vs code")) return "VS Code Extension";
  if (text.includes("raycast")) return "Raycast Extension";
  if (
    text.includes("ubersicht") ||
    text.includes("übersicht") ||
    text.includes("uebersicht")
  )
    return "Übersicht Widget";
  if (text.includes("menu bar") || text.includes("menubar"))
    return "macOS Native";
  if (text.includes("browser") || text.includes("chrome extension"))
    return "Browser Extension";
  if (text.includes("electron") || text.includes("desktop widget"))
    return "Electron/Desktop";
  if (text.includes("overlay")) return "Desktop Overlay";
  if (text.includes("dashboard")) return "Web Dashboard";
  if (text.includes("tui")) return "Terminal UI";
  if (text.includes("android") || text.includes("ios")) return "Mobile";
  if (text.includes("cli") || text.includes("terminal")) return "CLI/Terminal";

  // Guess from language
  const lang = (repo.language ?? "").toLowerCase();
  if (lang === "swift") return "macOS Native";
  if (lang === "java" || lang === "kotlin") return "Mobile";

  return "CLI/Terminal";
}

async function main() {
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));
  const knownIDs = new Set(registry.map((p) => p.id));
  console.log(`Current registry: ${registry.length} projects`);

  const candidates = new Map();

  for (const query of [...SEARCH_QUERIES, ...TOPIC_QUERIES]) {
    console.log(`Searching: ${query}`);
    const repos = await searchRepos(query);

    for (const repo of repos) {
      if (knownIDs.has(repo.full_name) || candidates.has(repo.full_name)) continue;
      if (isLikelyTracker(repo)) {
        candidates.set(repo.full_name, repo);
      }
    }

    // Respect rate limits
    await new Promise((r) => setTimeout(r, 2000));
  }

  console.log(`\nFound ${candidates.size} new candidates`);

  if (candidates.size === 0) {
    console.log("No new trackers found");
    return;
  }

  // Cap at 50 per run to keep PRs reviewable
  const toAdd = [...candidates.values()].slice(0, 50);
  if (candidates.size > 50) {
    console.log(`Capping at 50 (${candidates.size - 50} deferred to next run)`);
  }

  for (const repo of toAdd) {
    const entry = {
      id: repo.full_name,
      name: repo.name,
      author: repo.owner.login,
      repoURL: repo.html_url,
      description: repo.description ?? "",
      category: guessCategory(repo),
      platforms: [],
      language: repo.language ?? "Unknown",
      authMethod: [],
      features: [],
      builtWithClaude: null,
    };
    registry.push(entry);
    console.log(`  + ${repo.full_name} [${entry.category}] — ${entry.description.slice(0, 80)}`);
  }

  writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + "\n");
  console.log(`\nRegistry updated: ${registry.length} projects (+${toAdd.length})`);
}

main().catch(console.error);

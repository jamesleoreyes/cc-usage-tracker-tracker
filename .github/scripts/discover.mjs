#!/usr/bin/env node

// Discovers new Claude usage tracker repos on GitHub and adds them to the registry.
// Runs as a GitHub Action on a schedule.

import { readFileSync, writeFileSync } from "fs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const GITHUB_API = "https://api.github.com";
const TOKEN = process.env.GH_TOKEN;

const SEARCH_QUERIES = [
  // Literal naming patterns
  "claude+usage+tracker",
  "claude+usage+monitor",
  "claude+usage+widget",
  "claude+usage+bar",
  "claude+code+usage",
  "claude+code+monitor",
  "claude+code+tracker",
  "claude+rate+limit",
  // CC prefix pattern
  "ccusage",
  "ccstatusline",
  "cctray",
  "ccowl",
  "ccflare",
  // Statusline / powerline
  "claude+statusline",
  "claude+powerline",
  "claude+code+statusline",
  "claude+code+status+line",
  // Metaphor names
  "claude+hud",
  "claude+meter",
  "claude+pulse",
  "claude+bar",
  // Token tracking
  "claude+token+tracker",
  "tokscale+claude",
  "toktrack+claude",
  // Platform-specific
  "claude+menu+bar+macos",
  "claude+waybar",
  "claude+tmux+status",
  "claude+neovim+usage",
  "claude+vscode+usage",
  "claude+raycast+usage",
];

// GitHub Topics that tracker repos commonly use
const TOPIC_QUERIES = [
  "topic:claude-usage",
  "topic:ccusage",
  "topic:claude-code",
  "topic:claude-code-usage",
  "topic:claude-monitor",
];

// Keywords in repo description that suggest it's a usage tracker
const RELEVANCE_KEYWORDS = [
  "usage",
  "monitor",
  "tracker",
  "token",
  "rate limit",
  "status bar",
  "statusline",
  "menu bar",
  "menubar",
  "widget",
  "dashboard",
  "cost",
  "burn rate",
  "quota",
  "limit",
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
  const url = `${GITHUB_API}/search/repositories?q=${encodeURIComponent(query)}&sort=updated&per_page=50`;
  const data = await githubFetch(url);
  return data?.items ?? [];
}

function isLikelyTracker(repo) {
  const text =
    `${repo.full_name} ${repo.description ?? ""} ${(repo.topics ?? []).join(" ")}`.toLowerCase();

  // Must have some connection to Claude/Anthropic/CC
  const hasClaude =
    text.includes("claude") ||
    text.includes("anthropic") ||
    text.includes("ccusage") ||
    /\bcc[a-z]/.test(text);
  if (!hasClaude) return false;

  // Must have some tracker/monitor signal
  return RELEVANCE_KEYWORDS.some((kw) => text.includes(kw));
}

function guessCategory(repo) {
  const text =
    `${repo.full_name} ${repo.description ?? ""} ${(repo.topics ?? []).join(" ")}`.toLowerCase();

  if (text.includes("statusline") || text.includes("status-line") || text.includes("powerline"))
    return "Statusline";
  if (text.includes("menu bar") || text.includes("menubar") || text.includes("macos native"))
    return "macOS Native";
  if (text.includes("waybar")) return "Waybar Module";
  if (text.includes("tmux")) return "Tmux Plugin";
  if (text.includes("neovim") || text.includes("nvim")) return "Neovim Plugin";
  if (text.includes("vscode") || text.includes("vs code")) return "VS Code Extension";
  if (text.includes("raycast")) return "Raycast Extension";
  if (text.includes("browser") || text.includes("extension") || text.includes("chrome"))
    return "Browser Extension";
  if (text.includes("electron") || text.includes("desktop widget")) return "Electron/Desktop";
  if (text.includes("ubersicht") || text.includes("übersicht")) return "Übersicht Widget";
  if (text.includes("web") || text.includes("dashboard")) return "Web Dashboard";
  if (text.includes("overlay")) return "Desktop Overlay";
  if (text.includes("cli") || text.includes("terminal")) return "CLI/Terminal";
  if (text.includes("tui") || text.includes("rich")) return "Terminal UI";
  if (text.includes("android") || text.includes("ios") || text.includes("mobile")) return "Mobile";
  return "CLI/Terminal"; // default
}

async function main() {
  // Load current registry
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));
  const knownIDs = new Set(registry.map((p) => p.id));
  console.log(`Current registry: ${registry.length} projects`);

  // Collect candidates from all searches
  const candidates = new Map();

  // Search queries
  for (const query of [...SEARCH_QUERIES, ...TOPIC_QUERIES]) {
    console.log(`Searching: ${query}`);
    const repos = await searchRepos(query);
    for (const repo of repos) {
      if (!knownIDs.has(repo.full_name) && !candidates.has(repo.full_name)) {
        if (isLikelyTracker(repo)) {
          candidates.set(repo.full_name, repo);
        }
      }
    }
    // Respect rate limits: 2s between searches
    await new Promise((r) => setTimeout(r, 2000));
  }

  console.log(`Found ${candidates.size} new candidates`);

  if (candidates.size === 0) {
    console.log("No new trackers found");
    return;
  }

  // Add new entries to registry
  for (const [, repo] of candidates) {
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
    console.log(`  + ${repo.full_name} (${entry.category})`);
  }

  // Write updated registry
  writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + "\n");
  console.log(`Registry updated: ${registry.length} projects`);
}

main().catch(console.error);

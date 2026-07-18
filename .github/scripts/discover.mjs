#!/usr/bin/env node

// Discovers new Claude usage tracker repos on GitHub and adds them to the registry.
// Runs as a GitHub Action on a schedule.

import { readFileSync, writeFileSync } from "fs";
import { classifyRepo, gatherEvidence, DEFAULT_MODEL } from "./classify.mjs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const REJECTED_PATH = ".github/data/rejected.json";
const GITHUB_API = "https://api.github.com";
const TOKEN = process.env.GH_TOKEN;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const CLASSIFIER_MODEL = process.env.CLASSIFIER_MODEL ?? DEFAULT_MODEL;
const CONFIDENCE_THRESHOLD = 0.6;
const CLASSIFY_CAP = 40; // cost guard; deferred candidates re-surface next run

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

// Repos matching these patterns are almost certainly not usage trackers.
// Curation rule: an entry must display, measure, or report Claude usage as a
// substantial feature. Account poolers, setup kits, and orchestrators don't count.
const REJECT_PATTERNS = [
  // Account poolers / credential rotators (circumvent limits rather than track them)
  /\b(pools?|pooling|rotat\w+|swap\w*)\b.{0,24}\b(accounts?|credentials?|keys?)\b/i,
  /\baccounts?\b.{0,24}\b(pool\w*|rotat\w+|swap\w*)\b/i,
  /\breverse\s+prox(y|ies)\b/i,
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

  // lol
  if (repo.full_name === "jamesleoreyes/cc-usage-tracker-tracker") return false;

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

function loadRejected() {
  try {
    return JSON.parse(readFileSync(REJECTED_PATH, "utf-8"));
  } catch {
    return [];
  }
}

async function main() {
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));
  const rejected = loadRejected();
  // Classifier-rejected repos are remembered so they aren't re-fetched and
  // re-classified every 6 hours for as long as they keep matching a search.
  const knownIDs = new Set([...registry.map((p) => p.id), ...rejected.map((r) => r.id)]);
  console.log(`Current registry: ${registry.length} projects (+${rejected.length} remembered rejects)`);

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

  // Second stage: LLM classification with deterministic evidence. Without an
  // API key (or on API failure) discovery falls open to the heuristic-only
  // behavior — the classifier improves quality, it must never block discovery.
  const accepted = [];
  const newlyRejected = [];

  if (ANTHROPIC_API_KEY) {
    const toClassify = [...candidates.values()].slice(0, CLASSIFY_CAP);
    const deferred = candidates.size - toClassify.length;
    if (deferred > 0) console.log(`Classifying ${toClassify.length}, deferring ${deferred} to the next run`);

    for (const repo of toClassify) {
      let verdict = null;
      let evidence = { readme: null, claudeCommitEvidence: null };
      try {
        evidence = await gatherEvidence(repo.full_name, TOKEN);
        verdict = await classifyRepo(repo, evidence, { apiKey: ANTHROPIC_API_KEY, model: CLASSIFIER_MODEL });
      } catch (e) {
        console.warn(`  ? ${repo.full_name}: classifier unavailable (${e.message.slice(0, 80)}), accepting heuristically`);
        accepted.push({ repo, verdict: null });
        continue;
      }

      if (verdict.is_tracker && verdict.confidence >= CONFIDENCE_THRESHOLD) {
        console.log(`  ✓ ${repo.full_name} (${verdict.confidence.toFixed(2)}) [${verdict.category}] — ${verdict.reason.slice(0, 80)}`);
        accepted.push({ repo, verdict });
      } else {
        console.log(`  ✗ ${repo.full_name} (${verdict.confidence.toFixed(2)}) — ${verdict.reason.slice(0, 100)}`);
        newlyRejected.push({
          id: repo.full_name,
          reason: verdict.reason,
          confidence: verdict.confidence,
          rejectedAt: new Date().toISOString(),
        });
      }
    }
  } else {
    console.log("ANTHROPIC_API_KEY not set — accepting all candidates heuristically (no classification)");
    for (const repo of candidates.values()) accepted.push({ repo, verdict: null });
  }

  for (const { repo, verdict } of accepted) {
    const entry = {
      id: repo.full_name,
      name: repo.name,
      author: repo.owner.login,
      repoURL: repo.html_url,
      description: repo.description ?? "",
      category: verdict?.category ?? guessCategory(repo),
      platforms: verdict?.platforms ?? [],
      language: repo.language ?? "Unknown",
      authMethod: verdict?.auth_methods ?? [],
      features: verdict?.features ?? [],
      builtWithClaude: verdict?.built_with_claude ?? null,
      stars: repo.stargazers_count ?? 0,
      lastCommitDate: repo.pushed_at ?? null,
      openIssues: repo.open_issues_count ?? 0,
      archived: repo.archived ?? false,
      lastFetched: new Date().toISOString(),
    };
    registry.push(entry);
    console.log(`  + ${repo.full_name} [${entry.category}] ★${entry.stars} — ${entry.description.slice(0, 70)}`);
  }

  if (accepted.length > 0) {
    writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + "\n");
  }
  if (newlyRejected.length > 0) {
    writeFileSync(REJECTED_PATH, JSON.stringify([...rejected, ...newlyRejected], null, 2) + "\n");
  }
  console.log(`\nRegistry updated: ${registry.length} projects (+${accepted.length}, rejected ${newlyRejected.length})`);
}

main().catch(console.error);

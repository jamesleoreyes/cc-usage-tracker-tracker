#!/usr/bin/env node

// LLM classification for discovered tracker candidates.
//
// Design: the LLM never calls tools. Evidence (README, commit history) is
// gathered deterministically here and passed INTO one structured-output
// classification call. builtWithClaude is decided by hard commit evidence
// when available — the model only fills the gap when there is none.
//
// Zero dependencies, matching the rest of the scripts: raw fetch against
// the GitHub and Anthropic APIs.

const GITHUB_API = "https://api.github.com";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
// Cheap by default — this runs on every discovery cycle. Override with
// CLASSIFIER_MODEL (workflow) or --model (backfill) if a batch needs more judgment.
export const DEFAULT_MODEL = "claude-haiku-4-5";

// Keep in sync with Sources/Models/TrackerProject.swift. The strict CI test
// (Tests/RegistryValidationTests.swift) fails if the registry ever contains a
// value outside the Swift enums, so drift here is caught before it ships.
export const CATEGORIES = [
  "macOS Native", "Electron/Desktop", "CLI/Terminal", "Terminal UI",
  "Browser Extension", "Web Dashboard", "Mobile", "Statusline",
  "Übersicht Widget", "VS Code Extension", "Neovim Plugin", "Raycast Extension",
  "Tmux Plugin", "Waybar Module", "Desktop Overlay", "Claude Code Plugin",
];
export const PLATFORMS = [
  "macos", "windows", "linux", "android", "ios", "web", "chromium", "firefox",
  "vscode", "neovim", "raycast", "tmux",
];
export const AUTH_METHODS = [
  "OAuth Token", "Session Cookie", "Session Key", "JSONL Log Parsing",
  "API Key", "Browser Cookie Auto-detect", "OpenTelemetry", "Traffic Capture",
];

export const VERDICT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "is_tracker", "confidence", "category", "platforms", "auth_methods",
    "features", "built_with_claude", "reason",
  ],
  properties: {
    is_tracker: {
      type: "boolean",
      description: "true only if the project displays, measures, or reports Claude usage as a substantial feature",
    },
    confidence: {
      type: "number",
      description: "0.0-1.0 confidence in the is_tracker judgment",
    },
    category: { type: "string", enum: CATEGORIES },
    platforms: { type: "array", items: { type: "string", enum: PLATFORMS } },
    auth_methods: { type: "array", items: { type: "string", enum: AUTH_METHODS } },
    features: {
      type: "array",
      items: { type: "string" },
      description: "up to 8 short kebab-case feature tags, e.g. burn-rate-alerts, multi-account",
    },
    built_with_claude: {
      type: ["boolean", "null"],
      description: "true only if the README or metadata claims it was built with Claude/Claude Code; null if unknown. Never guess false.",
    },
    reason: { type: "string", description: "one sentence explaining the verdict" },
  },
};

export const CURATOR_SYSTEM_PROMPT = `You curate the registry of a satirical-but-real catalog of Claude usage trackers: open-source projects people built to track their Claude/Claude Code usage.

The inclusion rule: a project belongs in the registry only if it displays, measures, or reports Claude usage (tokens, cost, rate limits, quotas, sessions, context) as a substantial feature. Statuslines, menu bar apps, dashboards, TUIs, widgets, hardware displays, usage-analytics skills, and multi-provider trackers that include Claude all qualify — even scrappy or joke-flavored ones. Projects that do NOT qualify: account poolers/rotators/switchers with no usage display, personal dotfiles/setup collections, orchestrators and model routers without a usage display, generic Claude skills unrelated to usage, proxies, starter kits, and mirrors of other projects.

Judge from the provided metadata, README excerpt, and commit evidence. Calibrate confidence honestly: 0.9+ only when the purpose is unmistakable, below 0.6 when you are genuinely unsure. For built_with_claude, answer true only when the README or description claims Claude/Claude Code was used to build it; otherwise null — never false, since absence of a claim proves nothing.`;

// --- deterministic evidence -------------------------------------------------

async function githubJSON(url, token, accept = "application/vnd.github+json") {
  const res = await fetch(url, {
    headers: {
      Accept: accept,
      "User-Agent": "cc-usage-tracker-tracker-classifier",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  if (!res.ok) return { _status: res.status, _remaining: res.headers.get("x-ratelimit-remaining"), _reset: res.headers.get("x-ratelimit-reset") };
  const body = accept.includes("raw") ? await res.text() : await res.json();
  return { _status: 200, _remaining: res.headers.get("x-ratelimit-remaining"), _reset: res.headers.get("x-ratelimit-reset"), body };
}

const CLAUDE_BOT_LOGIN = /^(claude|claude-code)(\[bot\])?$/i;
const CLAUDE_TRAILER = /co-authored-by:.*(claude\b|noreply@anthropic\.com)/i;
const CLAUDE_GENERATED = /generated with.*claude/i;

/// Gather README + commit-history evidence for one repo. Fails open: any
/// GitHub error just yields nulls and classification proceeds without it.
export async function gatherEvidence(fullName, ghToken) {
  const evidence = { readme: null, claudeCommitEvidence: null, rateLimit: null };

  const readme = await githubJSON(`${GITHUB_API}/repos/${fullName}/readme`, ghToken, "application/vnd.github.raw+json");
  evidence.rateLimit = readme._remaining;
  if (readme._status === 200 && typeof readme.body === "string") {
    evidence.readme = readme.body.slice(0, 6000);
  }

  const commits = await githubJSON(`${GITHUB_API}/repos/${fullName}/commits?per_page=30`, ghToken);
  evidence.rateLimit = commits._remaining ?? evidence.rateLimit;
  if (commits._status === 200 && Array.isArray(commits.body)) {
    let trailered = 0;
    let botAuthored = 0;
    for (const c of commits.body) {
      const message = c.commit?.message ?? "";
      const emails = [c.commit?.author?.email, c.commit?.committer?.email].filter(Boolean);
      const logins = [c.author?.login, c.committer?.login].filter(Boolean);
      if (CLAUDE_TRAILER.test(message) || CLAUDE_GENERATED.test(message) || emails.some((e) => e.includes("noreply@anthropic.com"))) trailered++;
      if (logins.some((l) => CLAUDE_BOT_LOGIN.test(l))) botAuthored++;
    }
    if (trailered > 0 || botAuthored > 0) {
      const parts = [];
      if (trailered > 0) parts.push(`${trailered}/${commits.body.length} recent commits carry Claude co-author/generated-with trailers`);
      if (botAuthored > 0) parts.push(`${botAuthored}/${commits.body.length} recent commits are authored by a claude bot account`);
      evidence.claudeCommitEvidence = parts.join("; ");
    }
  }

  return evidence;
}

// --- classification ---------------------------------------------------------

export function buildClassificationPrompt(repo, evidence) {
  const meta = [
    `Repository: ${repo.full_name ?? repo.id}`,
    `Description: ${repo.description ?? "(none)"}`,
    `Topics: ${(repo.topics ?? []).join(", ") || "(none)"}`,
    `Primary language: ${repo.language ?? "Unknown"}`,
    `Stars: ${repo.stargazers_count ?? repo.stars ?? 0}`,
  ].join("\n");

  const commitLine = evidence.claudeCommitEvidence
    ? `Commit evidence (deterministic): ${evidence.claudeCommitEvidence} — built_with_claude is being set to true from this evidence regardless of your answer.`
    : "Commit evidence (deterministic): none found in the 30 most recent commits.";

  const readmeBlock = evidence.readme
    ? `README excerpt (truncated):\n---\n${evidence.readme}\n---`
    : "README: unavailable.";

  return `${meta}\n\n${commitLine}\n\n${readmeBlock}\n\nClassify this repository.`;
}

async function anthropicRequest(body, apiKey, attempt = 0) {
  const res = await fetch(ANTHROPIC_API, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });
  if ((res.status === 429 || res.status === 529 || res.status >= 500) && attempt < 3) {
    const retryAfter = parseInt(res.headers.get("retry-after") ?? "0", 10);
    const delay = Math.max(retryAfter * 1000, 2000 * 2 ** attempt);
    await new Promise((r) => setTimeout(r, delay));
    return anthropicRequest(body, apiKey, attempt + 1);
  }
  if (!res.ok) throw new Error(`Anthropic API ${res.status}: ${(await res.text()).slice(0, 200)}`);
  return res.json();
}

export function buildMessageParams(repo, evidence, model) {
  return {
    model,
    max_tokens: 1024,
    system: CURATOR_SYSTEM_PROMPT,
    output_config: { format: { type: "json_schema", schema: VERDICT_SCHEMA } },
    messages: [{ role: "user", content: buildClassificationPrompt(repo, evidence) }],
  };
}

export function parseVerdict(response, evidence) {
  if (response.stop_reason === "refusal" || response.stop_reason === "max_tokens") {
    throw new Error(`classification stopped: ${response.stop_reason}`);
  }
  const text = response.content?.find((b) => b.type === "text")?.text;
  if (!text) throw new Error("classification returned no text block");
  const verdict = JSON.parse(text);
  verdict.confidence = Math.max(0, Math.min(1, verdict.confidence));
  verdict.features = (verdict.features ?? []).slice(0, 8);
  // Hard evidence outranks the model; absence of evidence proves nothing.
  verdict.built_with_claude = evidence.claudeCommitEvidence
    ? true
    : verdict.built_with_claude === true ? true : null;
  return verdict;
}

/// Classify one candidate repo. Throws on API failure — callers decide the
/// fallback (discovery fails open to the heuristic path).
export async function classifyRepo(repo, evidence, { apiKey, model = DEFAULT_MODEL }) {
  const response = await anthropicRequest(buildMessageParams(repo, evidence, model), apiKey);
  return parseVerdict(response, evidence);
}

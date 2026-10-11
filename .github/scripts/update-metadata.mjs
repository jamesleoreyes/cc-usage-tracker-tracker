#!/usr/bin/env node

// Fetches live GitHub metadata (stars, last commit, archived, open issues,
// latest release) for repos in the registry and writes it back, following
// renamed and transferred repos to their current name.
// Runs as a GitHub Action on a schedule.
//
// The registry is larger than one run's API budget, so each run refreshes the
// BATCH_LIMIT stalest entries (by lastFetched) and the schedule rotates
// through everything over ~a day and a half.

import { appendFileSync, readFileSync, writeFileSync } from "fs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const GITHUB_API = "https://api.github.com";
const TOKEN = process.env.GH_TOKEN;
const BATCH_LIMIT = parseInt(process.env.BATCH_LIMIT ?? "400", 10);

let rateLimited = false;

async function githubFetch(url) {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "cc-usage-tracker-tracker",
  };
  if (TOKEN) headers.Authorization = `Bearer ${TOKEN}`;

  const res = await fetch(url, { headers });

  // Log rate limit status periodically
  const remaining = res.headers.get("X-RateLimit-Remaining");
  if (remaining && parseInt(remaining) % 100 === 0) {
    console.log(`  Rate limit remaining: ${remaining}`);
  }

  if (res.status === 403 || res.status === 429) {
    const reset = res.headers.get("X-RateLimit-Reset");
    const waitUntil = reset ? new Date(parseInt(reset) * 1000).toISOString() : "unknown";
    console.warn(`Rate limited, resets at ${waitUntil}`);
    rateLimited = true;
    return null;
  }
  if (res.status === 404) return { _notFound: true };
  if (!res.ok) return null;
  return res.json();
}

async function fetchRepoMetadata(owner, repo) {
  const data = await githubFetch(`${GITHUB_API}/repos/${owner}/${repo}`);
  if (!data) return null;
  if (data._notFound) return { notFound: true };

  return {
    // GitHub redirects renamed and transferred repos, so these can differ from
    // the registry entry that asked — that's how renames are detected.
    fullName: data.full_name,
    name: data.name,
    owner: data.owner?.login,
    repoURL: data.html_url,
    stars: data.stargazers_count ?? 0,
    lastCommitDate: data.pushed_at ?? null,
    openIssues: data.open_issues_count ?? 0,
    archived: data.archived ?? false,
  };
}

async function fetchLatestRelease(owner, repo) {
  const data = await githubFetch(`${GITHUB_API}/repos/${owner}/${repo}/releases/latest`);
  if (!data || data._notFound) return null;
  return data.tag_name ?? null;
}

const CLASSIFICATION_FIELDS = ["category", "platforms", "authMethod", "features", "builtWithClaude"];
const isUnclassified = (p) =>
  !(p.platforms ?? []).length && !(p.authMethod ?? []).length && !(p.features ?? []).length;

async function main() {
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));

  // Refresh the stalest entries first. Sorting a copy of object references
  // means updates land in the original array without changing its order.
  const batch = [...registry]
    .sort((a, b) => (a.lastFetched ?? "").localeCompare(b.lastFetched ?? ""))
    .slice(0, BATCH_LIMIT);
  console.log(`Registry has ${registry.length} projects; refreshing the ${batch.length} stalest...`);

  // A renamed or transferred repo keeps its old id here, while discovery
  // searches by current name and adds it again — so a stale id is both wrong
  // and a duplicate in waiting. Fix the id, or drop the entry when the repo is
  // already listed under its current name.
  const byID = new Map(registry.map((p) => [p.id.toLowerCase(), p]));
  const dropped = new Set();

  let updated = 0;
  let renamed = 0;
  let notFound = 0;
  let errors = 0;

  for (let i = 0; i < batch.length; i++) {
    if (rateLimited) {
      console.warn(`Stopping early at ${i}/${batch.length} — rate limited; the rest stay stalest and go first next run`);
      break;
    }
    const project = batch[i];
    const [owner, repo] = project.id.split("/");

    if (!owner || !repo) {
      console.warn(`  Skipping invalid id: ${project.id}`);
      continue;
    }

    const metadata = await fetchRepoMetadata(owner, repo);
    if (!metadata) {
      errors++;
      continue;
    }

    if (metadata.notFound) {
      project.archived = true;
      project.lastFetched = new Date().toISOString();
      notFound++;
      console.log(`  [404] ${project.id}`);
      continue;
    }

    if (metadata.fullName && metadata.fullName !== project.id) {
      const listed = byID.get(metadata.fullName.toLowerCase());
      if (listed && listed !== project) {
        // An entry added after the rename while the classifier was down has no
        // classification of its own — keep this one's rather than lose it.
        if (isUnclassified(listed) && !isUnclassified(project)) {
          for (const field of CLASSIFICATION_FIELDS) listed[field] = project[field];
        }
        dropped.add(project);
        console.log(`  [duplicate] ${project.id} is now ${metadata.fullName}, already listed — dropped`);
        continue;
      }
      console.log(`  [renamed] ${project.id} -> ${metadata.fullName}`);
      byID.delete(project.id.toLowerCase());
      project.id = metadata.fullName;
      project.name = metadata.name;
      project.author = metadata.owner;
      project.repoURL = metadata.repoURL;
      byID.set(project.id.toLowerCase(), project);
      renamed++;
    }

    project.stars = metadata.stars;
    project.lastCommitDate = metadata.lastCommitDate;
    project.openIssues = metadata.openIssues;
    project.archived = metadata.archived;
    project.lastFetched = new Date().toISOString();

    // Fetch latest release (skip if rate limited)
    const release = await fetchLatestRelease(...project.id.split("/"));
    if (release) {
      project.latestRelease = release;
    }

    updated++;

    // Progress log every 50 repos
    if ((i + 1) % 50 === 0) {
      console.log(`  Progress: ${i + 1}/${batch.length}`);
    }

    // Small delay to be respectful (GITHUB_TOKEN gets 1000 req/hr for search, 5000 for REST)
    await new Promise((r) => setTimeout(r, 100));
  }

  // Write back; filtering out the dropped duplicates keeps everything else in order
  writeFileSync(REGISTRY_PATH, JSON.stringify(registry.filter((p) => !dropped.has(p)), null, 2) + "\n");
  if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `renamed=${renamed}\ndropped=${dropped.size}\n`);
  console.log(
    `\nDone: ${updated} updated, ${renamed} renamed, ${dropped.size} duplicates dropped, ${notFound} not found, ${errors} errors`
  );
}

main().catch(console.error);

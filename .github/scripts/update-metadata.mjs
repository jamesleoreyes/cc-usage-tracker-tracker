#!/usr/bin/env node

// Fetches live GitHub metadata (stars, last commit, archived, open issues,
// latest release) for every repo in the registry and writes it back.
// Runs as a GitHub Action on a schedule.

import { readFileSync, writeFileSync } from "fs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const GITHUB_API = "https://api.github.com";
const TOKEN = process.env.GH_TOKEN;

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

async function main() {
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));
  console.log(`Updating metadata for ${registry.length} projects...`);

  let updated = 0;
  let notFound = 0;
  let errors = 0;

  for (let i = 0; i < registry.length; i++) {
    const project = registry[i];
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

    project.stars = metadata.stars;
    project.lastCommitDate = metadata.lastCommitDate;
    project.openIssues = metadata.openIssues;
    project.archived = metadata.archived;
    project.lastFetched = new Date().toISOString();

    // Fetch latest release (skip if rate limited)
    const release = await fetchLatestRelease(owner, repo);
    if (release) {
      project.latestRelease = release;
    }

    updated++;

    // Progress log every 50 repos
    if ((i + 1) % 50 === 0) {
      console.log(`  Progress: ${i + 1}/${registry.length}`);
    }

    // Small delay to be respectful (GITHUB_TOKEN gets 1000 req/hr for search, 5000 for REST)
    await new Promise((r) => setTimeout(r, 100));
  }

  // Write back
  writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + "\n");
  console.log(`\nDone: ${updated} updated, ${notFound} not found, ${errors} errors`);
}

main().catch(console.error);

#!/usr/bin/env node

// One-off enrichment backfill for discovery-era registry entries (the ones
// with empty platforms/authMethod/features). Uses the Anthropic Message
// Batches API (50% of standard pricing) with the same evidence + schema as
// the live classifier.
//
// Usage:
//   ANTHROPIC_API_KEY=... GH_TOKEN=$(gh auth token) node .github/scripts/backfill-enrich.mjs [flags]
//
// Flags:
//   --yes                 required to actually submit (spend gate)
//   --model <id>          default claude-opus-4-8
//   --limit <n>           only process the first n entries (for a cheap test run)
//   --evidence-cache <p>  evidence cache file, default ./backfill-evidence.json (resumable)
//   --batch-id <id>       skip straight to polling/applying an already-submitted batch
//
// Phases (each resumable):
//   A. Gather README + commit evidence per repo (GitHub API, rate-limit aware, ~90 min for 3.3k)
//   B. Submit one message batch; poll until ended
//   C. Apply verdicts to the registry; flagged non-trackers go to backfill-flagged.json for review

import { readFileSync, writeFileSync, existsSync } from "fs";
import {
  gatherEvidence, buildMessageParams, parseVerdict, DEFAULT_MODEL,
} from "./classify.mjs";

const REGISTRY_PATH = "Sources/Resources/tracker-registry.json";
const FLAGGED_PATH = "backfill-flagged.json";
const BATCH_MAP_PATH = "backfill-batch-map.json";
const BATCHES_API = "https://api.anthropic.com/v1/messages/batches";

const API_KEY = process.env.ANTHROPIC_API_KEY;
const GH_TOKEN = process.env.GH_TOKEN;

// $/MTok at batch (50%) rates: [input, output]
const BATCH_PRICING = {
  "claude-opus-4-8": [2.5, 12.5],
  "claude-sonnet-5": [1.5, 7.5],
  "claude-haiku-4-5": [0.5, 2.5],
};

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const MODEL = flag("model") ?? DEFAULT_MODEL;
const LIMIT = flag("limit") ? parseInt(flag("limit"), 10) : Infinity;
const CACHE_PATH = flag("evidence-cache") ?? "./backfill-evidence.json";
const RESUME_BATCH_ID = flag("batch-id");
const CONFIRMED = args.includes("--yes");

if (!API_KEY) {
  console.error("ANTHROPIC_API_KEY is required");
  process.exit(1);
}

const anthropicHeaders = {
  "Content-Type": "application/json",
  "x-api-key": API_KEY,
  "anthropic-version": "2023-06-01",
};

function selectTargets(registry) {
  return registry.filter(
    (p) => (p.platforms ?? []).length === 0
      && (p.authMethod ?? []).length === 0
      && (p.features ?? []).length === 0,
  );
}

async function phaseA(targets) {
  const cache = existsSync(CACHE_PATH) ? JSON.parse(readFileSync(CACHE_PATH, "utf-8")) : {};
  const pending = targets.filter((p) => !(p.id in cache));
  console.log(`Phase A — evidence: ${Object.keys(cache).length} cached, ${pending.length} to fetch`);

  let done = 0;
  for (const project of pending) {
    const evidence = await gatherEvidence(project.id, GH_TOKEN);
    cache[project.id] = { readme: evidence.readme, claudeCommitEvidence: evidence.claudeCommitEvidence };

    // Two calls per repo; stay clear of the 5k/hr authenticated limit.
    const remaining = parseInt(evidence.rateLimit ?? "9999", 10);
    if (remaining < 60) {
      console.log(`  rate limit low (${remaining}), sleeping 15 min...`);
      writeFileSync(CACHE_PATH, JSON.stringify(cache));
      await new Promise((r) => setTimeout(r, 15 * 60 * 1000));
    }

    if (++done % 100 === 0) {
      writeFileSync(CACHE_PATH, JSON.stringify(cache));
      console.log(`  ${done}/${pending.length}`);
    }
  }
  writeFileSync(CACHE_PATH, JSON.stringify(cache));
  return cache;
}

function estimateCost(targets, cache) {
  const [inRate, outRate] = BATCH_PRICING[MODEL] ?? BATCH_PRICING[DEFAULT_MODEL];
  let inputChars = 0;
  for (const p of targets) {
    inputChars += 1200 + (cache[p.id]?.readme?.length ?? 0); // prompt + system overhead
  }
  const inputTokens = inputChars / 4;
  const outputTokens = targets.length * 250;
  return (inputTokens / 1e6) * inRate + (outputTokens / 1e6) * outRate;
}

async function phaseB(targets, cache) {
  // custom_id is capped at 64 chars; repo ids can exceed it, so key by index.
  const requests = targets.map((project, i) => ({
    custom_id: `r${i}`,
    params: buildMessageParams(
      { full_name: project.id, description: project.description, topics: [], language: project.language, stars: project.stars },
      cache[project.id] ?? { readme: null, claudeCommitEvidence: null },
      MODEL,
    ),
  }));

  const res = await fetch(BATCHES_API, {
    method: "POST",
    headers: anthropicHeaders,
    body: JSON.stringify({ requests }),
  });
  if (!res.ok) throw new Error(`batch create failed ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const batch = await res.json();
  // custom_ids are positional (r0, r1, ...), so persist the position → repo-id
  // mapping. A --batch-id resume must NOT recompute selection from the registry:
  // if the registry changed in between (a discovery run landed), positional
  // recomputation would silently apply verdicts to the wrong entries.
  writeFileSync(BATCH_MAP_PATH, JSON.stringify({ batchId: batch.id, ids: targets.map((p) => p.id) }));
  console.log(`Phase B — batch submitted: ${batch.id} (${requests.length} requests, id map saved to ${BATCH_MAP_PATH})`);
  return batch.id;
}

async function pollBatch(batchId) {
  while (true) {
    const res = await fetch(`${BATCHES_API}/${batchId}`, { headers: anthropicHeaders });
    if (!res.ok) throw new Error(`batch poll failed ${res.status}`);
    const batch = await res.json();
    const c = batch.request_counts;
    console.log(`  ${batch.processing_status} — ok:${c.succeeded} err:${c.errored} processing:${c.processing}`);
    if (batch.processing_status === "ended") return batch;
    await new Promise((r) => setTimeout(r, 60_000));
  }
}

async function phaseC(batch, ids, registry) {
  const res = await fetch(batch.results_url, { headers: anthropicHeaders });
  if (!res.ok) throw new Error(`results fetch failed ${res.status}`);
  const lines = (await res.text()).trim().split("\n");

  const byID = new Map(registry.map((p) => [p.id, p]));
  const cache = existsSync(CACHE_PATH) ? JSON.parse(readFileSync(CACHE_PATH, "utf-8")) : {};
  const flagged = [];
  let enriched = 0;
  let errored = 0;

  for (const line of lines) {
    const result = JSON.parse(line);
    const index = parseInt(result.custom_id.slice(1), 10);
    const project = byID.get(ids[index]);
    if (!project) continue;

    if (result.result.type !== "succeeded") {
      errored++;
      continue;
    }

    // Evidence-based builtWithClaude was baked into the prompt; re-derive
    // from the cache so hard evidence still outranks the model here.
    const evidence = { claudeCommitEvidence: cache[project.id]?.claudeCommitEvidence ?? null };
    let verdict;
    try {
      verdict = parseVerdict(result.result.message, evidence);
    } catch {
      errored++;
      continue;
    }

    if (!verdict.is_tracker) {
      // Already in the published registry — flag for human review, never auto-remove.
      flagged.push({ id: project.id, confidence: verdict.confidence, reason: verdict.reason });
    }

    project.category = verdict.category;
    project.platforms = verdict.platforms;
    project.authMethod = verdict.auth_methods;
    project.features = verdict.features;
    project.builtWithClaude = verdict.built_with_claude;
    enriched++;
  }

  writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2) + "\n");
  if (flagged.length > 0) writeFileSync(FLAGGED_PATH, JSON.stringify(flagged, null, 2) + "\n");

  console.log(`\nPhase C — applied: ${enriched} enriched, ${errored} errored`);
  console.log(`Flagged as possibly-not-trackers (review ${FLAGGED_PATH}, nothing was removed): ${flagged.length}`);
  console.log("Run `swift test` to validate the enriched registry before committing.");
}

async function main() {
  const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf-8"));
  let targets = selectTargets(registry);
  if (Number.isFinite(LIMIT)) targets = targets.slice(0, LIMIT);
  console.log(`Registry: ${registry.length} entries, ${targets.length} selected for enrichment (model: ${MODEL})`);

  if (RESUME_BATCH_ID) {
    if (!existsSync(BATCH_MAP_PATH)) {
      console.error(`--batch-id resume requires ${BATCH_MAP_PATH} (written at submit time); refusing to guess the result mapping.`);
      process.exit(1);
    }
    const map = JSON.parse(readFileSync(BATCH_MAP_PATH, "utf-8"));
    if (map.batchId !== RESUME_BATCH_ID) {
      console.error(`${BATCH_MAP_PATH} is for batch ${map.batchId}, not ${RESUME_BATCH_ID}.`);
      process.exit(1);
    }
    const batch = await pollBatch(RESUME_BATCH_ID);
    await phaseC(batch, map.ids, registry);
    return;
  }

  const cache = await phaseA(targets);
  const cost = estimateCost(targets, cache);
  console.log(`Estimated batch cost: ~$${cost.toFixed(2)} (${MODEL}, batch rates)`);

  if (!CONFIRMED) {
    console.log("Dry run complete. Re-run with --yes to submit the batch.");
    return;
  }

  const batchId = await phaseB(targets, cache);
  const batch = await pollBatch(batchId);
  await phaseC(batch, targets.map((p) => p.id), registry);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

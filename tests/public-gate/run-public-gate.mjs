import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "..", "..");

const REQUIRED_GATE_IDS = ["G-1", "G-2", "G-3", "G-4"];
const REQUIRED_PLACEHOLDER_IDS = ["T-1", "T-2", "T-3", "T-4", "T-5", "T-6"];
const REQUIRED_USER_KEYS = ["A", "B", "C", "D"];
const REQUIRED_APP_CONFIG_KEYS = [
  "rate_limits",
  "rate_limits_new_account",
  "auto_hide",
  "popular_feed",
];

function readJson(relativePath) {
  const fullPath = resolve(rootDir, relativePath);
  return JSON.parse(readFileSync(fullPath, "utf8"));
}

function toIdSet(entries) {
  return new Set((entries || []).map((entry) => entry.id));
}

function findMissingIds(entries, requiredIds) {
  const idSet = toIdSet(entries);
  return requiredIds.filter((id) => !idSet.has(id));
}

function runFixtureChecks(fixture, failures) {
  const users = fixture.users || {};
  for (const userKey of REQUIRED_USER_KEYS) {
    const user = users[userKey];
    if (!user || typeof user.user_id !== "string" || typeof user.nickname !== "string") {
      failures.push(`fixture.users.${userKey} is missing user_id/nickname`);
    }
  }

  const blocks = Array.isArray(fixture.blocks) ? fixture.blocks : [];
  const requiredPairs = [
    ["A", "B"],
    ["B", "A"],
  ];
  for (const [blocker, blocked] of requiredPairs) {
    const found = blocks.some((item) => item.blocker === blocker && item.blocked === blocked);
    if (!found) {
      failures.push(`fixture.blocks missing required relation ${blocker} -> ${blocked}`);
    }
  }

  const topics = Array.isArray(fixture.topics) ? fixture.topics : [];
  if (topics.length < 2) {
    failures.push("fixture.topics must include at least 2 topics");
  }

  const posts = Array.isArray(fixture.posts) ? fixture.posts : [];
  const hasPublicPost = posts.some(
    (post) => post.visibility === "public" && typeof post.published_at === "string" && post.published_at.length > 0,
  );
  if (!hasPublicPost) {
    failures.push("fixture.posts must include at least one public+published sample");
  }

  const threads = Array.isArray(fixture.threads) ? fixture.threads : [];
  if (threads.length === 0) {
    failures.push("fixture.threads must include at least one sample thread");
  }

  const appConfig = fixture.app_config || {};
  for (const key of REQUIRED_APP_CONFIG_KEYS) {
    if (!(key in appConfig)) {
      failures.push(`fixture.app_config missing key ${key}`);
    }
  }
}

export function runPublicGate({ requireExact = false } = {}) {
  console.log("\n-- Public Surface Gate (P0-04 skeleton) --");

  const failures = [];

  const manifest = readJson("tests/public-gate/manifest.json");
  const fixture = readJson("tests/fixtures/p0-04-public-surface.seed.json");

  const missingGates = findMissingIds(manifest.gates, REQUIRED_GATE_IDS);
  const missingPlaceholders = findMissingIds(manifest.phase1_placeholders, REQUIRED_PLACEHOLDER_IDS);

  for (const gateId of missingGates) {
    failures.push(`tests/public-gate/manifest.json missing gate ${gateId}`);
  }
  for (const placeholderId of missingPlaceholders) {
    failures.push(`tests/public-gate/manifest.json missing placeholder ${placeholderId}`);
  }

  runFixtureChecks(fixture, failures);

  const gates = [...(manifest.gates || [])].sort((a, b) => a.id.localeCompare(b.id));
  const skippedGateIds = [];
  for (const gate of gates) {
    if (gate.mode !== "skeleton") {
      failures.push(`gate ${gate.id} must keep mode=skeleton in P0-04`);
    }
    const status = (gate.status || "skip").toUpperCase();
    if (status === "SKIP") {
      skippedGateIds.push(gate.id);
    }
    const reason = gate.reason || "placeholder";
    console.log(`${status}: [${gate.id}] ${gate.title} (${reason})`);
  }

  const placeholders = [...(manifest.phase1_placeholders || [])].sort((a, b) => a.id.localeCompare(b.id));
  for (const item of placeholders) {
    if (item.mode !== "placeholder") {
      failures.push(`placeholder ${item.id} must keep mode=placeholder`);
    }
    console.log(`SKIP: [${item.id}] ${item.title} (Phase 1 placeholder)`);
  }

  if (requireExact && skippedGateIds.length > 0) {
    failures.push(`exact mode requested but skeleton gates remain: ${skippedGateIds.join(", ")}`);
  }

  if (failures.length > 0) {
    for (const failure of failures) {
      console.error(`FAIL: ${failure}`);
    }
    return { exitCode: 1 };
  }

  console.log("PASS: ci:public-gate skeleton + fixture baseline");
  return { exitCode: 0 };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const requireExact = process.argv.includes("--require-exact");
  const { exitCode } = runPublicGate({ requireExact });
  process.exit(exitCode);
}

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checkDci1ProfilesJoin } from "./check-dci-1-profiles-join.mjs";
import { checkDci2AppConfigWhitelist } from "./check-dci-2-app-config-whitelist.mjs";
import { checkDci5SchemaDrift } from "./check-dci-5-schema-drift.mjs";
import { checkDci6RpcGuardCompleteness } from "./check-dci-6-rpc-guard-completeness.mjs";
import { checkDci7RlsCoverage } from "./check-dci-7-rls-coverage.mjs";
import { checkDci8GrantRevoke } from "./check-dci-8-grant-revoke.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "..", "..");

const REQUIRED_DCI_PLACEHOLDER_IDS = ["DCI-3", "DCI-4"];

function checkErrorCodesDrift() {
  const apiSource = readFileSync(resolve(rootDir, "docs", "API.md"), "utf8");
  const sharedSource = readFileSync(resolve(rootDir, "packages", "shared", "src", "error-codes.ts"), "utf8");

  const docCodes = new Set();
  const tableRowRegex = /^\|\s*(\S+)\s*\|/gm;
  for (const match of apiSource.matchAll(tableRowRegex)) {
    const code = match[1];
    if (code === "error_code" || code.startsWith("-") || code.startsWith("(")) {
      continue;
    }
    docCodes.add(code);
  }

  const sharedCodes = new Set();
  const codeRegex = /"([^"]+)"/g;
  for (const match of sharedSource.matchAll(codeRegex)) {
    sharedCodes.add(match[1]);
  }

  const inDocOnly = [...docCodes].filter((code) => !sharedCodes.has(code));
  const inSharedOnly = [...sharedCodes].filter((code) => !docCodes.has(code));

  return {
    id: "DCI-ERR",
    title: "error_code drift (API.md vs error-codes.ts)",
    pass: inDocOnly.length === 0 && inSharedOnly.length === 0,
    details: [
      `doc codes (${docCodes.size}): ${[...docCodes].sort().join(", ")}`,
      `shared codes (${sharedCodes.size}): ${[...sharedCodes].sort().join(", ")}`,
      ...(inDocOnly.length > 0 ? [`API.md only: ${inDocOnly.join(", ")}`] : []),
      ...(inSharedOnly.length > 0 ? [`error-codes.ts only: ${inSharedOnly.join(", ")}`] : []),
    ],
  };
}

function loadDciPlaceholders() {
  const manifestPath = resolve(rootDir, "tests", "drift", "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const entries = Array.isArray(manifest.placeholders) ? manifest.placeholders : [];

  const entryIds = new Set(entries.map((entry) => entry.id));
  const missingIds = REQUIRED_DCI_PLACEHOLDER_IDS.filter((id) => !entryIds.has(id));

  return {
    entries,
    missingIds,
  };
}

function printResult(result) {
  if (result.pass) {
    console.log(`PASS: [${result.id}] ${result.title}`);
    return;
  }

  console.error(`FAIL: [${result.id}] ${result.title}`);
  for (const detail of result.details) {
    console.error(` - ${detail}`);
  }
}

export function runDriftChecks() {
  console.log("\n-- Drift checks (P0-04) --");

  let exitCode = 0;

  const checks = [
    checkErrorCodesDrift(),
    checkDci1ProfilesJoin({ rootDir }),
    checkDci2AppConfigWhitelist({ rootDir }),
    checkDci5SchemaDrift({ rootDir }),
    checkDci6RpcGuardCompleteness({ rootDir }),
    checkDci7RlsCoverage({ rootDir }),
    checkDci8GrantRevoke({ rootDir }),
  ];

  for (const check of checks) {
    printResult(check);
    if (!check.pass) {
      exitCode = 1;
    }
  }

  const placeholders = loadDciPlaceholders();
  for (const missingId of placeholders.missingIds) {
    console.error(`FAIL: tests/drift/manifest.json missing ${missingId}`);
    exitCode = 1;
  }

  for (const placeholder of placeholders.entries.sort((a, b) => a.id.localeCompare(b.id))) {
    if (placeholder.mode !== "placeholder") {
      console.error(`FAIL: ${placeholder.id} must keep mode=placeholder`);
      exitCode = 1;
    }
    const reason = placeholder.reason || "Phase 1 placeholder";
    console.log(`SKIP: [${placeholder.id}] ${placeholder.title} (${reason})`);
  }

  if (exitCode === 0) {
    console.log("PASS: ci:drift");
  }

  return { exitCode };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { exitCode } = runDriftChecks();
  process.exit(exitCode);
}

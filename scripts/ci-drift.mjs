import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

let exitCode = 0;

function fail(msg) {
  console.error(`FAIL: ${msg}`);
  exitCode = 1;
}

// ──────────────────────────────────────────────
// DCI-ERR: error-codes drift (API.md §1 vs error-codes.ts)
// ──────────────────────────────────────────────

function checkErrorCodesDrift() {
  console.log("\n── DCI-ERR: error-codes drift ──");

  // 1. Parse error_code column from API.md transport adapter table
  const apiMd = readFileSync(resolve(root, "docs/API.md"), "utf-8");

  // Match rows like: | not_found | 404 | ... |
  // Skip header/separator rows and the "(정상)" row
  const tableRowRe = /^\|\s*(\S+)\s*\|/gm;
  const docCodes = new Set();
  for (const m of apiMd.matchAll(tableRowRe)) {
    const code = m[1];
    if (
      code === "error_code" ||
      code.startsWith("-") ||
      code.startsWith("(")
    ) {
      continue;
    }
    docCodes.add(code);
  }

  // 2. Parse ERROR_CODES array from error-codes.ts
  const ecTs = readFileSync(
    resolve(root, "packages/shared/src/error-codes.ts"),
    "utf-8",
  );
  const strRe = /"([^"]+)"/g;
  const tsCodes = new Set();
  for (const m of ecTs.matchAll(strRe)) {
    tsCodes.add(m[1]);
  }

  // 3. Compare
  const inDocOnly = [...docCodes].filter((c) => !tsCodes.has(c));
  const inTsOnly = [...tsCodes].filter((c) => !docCodes.has(c));

  if (inDocOnly.length > 0) {
    fail(`API.md에 있지만 error-codes.ts에 없음: ${inDocOnly.join(", ")}`);
  }
  if (inTsOnly.length > 0) {
    fail(`error-codes.ts에 있지만 API.md에 없음: ${inTsOnly.join(", ")}`);
  }

  if (inDocOnly.length === 0 && inTsOnly.length === 0) {
    console.log(`PASS: ${docCodes.size} codes, doc ↔ ts 1:1 match`);
  }
}

// ──────────────────────────────────────────────
// Run all drift checks
// ──────────────────────────────────────────────

checkErrorCodesDrift();

console.log("\nINFO: DCI-1~DCI-4 checks will be added in P0-04.");

process.exit(exitCode);
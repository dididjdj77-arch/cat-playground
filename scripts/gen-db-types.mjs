import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const GENERATED_TYPES_PATH = "packages/shared/src/database.types.ts";
const args = ["gen", "types", "typescript", "--local"];
const checkMode = process.argv.includes("--check");

console.log(`[db:types] supabase ${args.join(" ")}`);

const result = spawnSync("supabase", args, {
  encoding: "utf8",
  shell: process.platform === "win32"
});

if (result.status !== 0) {
  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }
  process.exit(result.status ?? 1);
}

const generatedSource = result.stdout ?? "";

if (generatedSource.trim().length === 0) {
  console.error("FAIL: supabase type generation returned empty output");
  process.exit(1);
}

const normalizedSource = generatedSource.endsWith("\n")
  ? generatedSource
  : `${generatedSource}\n`;

const outputDir = path.dirname(GENERATED_TYPES_PATH);
fs.mkdirSync(outputDir, { recursive: true });

const previousSource = fs.existsSync(GENERATED_TYPES_PATH)
  ? fs.readFileSync(GENERATED_TYPES_PATH, "utf8")
  : null;

if (checkMode) {
  if (previousSource !== normalizedSource) {
    console.error("FAIL: generated DB types are out of sync");
    console.error(` - run \`npm run db:types\` and commit ${GENERATED_TYPES_PATH}`);
    process.exit(1);
  }

  console.log(`PASS: db:types:check (${GENERATED_TYPES_PATH})`);
  process.exit(0);
}

if (previousSource === normalizedSource) {
  console.log(`PASS: db:types already up to date (${GENERATED_TYPES_PATH})`);
  process.exit(0);
}

fs.writeFileSync(GENERATED_TYPES_PATH, normalizedSource, "utf8");
console.log(`PASS: db:types wrote ${GENERATED_TYPES_PATH}`);

import fs from "node:fs";
import { spawnSync } from "node:child_process";

const baselineMigration = "supabase/migrations/20260211143853_init.sql";

if (!fs.existsSync(baselineMigration)) {
  console.error(`FAIL: missing baseline migration ${baselineMigration}`);
  process.exit(1);
}

const args = [
  "db",
  "lint",
  "--local",
  "--schema",
  "public",
  "--level",
  "warning",
  "--fail-on",
  "warning"
];

console.log(`[db:smoke] supabase ${args.join(" ")}`);

const result = spawnSync("supabase", args, {
  stdio: "inherit",
  shell: process.platform === "win32"
});

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

console.log("PASS: db:smoke");

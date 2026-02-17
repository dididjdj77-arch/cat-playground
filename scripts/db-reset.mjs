import fs from "node:fs";
import { spawnSync } from "node:child_process";

const REQUIRED_PATHS = [
  "supabase/config.toml",
  "supabase/seed.sql",
  "supabase/migrations/20260211143853_init.sql"
];

const missingPaths = REQUIRED_PATHS.filter((p) => !fs.existsSync(p));
if (missingPaths.length > 0) {
  console.error("FAIL: db:reset preflight missing required files");
  for (const missingPath of missingPaths) {
    console.error(` - ${missingPath}`);
  }
  process.exit(1);
}

const args = ["db", "reset", "--local", "--yes"];

const dockerProbe = spawnSync("docker", ["info"], {
  stdio: "ignore",
  shell: process.platform === "win32"
});

if (dockerProbe.status !== 0) {
  console.error("FAIL: Docker daemon is not reachable.");
  console.error(" - Start Docker Desktop (or the Docker service) and retry `npm run db:reset`.");
  process.exit(1);
}

const startArgs = ["start"];

console.log(`[db:reset] supabase ${startArgs.join(" ")}`);

const startResult = spawnSync("supabase", startArgs, {
  stdio: "inherit",
  shell: process.platform === "win32"
});

if (startResult.status !== 0) {
  process.exit(startResult.status ?? 1);
}

console.log(`[db:reset] supabase ${args.join(" ")}`);

const result = spawnSync("supabase", args, {
  stdio: "inherit",
  shell: process.platform === "win32"
});

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

console.log("PASS: db:reset");

import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const ROOT = process.cwd();

const SQL_TEST_FILES = [
  "tests/p1-01-inventory-rpc.sql",
  "tests/p1-02-observation-rpc.sql",
  "tests/p1-03-house-rpc.sql",
  "tests/p1-07-profile-notif-rpc.sql",
];

const CONTAINER_NAME = "supabase_db_cat-playground";

let exitCode = 0;

for (const relativePath of SQL_TEST_FILES) {
  const fullPath = resolve(ROOT, relativePath);

  if (!existsSync(fullPath)) {
    console.error(`FAIL: missing test file ${relativePath}`);
    exitCode = 1;
    continue;
  }

  console.log(`[db:sql-tests] running ${relativePath} ...`);

  // docker exec reads from stdin, so we pipe the SQL file
  const result = spawnSync(
    "docker",
    [
      "exec",
      "-i",
      CONTAINER_NAME,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
    ],
    {
      input: readFileSync(fullPath, "utf8"),
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 30000,
    },
  );

  const stdout = result.stdout?.toString() || "";
  const stderr = result.stderr?.toString() || "";

  if (result.status !== 0) {
    console.error(`FAIL: ${relativePath}`);
    if (stderr) {
      console.error(stderr.trim());
    }
    if (stdout) {
      console.error(stdout.trim());
    }
    exitCode = 1;
  } else {
    console.log(`PASS: ${relativePath}`);
  }
}

if (exitCode === 0) {
  console.log(`\nPASS: db:sql-tests (${SQL_TEST_FILES.length} files)`);
} else {
  console.error(`\nFAIL: db:sql-tests`);
}

process.exit(exitCode);

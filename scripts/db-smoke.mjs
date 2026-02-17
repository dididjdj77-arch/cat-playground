import fs from "node:fs";

const baselineMigration = "supabase/migrations/20260211143853_init.sql";

if (!fs.existsSync(baselineMigration)) {
  console.error(`FAIL: missing baseline migration ${baselineMigration}`);
  process.exit(1);
}

console.log("PASS: db:smoke (baseline migration present)");

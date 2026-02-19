import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

function loadAllMigrationSql(rootDir) {
  const migrationDir = resolve(rootDir, "supabase", "migrations");
  const files = readdirSync(migrationDir)
    .filter((name) => name.endsWith(".sql"))
    .sort();

  let combined = "";
  for (const fileName of files) {
    combined += readFileSync(resolve(migrationDir, fileName), "utf8") + "\n";
  }
  return combined;
}

function loadManifest(rootDir) {
  const manifestPath = resolve(rootDir, "tests", "drift", "schema-manifest.json");
  return JSON.parse(readFileSync(manifestPath, "utf8"));
}

export function checkDci5SchemaDrift({ rootDir }) {
  const sql = loadAllMigrationSql(rootDir);
  const sqlLower = sql.toLowerCase();
  const manifest = loadManifest(rootDir);
  const violations = [];

  // 1) Table existence (matches both "create table" and "create table if not exists")
  for (const table of manifest.tables) {
    const regex = new RegExp(`create\\s+table\\s+(if\\s+not\\s+exists\\s+)?public\\.${table}\\b`, "i");
    if (!regex.test(sql)) {
      violations.push(`TABLE missing: ${table}`);
    }
  }

  // 2) CHECK constraints
  for (const check of manifest.check_constraints) {
    const regex = new RegExp(check.pattern, "i");
    if (!regex.test(sql)) {
      violations.push(`CHECK missing [${check.id}]: ${check.description} on ${check.table}`);
    }
  }

  // 3) UNIQUE constraints (inline or index-based)
  for (const uq of manifest.unique_constraints) {
    const regex = new RegExp(uq.pattern, "is");
    if (!regex.test(sql)) {
      violations.push(`UNIQUE missing [${uq.id}]: ${uq.description} on ${uq.table}`);
    }
  }

  // 4) Indexes
  for (const idx of manifest.indexes) {
    if (!sqlLower.includes(idx.pattern.toLowerCase())) {
      violations.push(`INDEX missing [${idx.id}]: ${idx.pattern}`);
    }
  }

  return {
    id: "DCI-5",
    title: "schema drift (DATA-MODEL vs migrations)",
    pass: violations.length === 0,
    details:
      violations.length === 0
        ? [
            `tables: ${manifest.tables.length} checked`,
            `checks: ${manifest.check_constraints.length} checked`,
            `uniques: ${manifest.unique_constraints.length} checked`,
            `indexes: ${manifest.indexes.length} checked`,
          ]
        : violations,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === import.meta.url.replace("file:///", "")) {
  const rootDir = resolve(import.meta.dirname, "..", "..");
  const result = checkDci5SchemaDrift({ rootDir });
  if (!result.pass) {
    for (const detail of result.details) {
      console.error(`FAIL: ${detail}`);
    }
    process.exit(1);
  }
  console.log(`PASS: [${result.id}] ${result.title}`);
  for (const detail of result.details) {
    console.log(`  ${detail}`);
  }
}

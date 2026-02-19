import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

// Tables with user-owned data — require RLS enabled + policy
const RLS_REQUIRED_TABLES = [
  "profiles",
  "profile_settings",
  "cats",
  "catalog_suggestions",
  "house_profiles",
  "house_slots",
  "inventory_items",
  "observation_groups",
  "observations",
  "observation_patch_dedup",
  "observation_inventory_refs",
  "topic_follows",
  "threads",
  "replies",
  "posts",
  "comments",
  "likes",
  "blocks",
  "reports",
  "notifications",
];

// System/reference/ops tables — no user-owned rows, accessed only via SECURITY DEFINER RPCs
// These need revoke select but not RLS (no owner-based row filtering needed)
const SYSTEM_TABLES = [
  "catalog_items",
  "catalog_aliases",
  "topics",
  "comment_revisions",
  "reply_revisions",
  "moderation_actions",
  "ops_metrics",
  "payload_versions",
  "payload_version_events",
  "payload_version_rollups",
  "app_config",
];

// All tables that need revoke select from anon/authenticated
const ALL_DOMAIN_TABLES = [...RLS_REQUIRED_TABLES, ...SYSTEM_TABLES];

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

export function checkDci7RlsCoverage({ rootDir }) {
  const sql = loadAllMigrationSql(rootDir);
  const sqlLower = sql.toLowerCase();
  const violations = [];

  let rlsEnabledCount = 0;
  let revokeCount = 0;

  // 1) Check RLS on user-owned tables only
  for (const table of RLS_REQUIRED_TABLES) {
    const rlsPattern = `alter table public.${table} enable row level security`;
    if (!sqlLower.includes(rlsPattern)) {
      violations.push(`RLS not enabled: ${table} (user-owned table)`);
    } else {
      rlsEnabledCount++;
    }
  }

  // 2) Check revoke select for ALL domain tables
  for (const table of ALL_DOMAIN_TABLES) {
    const revokePattern = `revoke select on table public.${table} from anon`;
    if (!sqlLower.includes(revokePattern)) {
      violations.push(`REVOKE SELECT missing for anon: ${table}`);
    } else {
      revokeCount++;
    }
  }

  return {
    id: "DCI-7",
    title: "RLS coverage + revoke select",
    pass: violations.length === 0,
    details:
      violations.length === 0
        ? [
            `RLS enabled: ${rlsEnabledCount}/${RLS_REQUIRED_TABLES.length} (user-owned)`,
            `revoke select: ${revokeCount}/${ALL_DOMAIN_TABLES.length} (all domain)`,
          ]
        : violations,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === import.meta.url.replace("file:///", "")) {
  const rootDir = resolve(import.meta.dirname, "..", "..");
  const result = checkDci7RlsCoverage({ rootDir });
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

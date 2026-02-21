import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const WRITE_RPCS_REQUIRING_GUARD = [
  "rpc_inventory_switch",
  "rpc_inventory_discontinue",
  "rpc_inventory_correction",
  "rpc_upsert_observation_group_with_items",
  "rpc_patch_observation_items",
  "rpc_set_house_slot",
  "rpc_clear_house_slot",
  "rpc_publish_house",
  "rpc_unpublish_house",
  "rpc_create_post",
  "rpc_update_post",
  "rpc_delete_post",
  "rpc_publish_post",
  "rpc_unpublish_post",
  "rpc_create_comment",
  "rpc_update_comment",
  "rpc_delete_comment",
  "rpc_toggle_like",
  "rpc_create_thread",
  "rpc_update_thread",
  "rpc_delete_thread",
  "rpc_create_reply",
  "rpc_update_reply",
  "rpc_delete_reply",
  "rpc_follow_topic",
  "rpc_unfollow_topic",
  "rpc_report_content",
  "rpc_block_user",
  "rpc_unblock_user",
  "rpc_update_profile",
  "rpc_mark_notification_read",
  "rpc_mark_all_notifications_read",
  "rpc_hide_content",
  "rpc_unhide_content",
];

const PRE_TERMS_EXCEPTIONS = [
  "rpc_agree_terms",
  "rpc_set_initial_nickname",
];

// Stubs that return error immediately without business logic (D-095: 예비 등록)
const STUB_EXCEPTIONS = [
  "rpc_inventory_correction",
];

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

function extractFunctionBody(sqlSource, functionName) {
  const sourceLower = sqlSource.toLowerCase();
  const anchor = `create or replace function public.${functionName.toLowerCase()}`;
  const start = sourceLower.indexOf(anchor);
  if (start < 0) {
    return null;
  }

  const asIdx = sourceLower.indexOf("as $$", start);
  if (asIdx < 0) {
    return null;
  }

  const bodyStart = asIdx + "as $$".length;
  const bodyEnd = sqlSource.indexOf("$$;", bodyStart);
  if (bodyEnd < 0) {
    return null;
  }

  return sqlSource.slice(bodyStart, bodyEnd);
}

export function checkDci6RpcGuardCompleteness({ rootDir }) {
  const sql = loadAllMigrationSql(rootDir);
  const violations = [];
  let checkedCount = 0;

  const skippedStubs = [];
  for (const rpcName of WRITE_RPCS_REQUIRING_GUARD) {
    if (STUB_EXCEPTIONS.includes(rpcName)) {
      skippedStubs.push(rpcName);
      continue;
    }

    const body = extractFunctionBody(sql, rpcName);
    if (!body) {
      violations.push(`${rpcName}: function body not found in migrations`);
      continue;
    }

    checkedCount++;

    // Check for actual function call (not just comment mention)
    // Real call patterns: ":= public.guard_terms_agreed()" or ":= guard_terms_agreed()"
    const hasCall = /guard_terms_agreed\s*\(\s*\)/i.test(
      body.split("\n").filter((line) => !line.trim().startsWith("--")).join("\n")
    );
    if (!hasCall) {
      violations.push(`${rpcName}: missing guard_terms_agreed() call (D-096)`);
    }
  }

  // Verify pre-terms exceptions do NOT have guard_terms_agreed call
  for (const rpcName of PRE_TERMS_EXCEPTIONS) {
    const body = extractFunctionBody(sql, rpcName);
    if (!body) {
      continue;
    }

    // Check for actual function call (excluding comments)
    const hasCall = /guard_terms_agreed\s*\(\s*\)/i.test(
      body.split("\n").filter((line) => !line.trim().startsWith("--")).join("\n")
    );
    if (hasCall) {
      violations.push(`${rpcName}: pre-terms exception should NOT call guard_terms_agreed (D-097)`);
    }
  }

  return {
    id: "DCI-6",
    title: "write RPC guard completeness (D-096)",
    pass: violations.length === 0,
    details:
      violations.length === 0
        ? [
            `write RPCs checked: ${checkedCount}/${WRITE_RPCS_REQUIRING_GUARD.length - STUB_EXCEPTIONS.length}`,
            `pre-terms exceptions verified: ${PRE_TERMS_EXCEPTIONS.length}`,
            `stubs skipped: ${skippedStubs.join(", ") || "none"}`,
          ]
        : violations,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === import.meta.url.replace("file:///", "")) {
  const rootDir = resolve(import.meta.dirname, "..", "..");
  const result = checkDci6RpcGuardCompleteness({ rootDir });
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

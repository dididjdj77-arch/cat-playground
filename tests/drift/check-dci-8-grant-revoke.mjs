import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

// RPCs that should be executable by both anon and authenticated (public read)
const ANON_AND_AUTH_RPCS = [
  { name: "rpc_get_public_posts_feed", sig: "text, int" },
  { name: "rpc_get_public_post_detail", sig: "uuid" },
  { name: "rpc_get_public_post_comments", sig: "uuid, text, int" },
  { name: "rpc_get_public_threads_feed", sig: "text, text, int" },
  { name: "rpc_get_public_thread_detail", sig: "uuid" },
  { name: "rpc_list_topics", sig: null },
  { name: "rpc_search_threads", sig: "text, text, int" },
];

// RPCs that should be authenticated-only (anon must NOT have execute)
const AUTH_ONLY_RPCS = [
  { name: "rpc_get_public_house_slots_summary", sig: "uuid" },
  { name: "rpc_inventory_switch", sig: null },
  { name: "rpc_inventory_discontinue", sig: null },
  { name: "rpc_create_post", sig: null },
  { name: "rpc_update_post", sig: null },
  { name: "rpc_delete_post", sig: null },
  { name: "rpc_publish_post", sig: null },
  { name: "rpc_unpublish_post", sig: null },
  { name: "rpc_create_comment", sig: null },
  { name: "rpc_update_comment", sig: null },
  { name: "rpc_delete_comment", sig: null },
  { name: "rpc_toggle_like", sig: "text, uuid" },
  { name: "rpc_create_thread", sig: null },
  { name: "rpc_update_thread", sig: null },
  { name: "rpc_delete_thread", sig: null },
  { name: "rpc_create_reply", sig: null },
  { name: "rpc_update_reply", sig: null },
  { name: "rpc_delete_reply", sig: null },
  { name: "rpc_follow_topic", sig: null },
  { name: "rpc_unfollow_topic", sig: null },
  { name: "rpc_report_content", sig: null },
  { name: "rpc_block_user", sig: null },
  { name: "rpc_unblock_user", sig: null },
  { name: "rpc_agree_terms", sig: null },
  { name: "rpc_set_initial_nickname", sig: null },
  { name: "rpc_update_profile", sig: null },
  { name: "rpc_get_my_profile", sig: null },
  { name: "rpc_get_my_house", sig: null },
  { name: "rpc_get_my_observation_group", sig: null },
  { name: "rpc_get_notifications", sig: null },
  { name: "rpc_mark_notification_read", sig: null },
  { name: "rpc_mark_all_notifications_read", sig: null },
  { name: "rpc_upsert_observation_group_with_items", sig: null },
  { name: "rpc_patch_observation_items", sig: null },
  { name: "rpc_set_house_slot", sig: null },
  { name: "rpc_clear_house_slot", sig: null },
  { name: "rpc_publish_house", sig: null },
  { name: "rpc_unpublish_house", sig: null },
  { name: "rpc_get_app_config", sig: null },
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

function hasGrant(sqlLower, rpcName, role) {
  // Match grant with or without specific signature
  const pattern = `grant execute on function public.${rpcName}`;
  const lines = sqlLower.split("\n");
  return lines.some(
    (line) => line.includes(pattern) && line.includes(`to ${role}`)
  );
}

export function checkDci8GrantRevoke({ rootDir }) {
  const sql = loadAllMigrationSql(rootDir);
  const sqlLower = sql.toLowerCase();
  const violations = [];

  // 1) Public RPCs: must have grant for both anon and authenticated
  for (const rpc of ANON_AND_AUTH_RPCS) {
    if (!hasGrant(sqlLower, rpc.name, "anon")) {
      violations.push(`${rpc.name}: missing GRANT EXECUTE to anon`);
    }
    if (!hasGrant(sqlLower, rpc.name, "authenticated")) {
      violations.push(`${rpc.name}: missing GRANT EXECUTE to authenticated`);
    }
  }

  // 2) Auth-only RPCs: must have grant for authenticated
  for (const rpc of AUTH_ONLY_RPCS) {
    if (!hasGrant(sqlLower, rpc.name, "authenticated")) {
      violations.push(`${rpc.name}: missing GRANT EXECUTE to authenticated`);
    }
  }

  // 3) Auth-only RPCs that must explicitly forbid anon (D-035 house existence hiding)
  const MUST_FORBID_ANON = ["rpc_get_public_house_slots_summary"];
  for (const name of MUST_FORBID_ANON) {
    if (hasGrant(sqlLower, name, "anon")) {
      violations.push(`${name}: must NOT grant execute to anon (D-035 existence hiding)`);
    }
  }

  return {
    id: "DCI-8",
    title: "GRANT/REVOKE completeness",
    pass: violations.length === 0,
    details:
      violations.length === 0
        ? [
            `public RPCs (anon+auth): ${ANON_AND_AUTH_RPCS.length} checked`,
            `auth-only RPCs: ${AUTH_ONLY_RPCS.length} checked`,
            `anon-forbidden RPCs: ${MUST_FORBID_ANON.length} checked`,
          ]
        : violations,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === import.meta.url.replace("file:///", "")) {
  const rootDir = resolve(import.meta.dirname, "..", "..");
  const result = checkDci8GrantRevoke({ rootDir });
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

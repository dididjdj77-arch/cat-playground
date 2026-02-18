import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "..", "..");

const REQUIRED_GATE_IDS = ["G-1", "G-2", "G-3", "G-4"];
const REQUIRED_CASE_IDS = ["T-1", "T-2", "T-3", "T-4", "T-5", "T-6", "DCI-4"];
const REQUIRED_USER_KEYS = ["A", "B", "C", "D"];
const REQUIRED_APP_CONFIG_KEYS = [
  "rate_limits",
  "rate_limits_new_account",
  "auto_hide",
  "popular_feed",
];

const REQUIRED_EXACT_CASE_IDS = ["T-1", "T-5", "DCI-4"];
const FORBIDDEN_DTO_KEYS = new Set([
  "avatar_key",
  "avatar_url",
  "inventory_item_id",
  "inventory_id",
  "raw_text",
  "note",
  "meta",
  "ended_at",
  "catalog_item_id",
]);

function readJson(relativePath) {
  return JSON.parse(readText(relativePath));
}

function readText(relativePath) {
  const fullPath = resolve(rootDir, relativePath);
  return readFileSync(fullPath, "utf8");
}

function toIdSet(entries) {
  return new Set((entries || []).map((entry) => entry.id));
}

function findMissingIds(entries, requiredIds) {
  const idSet = toIdSet(entries);
  return requiredIds.filter((id) => !idSet.has(id));
}

function findEntry(entries, id) {
  return (entries || []).find((entry) => entry.id === id) || null;
}

function pushIf(condition, message, failures) {
  if (condition) {
    failures.push(message);
  }
}

function isBlocked(viewerKey, targetKey, blocks) {
  if (!viewerKey) {
    return false;
  }

  return blocks.some(
    (item) =>
      (item.blocker === viewerKey && item.blocked === targetKey) ||
      (item.blocker === targetKey && item.blocked === viewerKey),
  );
}

function isSoftAlive(entity) {
  return !entity.deleted_at && !entity.hidden_at;
}

function isPublicPublished(post) {
  return post.visibility === "public" && typeof post.published_at === "string" && post.published_at.length > 0;
}

function canViewPublicPost(post, viewerKey, blocks) {
  return isSoftAlive(post) && isPublicPublished(post) && !isBlocked(viewerKey, post.author, blocks);
}

function toPublicFeedDto(post, fixture) {
  const user = fixture.users[post.author];
  return {
    id: post.id,
    body: post.body,
    log_date: post.log_date,
    like_count: post.like_count ?? 0,
    comment_count: post.comment_count ?? 0,
    published_at: post.published_at,
    created_at: post.created_at,
    author_nickname: user?.nickname ?? null,
  };
}

function simulatePublicFeed(viewerKey, fixture) {
  const blocks = Array.isArray(fixture.blocks) ? fixture.blocks : [];
  const posts = Array.isArray(fixture.posts) ? fixture.posts : [];

  return posts
    .filter((post) => canViewPublicPost(post, viewerKey, blocks))
    .sort((a, b) => {
      const aTs = new Date(a.published_at || 0).getTime();
      const bTs = new Date(b.published_at || 0).getTime();
      if (aTs !== bTs) {
        return bTs - aTs;
      }
      return String(a.id).localeCompare(String(b.id));
    })
    .map((post) => toPublicFeedDto(post, fixture));
}

function simulatePublicPostDetail(post, viewerKey, fixture) {
  const blocks = Array.isArray(fixture.blocks) ? fixture.blocks : [];
  if (!post || !canViewPublicPost(post, viewerKey, blocks)) {
    return { error_code: "not_found" };
  }

  const user = fixture.users[post.author];
  return {
    id: post.id,
    body: post.body,
    log_date: post.log_date,
    like_count: post.like_count ?? 0,
    comment_count: post.comment_count ?? 0,
    published_at: post.published_at,
    created_at: post.created_at,
    author_nickname: user?.nickname ?? null,
  };
}

function simulatePublicPostComments(post, viewerKey, fixture) {
  const blocks = Array.isArray(fixture.blocks) ? fixture.blocks : [];
  if (!post || !canViewPublicPost(post, viewerKey, blocks)) {
    return { error_code: "not_found" };
  }

  const comments = Array.isArray(fixture.comments) ? fixture.comments : [];
  return comments
    .filter((comment) => comment.post_id === post.id)
    .filter((comment) => isSoftAlive(comment))
    .filter((comment) => !isBlocked(viewerKey, comment.author, blocks))
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .map((comment) => ({
      id: comment.id,
      body: comment.body,
      like_count: comment.like_count ?? 0,
      edited_at: comment.edited_at ?? null,
      created_at: comment.created_at,
      author_nickname: fixture.users[comment.author]?.nickname ?? null,
    }));
}

function findForbiddenPaths(value, path = "$", output = []) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      findForbiddenPaths(item, `${path}[${index}]`, output);
    });
    return output;
  }

  if (!value || typeof value !== "object") {
    return output;
  }

  for (const [key, nested] of Object.entries(value)) {
    const keyLower = key.toLowerCase();
    const nextPath = `${path}.${key}`;
    const isForbidden =
      FORBIDDEN_DTO_KEYS.has(keyLower) ||
      keyLower.startsWith("reason_") ||
      keyLower === "inventory_items.id";

    if (isForbidden) {
      output.push(nextPath);
    }

    findForbiddenPaths(nested, nextPath, output);
  }

  return output;
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

function assertContains(body, token, label, failures) {
  if (!body.includes(token)) {
    failures.push(`${label} missing token: ${token}`);
  }
}

function assertOrder(body, tokens, label, failures) {
  let prevIndex = -1;
  for (const token of tokens) {
    const idx = body.indexOf(token);
    if (idx < 0) {
      failures.push(`${label} missing token in guard order: ${token}`);
      return;
    }

    if (idx < prevIndex) {
      failures.push(`${label} guard order violation around token: ${token}`);
      return;
    }

    prevIndex = idx;
  }
}

function extractJsonBuildKeys(functionBody) {
  const keys = new Set();
  const regex = /'([a-zA-Z0-9_]+)'\s*,/g;
  for (const match of functionBody.matchAll(regex)) {
    keys.add(match[1].toLowerCase());
  }
  return [...keys];
}

function runManifestChecks(manifest, failures, { requireExact }) {
  const missingGates = findMissingIds(manifest.gates, REQUIRED_GATE_IDS);
  for (const gateId of missingGates) {
    failures.push(`tests/public-gate/manifest.json missing gate ${gateId}`);
  }

  const missingCases = findMissingIds(manifest.phase1_placeholders, REQUIRED_CASE_IDS);
  for (const caseId of missingCases) {
    failures.push(`tests/public-gate/manifest.json missing phase1 case ${caseId}`);
  }

  const gates = [...(manifest.gates || [])].sort((a, b) => a.id.localeCompare(b.id));
  for (const gate of gates) {
    const status = (gate.status || "skip").toUpperCase();
    const mode = gate.mode || "unknown";
    const reason = gate.reason || "n/a";
    console.log(`${status}: [${gate.id}] ${gate.title} (${mode}; ${reason})`);

    if (requireExact) {
      pushIf(mode !== "exact", `gate ${gate.id} must be mode=exact`, failures);
      pushIf((gate.status || "").toLowerCase() !== "pass", `gate ${gate.id} must be status=pass`, failures);
    }
  }

  const cases = [...(manifest.phase1_placeholders || [])].sort((a, b) => a.id.localeCompare(b.id));
  for (const item of cases) {
    const status = (item.status || "skip").toUpperCase();
    const mode = item.mode || "unknown";
    const reason = item.reason || "n/a";
    console.log(`${status}: [${item.id}] ${item.title} (${mode}; ${reason})`);

    if (REQUIRED_EXACT_CASE_IDS.includes(item.id)) {
      if (requireExact) {
        pushIf(mode !== "exact", `case ${item.id} must be mode=exact`, failures);
        pushIf((item.status || "").toLowerCase() !== "pass", `case ${item.id} must be status=pass`, failures);
      }
      continue;
    }

    pushIf(mode !== "placeholder", `non-target case ${item.id} must keep mode=placeholder`, failures);
  }
}

function runFixtureChecks(fixture, failures) {
  const users = fixture.users || {};
  for (const userKey of REQUIRED_USER_KEYS) {
    const user = users[userKey];
    if (!user || typeof user.user_id !== "string" || typeof user.nickname !== "string") {
      failures.push(`fixture.users.${userKey} is missing user_id/nickname`);
    }
  }

  const appConfig = fixture.app_config || {};
  for (const key of REQUIRED_APP_CONFIG_KEYS) {
    if (!(key in appConfig)) {
      failures.push(`fixture.app_config missing key ${key}`);
    }
  }

  const posts = Array.isArray(fixture.posts) ? fixture.posts : [];
  if (posts.length < 2) {
    failures.push("fixture.posts must include at least 2 samples for block tests");
  }

  const comments = Array.isArray(fixture.comments) ? fixture.comments : [];
  if (comments.length < 1) {
    failures.push("fixture.comments must include at least one sample");
  }

  const blocks = Array.isArray(fixture.blocks) ? fixture.blocks : [];
  for (const [blocker, blocked] of [
    ["A", "B"],
    ["B", "A"],
  ]) {
    const found = blocks.some((item) => item.blocker === blocker && item.blocked === blocked);
    if (!found) {
      failures.push(`fixture.blocks missing required relation ${blocker} -> ${blocked}`);
    }
  }
}

function runGateChecks({ fixture, migrationSql, failures }) {
  const feedBody = extractFunctionBody(migrationSql, "rpc_get_public_posts_feed");
  const detailBody = extractFunctionBody(migrationSql, "rpc_get_public_post_detail");
  const commentsBody = extractFunctionBody(migrationSql, "rpc_get_public_post_comments");
  const toggleLikeBody = extractFunctionBody(migrationSql, "rpc_toggle_like");
  const createCommentBody = extractFunctionBody(migrationSql, "rpc_create_comment");

  if (!feedBody || !detailBody || !commentsBody || !toggleLikeBody || !createCommentBody) {
    failures.push("required RPC function body extraction failed from migration SQL");
    return;
  }

  assertContains(feedBody, "public.guard_block(v_viewer_id, p.author_id)", "rpc_get_public_posts_feed", failures);
  assertContains(feedBody, "public.guard_soft_state(p.deleted_at, p.hidden_at)", "rpc_get_public_posts_feed", failures);
  assertContains(feedBody, "public.guard_visibility_published(p.visibility, p.published_at)", "rpc_get_public_posts_feed", failures);

  assertContains(detailBody, "jsonb_build_object('error_code', 'not_found')", "rpc_get_public_post_detail", failures);

  assertContains(commentsBody, "public.guard_block(v_viewer_id, v_post_author_id)", "rpc_get_public_post_comments", failures);
  assertContains(commentsBody, "public.guard_soft_state(v_post_deleted_at, v_post_hidden_at)", "rpc_get_public_post_comments", failures);
  assertContains(
    commentsBody,
    "public.guard_visibility_published(v_post_visibility, v_post_published_at)",
    "rpc_get_public_post_comments",
    failures,
  );
  assertContains(commentsBody, "jsonb_build_object('error_code', 'not_found')", "rpc_get_public_post_comments", failures);

  assertOrder(
    createCommentBody,
    [
      "v_guard := public.guard_terms_agreed();",
      "public.guard_block(v_user_id, v_post.author_id)",
      "public.guard_soft_state(v_post.deleted_at, v_post.hidden_at)",
      "public.guard_visibility_published(v_post.visibility, v_post.published_at)",
    ],
    "rpc_create_comment",
    failures,
  );

  assertOrder(
    toggleLikeBody,
    [
      "v_guard := public.guard_terms_agreed();",
      "public.guard_block(v_user_id, v_target_author_id)",
      "public.guard_soft_state(v_target_deleted_at, v_target_hidden_at)",
    ],
    "rpc_toggle_like",
    failures,
  );

  const posts = Array.isArray(fixture.posts) ? fixture.posts : [];
  const basePostA = posts.find((post) => post.author === "A" && post.id === "00000000-0000-4000-8000-000000002001");
  const postB = posts.find((post) => post.author === "B");

  if (!basePostA || !postB) {
    failures.push("fixture must include public posts from A and B");
    return;
  }

  const feedForB = simulatePublicFeed("B", fixture);
  if (feedForB.some((post) => post.author_nickname === fixture.users.A.nickname)) {
    failures.push("G-1 fail: blocked viewer B can still see A public post in feed");
  }

  const feedForA = simulatePublicFeed("A", fixture);
  if (feedForA.some((post) => post.author_nickname === fixture.users.B.nickname)) {
    failures.push("T-1 fail: blocked viewer A can still see B public post in feed");
  }

  const feedForC = simulatePublicFeed("C", fixture);
  const hiddenOrDeletedIds = new Set(
    posts.filter((post) => post.hidden_at || post.deleted_at).map((post) => post.id),
  );
  if (feedForC.some((post) => hiddenOrDeletedIds.has(post.id))) {
    failures.push("T-1 fail: hidden/deleted posts leaked into public feed");
  }

  const feedForbidden = findForbiddenPaths(feedForC);
  if (feedForbidden.length > 0) {
    failures.push(`G-2 fail: forbidden DTO fields found in feed response: ${feedForbidden.join(", ")}`);
  }

  const commentsUnpublished = simulatePublicPostComments(
    {
      ...basePostA,
      published_at: null,
    },
    "C",
    fixture,
  );
  if (!commentsUnpublished || commentsUnpublished.error_code !== "not_found") {
    failures.push("G-3/T-5 fail: unpublished parent post must return not_found for comments");
  }

  const commentsHidden = simulatePublicPostComments(
    {
      ...basePostA,
      hidden_at: "2026-01-02T00:00:00Z",
    },
    "C",
    fixture,
  );
  if (!commentsHidden || commentsHidden.error_code !== "not_found") {
    failures.push("T-5 fail: hidden parent post must return not_found for comments");
  }

  const commentsDeleted = simulatePublicPostComments(
    {
      ...basePostA,
      deleted_at: "2026-01-02T00:00:00Z",
    },
    "C",
    fixture,
  );
  if (!commentsDeleted || commentsDeleted.error_code !== "not_found") {
    failures.push("T-5 fail: deleted parent post must return not_found for comments");
  }

  const commentsBlocked = simulatePublicPostComments(basePostA, "B", fixture);
  if (!commentsBlocked || commentsBlocked.error_code !== "not_found") {
    failures.push("T-5 fail: blocked viewer must receive not_found for comments");
  }

  const commentsMissing = simulatePublicPostComments(null, "C", fixture);
  if (!commentsMissing || commentsMissing.error_code !== "not_found") {
    failures.push("T-5 fail: missing parent post must return not_found for comments");
  }

  for (const scenario of [
    {
      name: "private",
      post: { ...basePostA, visibility: "private", published_at: null },
    },
    {
      name: "unpublished",
      post: { ...basePostA, published_at: null },
    },
    {
      name: "hidden",
      post: { ...basePostA, hidden_at: "2026-01-02T00:00:00Z" },
    },
    {
      name: "deleted",
      post: { ...basePostA, deleted_at: "2026-01-02T00:00:00Z" },
    },
  ]) {
    const detailResult = simulatePublicPostDetail(scenario.post, "C", fixture);
    if (!detailResult || detailResult.error_code !== "not_found") {
      failures.push(`G-4 fail: ${scenario.name} post detail must return not_found`);
    }
  }

  const blockedDetail = simulatePublicPostDetail(basePostA, "B", fixture);
  if (!blockedDetail || blockedDetail.error_code !== "not_found") {
    failures.push("G-4 fail: blocked post detail must return not_found");
  }

  const missingDetail = simulatePublicPostDetail(null, "C", fixture);
  if (!missingDetail || missingDetail.error_code !== "not_found") {
    failures.push("G-4 fail: missing post detail must return not_found");
  }

  const dtoBodies = [feedBody, detailBody, commentsBody];
  for (const [index, body] of dtoBodies.entries()) {
    const keys = extractJsonBuildKeys(body);
    const forbidden = keys.filter(
      (key) => FORBIDDEN_DTO_KEYS.has(key) || key.startsWith("reason_"),
    );
    if (forbidden.length > 0) {
      failures.push(`DCI-4 fail: forbidden key(s) in public DTO builder #${index + 1}: ${forbidden.join(", ")}`);
    }
  }

  const detailVisible = simulatePublicPostDetail(basePostA, "C", fixture);
  const commentsVisible = simulatePublicPostComments(basePostA, "C", fixture);
  for (const [name, payload] of [
    ["detail", detailVisible],
    ["comments", commentsVisible],
  ]) {
    const forbidden = findForbiddenPaths(payload);
    if (forbidden.length > 0) {
      failures.push(`DCI-4 fail: forbidden DTO field in public ${name} payload: ${forbidden.join(", ")}`);
    }
  }
}

function runGrantChecks(sqlSource, failures) {
  const requiredGrantLines = [
    "grant execute on function public.rpc_get_public_posts_feed(text, int) to anon;",
    "grant execute on function public.rpc_get_public_posts_feed(text, int) to authenticated;",
    "grant execute on function public.rpc_get_public_post_detail(uuid) to anon;",
    "grant execute on function public.rpc_get_public_post_detail(uuid) to authenticated;",
    "grant execute on function public.rpc_get_public_post_comments(uuid, text, int) to anon;",
    "grant execute on function public.rpc_get_public_post_comments(uuid, text, int) to authenticated;",
    "grant execute on function public.rpc_toggle_like(text, uuid) to authenticated;",
  ];

  for (const line of requiredGrantLines) {
    if (!sqlSource.includes(line)) {
      failures.push(`missing grant/revoke policy line: ${line}`);
    }
  }
}

export function runPublicGate({ requireExact = false } = {}) {
  console.log("\n-- Public Surface Gate (P1-04 exact) --");

  const failures = [];
  const manifest = readJson("tests/public-gate/manifest.json");
  const fixture = readJson("tests/fixtures/p0-04-public-surface.seed.json");
  const migrationRelativePath = "supabase/migrations/20260219040000_p1_04_nyanstagram_rpc.sql";
  const migrationFullPath = resolve(rootDir, migrationRelativePath);

  if (!existsSync(migrationFullPath)) {
    failures.push(`missing migration file: ${migrationRelativePath}`);
  }

  runManifestChecks(manifest, failures, { requireExact });
  runFixtureChecks(fixture, failures);

  if (existsSync(migrationFullPath)) {
    const migrationSql = readText(migrationRelativePath);
    runGrantChecks(migrationSql, failures);
    runGateChecks({ fixture, migrationSql, failures });
  }

  if (failures.length > 0) {
    for (const failure of failures) {
      console.error(`FAIL: ${failure}`);
    }
    return { exitCode: 1 };
  }

  console.log("PASS: ci:public-gate exact checks");
  return { exitCode: 0 };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const requireExact = process.argv.includes("--require-exact");
  const { exitCode } = runPublicGate({ requireExact });
  process.exit(exitCode);
}

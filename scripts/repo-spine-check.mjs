import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();

export const CANONICAL_SCRIPT_NAMES = [
  "repo:lint",
  "repo:typecheck",
  "repo:test",
  "db:reset",
  "db:smoke",
  "ci:verify",
  "ci:public-gate",
  "ci:drift"
];

export const REQUIRED_STUB_PATHS = [
  "apps/expo/app/(tabs)/_layout.tsx",
  "apps/expo/app/(tabs)/house.tsx",
  "apps/expo/app/(tabs)/diary.tsx",
  "apps/expo/app/(tabs)/social.tsx",
  "apps/expo/app/(tabs)/settings.tsx",
  "apps/web/app/c/page.tsx",
  "apps/web/app/c/[topicSlug]/page.tsx",
  "apps/web/app/c/[topicSlug]/[threadId]/page.tsx",
  "apps/web/app/p/page.tsx",
  "apps/web/app/p/[postId]/page.tsx",
  "apps/web/app/search/page.tsx",
  "packages/shared/src/error-codes.ts",
  "packages/shared/src/public-dto.ts",
  "packages/shared/src/index.ts",
  "supabase/migrations/20260211143853_init.sql"
];

export function readJson(relativePath) {
  const targetPath = path.join(ROOT, relativePath);
  const raw = fs.readFileSync(targetPath, "utf8");
  return JSON.parse(raw);
}

export function findMissingPaths(paths) {
  return paths.filter((relativePath) => !fs.existsSync(path.join(ROOT, relativePath)));
}

export function ensureCanonicalScripts(packageJson) {
  const scripts = packageJson.scripts || {};
  return CANONICAL_SCRIPT_NAMES.filter((name) => typeof scripts[name] !== "string" || scripts[name].trim() === "");
}

export function readText(relativePath) {
  return fs.readFileSync(path.join(ROOT, relativePath), "utf8");
}

export function failWithList(title, items) {
  if (items.length === 0) {
    return false;
  }
  console.error(`FAIL: ${title}`);
  for (const item of items) {
    console.error(` - ${item}`);
  }
  return true;
}

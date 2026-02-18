import { readdirSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const FORBIDDEN_JOIN_PATTERNS = [
  /\b(?:public\.)?profiles\.id\s*=\s*[a-z_][a-z0-9_.]*_id\b/gi,
  /\b[a-z_][a-z0-9_.]*_id\s*=\s*(?:public\.)?profiles\.id\b/gi,
];

function listFilesRecursive(dirPath, extension) {
  const results = [];
  const queue = [dirPath];

  while (queue.length > 0) {
    const current = queue.pop();
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const fullPath = resolve(current, entry.name);
      if (entry.isDirectory()) {
        queue.push(fullPath);
        continue;
      }
      if (entry.isFile() && fullPath.endsWith(extension)) {
        results.push(fullPath);
      }
    }
  }

  return results.sort();
}

function lineNumberAt(source, index) {
  return source.slice(0, index).split(/\r?\n/).length;
}

export function findForbiddenProfilesJoinPatterns(source) {
  const matches = [];

  for (const pattern of FORBIDDEN_JOIN_PATTERNS) {
    pattern.lastIndex = 0;
    for (const match of source.matchAll(pattern)) {
      const matchText = match[0];
      const index = match.index ?? 0;
      matches.push({
        text: matchText,
        index,
      });
    }
  }

  return matches;
}

export function checkDci1ProfilesJoin({ rootDir }) {
  const migrationDir = resolve(rootDir, "supabase", "migrations");
  const sqlFiles = listFilesRecursive(migrationDir, ".sql");
  const violations = [];

  for (const fullPath of sqlFiles) {
    const source = readFileSync(fullPath, "utf8");
    const matches = findForbiddenProfilesJoinPatterns(source);

    for (const match of matches) {
      violations.push(
        `${relative(rootDir, fullPath)}:${lineNumberAt(source, match.index)} -> ${match.text}`,
      );
    }
  }

  return {
    id: "DCI-1",
    title: "join lint (profiles.id forbidden)",
    pass: violations.length === 0,
    details:
      violations.length === 0
        ? [`checked ${sqlFiles.length} sql file(s)`]
        : violations,
  };
}

function runNegativeSelfTest() {
  const sample = "select 1 from public.posts p join public.profiles on profiles.id = p.author_id;";
  const matches = findForbiddenProfilesJoinPatterns(sample);

  if (matches.length === 0) {
    console.error("FAIL: DCI-1 negative self-test did not catch forbidden join");
    return 1;
  }

  console.log("PASS: DCI-1 negative self-test caught forbidden join pattern");
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.includes("--self-test-negative")) {
    process.exit(runNegativeSelfTest());
  }

  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const rootDir = resolve(scriptDir, "..", "..");
  const result = checkDci1ProfilesJoin({ rootDir });
  if (!result.pass) {
    for (const detail of result.details) {
      console.error(`FAIL: ${detail}`);
    }
    process.exit(1);
  }
  console.log(`PASS: [${result.id}] ${result.title}`);
}

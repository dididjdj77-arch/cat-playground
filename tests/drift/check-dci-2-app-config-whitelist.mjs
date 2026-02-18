import { readdirSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

function uniqSorted(values) {
  return [...new Set(values)].sort();
}

function parseConfigBaselineKeys(source) {
  const sectionMatch = source.match(/##\s*3\.\s*app_config key[\s\S]*?(?:\n##\s|$)/i);
  if (!sectionMatch) {
    throw new Error("CONFIG-BASELINES.md missing section '## 3. app_config key ...'");
  }

  const keys = [];
  const lines = sectionMatch[0].split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^\|\s*([a-z0-9_\-/]+)\s*\|/i);
    if (!match) {
      continue;
    }

    const key = match[1].trim();
    if (key === "key" || /^-+$/.test(key)) {
      continue;
    }
    keys.push(key);
  }

  return uniqSorted(keys);
}

function extractRpcWhitelistFromSql(sqlSource) {
  const rpcBlockRegex =
    /create\s+or\s+replace\s+function\s+public\.rpc_get_app_config\s*\([^)]*\)[\s\S]*?\$\$([\s\S]*?)\$\$/gi;

  let lastRpcBody = null;
  for (const match of sqlSource.matchAll(rpcBlockRegex)) {
    lastRpcBody = match[1];
  }

  if (!lastRpcBody) {
    return null;
  }

  const inClause = lastRpcBody.match(/where\s+key\s+in\s*\(([^)]*)\)/i);
  if (!inClause) {
    return [];
  }

  const keys = [];
  const keyRegex = /'([^']+)'/g;
  for (const match of inClause[1].matchAll(keyRegex)) {
    keys.push(match[1]);
  }

  return uniqSorted(keys);
}

export function checkDci2AppConfigWhitelist({ rootDir }) {
  const configDocPath = resolve(rootDir, "docs", "CONFIG-BASELINES.md");
  const configSource = readFileSync(configDocPath, "utf8");
  const docKeys = parseConfigBaselineKeys(configSource);

  const migrationDir = resolve(rootDir, "supabase", "migrations");
  const migrationFiles = readdirSync(migrationDir)
    .filter((name) => name.endsWith(".sql"))
    .sort();

  let rpcKeys = null;
  let rpcSourceFile = null;

  for (const fileName of migrationFiles) {
    const fullPath = resolve(migrationDir, fileName);
    const sqlSource = readFileSync(fullPath, "utf8");
    const extracted = extractRpcWhitelistFromSql(sqlSource);
    if (extracted !== null) {
      rpcKeys = extracted;
      rpcSourceFile = fullPath;
    }
  }

  if (!rpcKeys || !rpcSourceFile) {
    return {
      id: "DCI-2",
      title: "app_config whitelist snapshot",
      pass: false,
      details: ["could not find public.rpc_get_app_config whitelist in migrations"],
    };
  }

  const inDocOnly = docKeys.filter((key) => !rpcKeys.includes(key));
  const inRpcOnly = rpcKeys.filter((key) => !docKeys.includes(key));
  const pass = inDocOnly.length === 0 && inRpcOnly.length === 0;

  const details = [];
  details.push(`doc keys (${docKeys.length}): ${docKeys.join(", ")}`);
  details.push(
    `rpc keys (${rpcKeys.length}) from ${relative(rootDir, rpcSourceFile)}: ${rpcKeys.join(", ")}`,
  );
  if (inDocOnly.length > 0) {
    details.push(`CONFIG-BASELINES.md only: ${inDocOnly.join(", ")}`);
  }
  if (inRpcOnly.length > 0) {
    details.push(`rpc_get_app_config only: ${inRpcOnly.join(", ")}`);
  }

  return {
    id: "DCI-2",
    title: "app_config whitelist snapshot",
    pass,
    details,
  };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const rootDir = resolve(scriptDir, "..", "..");
  const result = checkDci2AppConfigWhitelist({ rootDir });

  if (!result.pass) {
    for (const detail of result.details) {
      console.error(`FAIL: ${detail}`);
    }
    process.exit(1);
  }

  console.log(`PASS: [${result.id}] ${result.title}`);
}

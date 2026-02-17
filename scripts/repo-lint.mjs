import {
  REQUIRED_STUB_PATHS,
  ensureCanonicalScripts,
  failWithList,
  findMissingPaths,
  readJson
} from "./repo-spine-check.mjs";

const packageJson = readJson("package.json");

const missingPaths = findMissingPaths(REQUIRED_STUB_PATHS);
const missingScripts = ensureCanonicalScripts(packageJson);

const failed =
  failWithList("missing required P0-01 stub paths", missingPaths) ||
  failWithList("missing canonical script names in package.json", missingScripts);

if (failed) {
  process.exit(1);
}

console.log("PASS: repo:lint");

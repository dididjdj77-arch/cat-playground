import { spawnSync } from "node:child_process";
import { runDriftChecks } from "../tests/drift/run-drift-checks.mjs";

function checkGeneratedTypesDrift() {
  const result = spawnSync(process.execPath, ["scripts/gen-db-types.mjs", "--check"], {
    stdio: "inherit"
  });

  return result.status ?? 1;
}

const { exitCode: driftExitCode } = runDriftChecks();
const generatedTypesExitCode = checkGeneratedTypesDrift();

process.exit(driftExitCode || generatedTypesExitCode);

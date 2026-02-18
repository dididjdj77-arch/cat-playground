import { runDriftChecks } from "../tests/drift/run-drift-checks.mjs";

const { exitCode } = runDriftChecks();

process.exit(exitCode);

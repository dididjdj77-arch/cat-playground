import { runPublicGate } from "../tests/public-gate/run-public-gate.mjs";

const requireExact = process.argv.includes("--require-exact");
const { exitCode } = runPublicGate({ requireExact });

process.exit(exitCode);

import type { AuthSpikeActionResult, AuthSpikeEvent, AuthSpikeLevel } from "./types";

let eventSequence = 0;

function levelFromResult(result: AuthSpikeActionResult): AuthSpikeLevel {
  return result.ok ? "success" : "error";
}

export function createAuthSpikeEvent(result: AuthSpikeActionResult): AuthSpikeEvent {
  eventSequence += 1;

  return {
    id: `auth-spike-${eventSequence}`,
    gate: result.gate,
    level: levelFromResult(result),
    title: result.title,
    detail: result.detail,
    createdAt: new Date().toISOString(),
  };
}

export function formatAuthSpikeEvent(event: AuthSpikeEvent): string {
  const detail = event.detail ? ` - ${event.detail}` : "";
  return `${event.createdAt} [${event.gate}] ${event.level.toUpperCase()} ${event.title}${detail}`;
}

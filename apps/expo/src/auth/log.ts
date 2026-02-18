import type { AuthActionResult, AuthEvent, AuthLevel } from "./types";

let eventSequence = 0;

function levelFromResult(result: AuthActionResult): AuthLevel {
  return result.ok ? "success" : "error";
}

export function createAuthEvent(result: AuthActionResult): AuthEvent {
  eventSequence += 1;

  return {
    id: `auth-${eventSequence}`,
    gate: result.gate,
    level: levelFromResult(result),
    title: result.title,
    detail: result.detail,
    createdAt: new Date().toISOString(),
  };
}

export function formatAuthEvent(event: AuthEvent): string {
  const detail = event.detail ? ` - ${event.detail}` : "";
  return `${event.createdAt} [${event.gate}] ${event.level.toUpperCase()} ${event.title}${detail}`;
}

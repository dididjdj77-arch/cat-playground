import type { AuthActionResult } from "../auth";
import {
  SESSION_EDGE_EVENT_KEYS,
  type SessionActionExecution,
  type SessionEdgeLogEntry,
  type SessionEdgeState,
  type SessionEdgeTransitionInput,
  type SessionRecoveryAction,
  type SessionRunWithPolicyOptions,
  type SessionTimeoutResultInput,
  type SessionRetryPolicy,
} from "./types";

// Structural checks are preferred; regex patterns are fallback for untyped errors.
const NETWORK_ERROR_PATTERN = /network request failed|failed to fetch|network error|offline|timeout|timed out/i;
const EXPIRED_ERROR_PATTERN = /jwt.+expired|token.+expired|refresh token.+(missing|invalid|expired)/i;
const NO_SESSION_PATTERN = /no active session|returned no session/i;
const OAUTH_CANCEL_PATTERN = /browser result:\s*(cancel|dismiss|locked)/i;
const RPC_ERROR_CODE_PATTERN = /error_code=/i;

let sessionEdgeLogSequence = 0;

interface StructuralAuthError {
  __isAuthError?: boolean;
  status?: number;
  code?: string;
}

export const SESSION_EDGE_RETRY_POLICY: SessionRetryPolicy = {
  timeoutMs: 8000,
  retryDelayMs: 1200,
  maxAttempts: 2,
};

class SessionActionTimeoutError extends Error {
  readonly timeoutMs: number;

  constructor(timeoutMs: number) {
    super(`Session action timed out after ${timeoutMs}ms`);
    this.name = "SessionActionTimeoutError";
    this.timeoutMs = timeoutMs;
  }
}

function toSearchableText(result: AuthActionResult): string {
  return `${result.title} ${result.detail ?? ""}`;
}

function extractStructuralError(result: AuthActionResult): StructuralAuthError | null {
  const payload = result.payload;
  if (typeof payload === "object" && payload !== null) {
    return payload as StructuralAuthError;
  }
  return null;
}

function isOfflineResult(result: AuthActionResult): boolean {
  const structural = extractStructuralError(result);
  if (structural?.code === "network_error" || structural?.status === 0) {
    return true;
  }
  return NETWORK_ERROR_PATTERN.test(toSearchableText(result));
}

function isSessionMissingResult(result: AuthActionResult): boolean {
  const structural = extractStructuralError(result);
  if (structural?.code === "session_not_found" || structural?.code === "no_session") {
    return true;
  }
  return NO_SESSION_PATTERN.test(toSearchableText(result));
}

function isSessionExpiredResult(result: AuthActionResult): boolean {
  const structural = extractStructuralError(result);
  if (structural?.__isAuthError && (structural.status === 401 || structural.code === "session_expired")) {
    return true;
  }
  return EXPIRED_ERROR_PATTERN.test(toSearchableText(result));
}

function isOauthCancelledResult(result: AuthActionResult): boolean {
  if (result.gate !== "AS-2") {
    return false;
  }

  const text = toSearchableText(result);
  return OAUTH_CANCEL_PATTERN.test(text) || text.includes("redirect was not completed");
}

function isRpcBusinessErrorResult(result: AuthActionResult): boolean {
  if (result.gate !== "AS-4") {
    return false;
  }

  return RPC_ERROR_CODE_PATTERN.test(result.title);
}

function appendAttemptDetail(detail: string | undefined, attempts: number): string | undefined {
  if (attempts <= 1) {
    return detail;
  }

  if (!detail) {
    return `Retry attempts: ${attempts}`;
  }

  return `${detail} (retry attempts: ${attempts})`;
}

function nextHasActiveSession(status: SessionEdgeState["status"], hadActiveSession: boolean): boolean {
  if (status === "active" || status === "refreshed") {
    return true;
  }

  if (status === "expired" || status === "signed-out") {
    return false;
  }

  return hadActiveSession;
}

function createState(
  input: Omit<SessionEdgeState, "hasActiveSession">,
  hadActiveSession: boolean,
): SessionEdgeState {
  return {
    ...input,
    hasActiveSession: nextHasActiveSession(input.status, hadActiveSession),
  };
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new SessionActionTimeoutError(timeoutMs));
    }, timeoutMs);

    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timer);
        reject(error);
      },
    );
  });
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function defaultShouldRetry(result: AuthActionResult): boolean {
  if (result.ok) {
    return false;
  }

  if (isOfflineResult(result)) {
    return true;
  }

  return result.gate === "AS-4" && !isRpcBusinessErrorResult(result);
}

export function createInitialSessionEdgeState(): SessionEdgeState {
  return {
    status: "idle",
    eventKey: SESSION_EDGE_EVENT_KEYS.idle,
    gate: "AS-3",
    title: "Session edge UX is idle",
    detail: "Run login/session/rpc actions to collect edge-state evidence.",
    recoverable: true,
    recoveryAction: "none",
    hasActiveSession: false,
  };
}

export function buildSessionTimeoutResult(input: SessionTimeoutResultInput): AuthActionResult {
  return {
    ok: false,
    gate: input.gate,
    title: input.title,
    detail: `No response within ${input.timeoutMs}ms.`,
  };
}

export function getSessionRecoveryActionLabel(action: SessionRecoveryAction): string {
  switch (action) {
    case "none":
      return "No action required";
    case "retry":
      return "Retry last action";
    case "sign-in":
      return "Sign in again";
    case "check-network":
      return "Restore network and retry";
    default:
      return action;
  }
}

export async function runSessionActionWithPolicy(
  runner: () => Promise<AuthActionResult>,
  options: SessionRunWithPolicyOptions,
): Promise<SessionActionExecution> {
  const policy: SessionRetryPolicy = {
    ...SESSION_EDGE_RETRY_POLICY,
    ...(options.policy ?? {}),
  };

  const shouldRetry = options.shouldRetry ?? defaultShouldRetry;
  let attempts = 0;
  let lastTimedOut = false;

  while (attempts < policy.maxAttempts) {
    attempts += 1;
    lastTimedOut = false;

    try {
      const result = await withTimeout(runner(), policy.timeoutMs);

      if (!shouldRetry(result) || attempts >= policy.maxAttempts) {
        return {
          result,
          attempts,
          timedOut: false,
        };
      }
    } catch (error) {
      if (error instanceof SessionActionTimeoutError) {
        lastTimedOut = true;

        if (attempts >= policy.maxAttempts) {
          return {
            result: options.timeoutResult,
            attempts,
            timedOut: true,
          };
        }
      } else {
        throw error;
      }
    }

    await delay(policy.retryDelayMs * attempts);
  }

  return {
    result: options.timeoutResult,
    attempts,
    timedOut: lastTimedOut,
  };
}

export function deriveSessionEdgeStateFromResult(input: SessionEdgeTransitionInput): SessionEdgeState {
  const attempts = input.attempts ?? 1;
  const detailWithAttempt = appendAttemptDetail(input.result.detail, attempts);

  if (input.action === "oauth" && input.result.ok) {
    return createState(
      {
        status: "progress",
        eventKey: SESSION_EDGE_EVENT_KEYS.oauthCompleted,
        gate: input.result.gate,
        title: "OAuth redirect completed",
        detail: "Reading session and running auth-only RPC next.",
        recoverable: true,
        recoveryAction: "none",
      },
      input.hadActiveSession,
    );
  }

  if (!input.result.ok && (input.timedOut || isOfflineResult(input.result))) {
    return createState(
      {
        status: "offline",
        eventKey: SESSION_EDGE_EVENT_KEYS.networkOffline,
        gate: input.result.gate,
        title: "Network/offline edge detected",
        detail: detailWithAttempt,
        recoverable: true,
        recoveryAction: "check-network",
      },
      input.hadActiveSession,
    );
  }

  if (input.action === "oauth" && !input.result.ok && isOauthCancelledResult(input.result)) {
    return createState(
      {
        status: "cancelled",
        eventKey: SESSION_EDGE_EVENT_KEYS.oauthCancelled,
        gate: input.result.gate,
        title: "OAuth flow was cancelled",
        detail: detailWithAttempt,
        recoverable: true,
        recoveryAction: "sign-in",
      },
      input.hadActiveSession,
    );
  }

  if (input.action === "sign-out") {
    if (input.result.ok) {
      return createState(
        {
          status: "signed-out",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionSignedOut,
          gate: input.result.gate,
          title: "Session signed out",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "sign-in",
        },
        input.hadActiveSession,
      );
    }

    return createState(
      {
        status: "unknown-error",
        eventKey: SESSION_EDGE_EVENT_KEYS.unknownError,
        gate: input.result.gate,
        title: "Sign-out failed",
        detail: detailWithAttempt,
        recoverable: true,
        recoveryAction: "sign-in",
      },
      input.hadActiveSession,
    );
  }

  if (input.action === "session-refresh") {
    if (input.result.ok) {
      return createState(
        {
          status: "refreshed",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionRefreshed,
          gate: input.result.gate,
          title: "Session refresh completed",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "none",
        },
        input.hadActiveSession,
      );
    }

    if (isSessionMissingResult(input.result) || isSessionExpiredResult(input.result)) {
      return createState(
        {
          status: "expired",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionExpired,
          gate: input.result.gate,
          title: "Session expired or refresh token invalid",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "sign-in",
        },
        input.hadActiveSession,
      );
    }
  }

  if (input.action === "session-read") {
    if (input.result.ok) {
      return createState(
        {
          status: "active",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionActive,
          gate: input.result.gate,
          title: "Session is active",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "none",
        },
        input.hadActiveSession,
      );
    }

    if (isSessionMissingResult(input.result) || isSessionExpiredResult(input.result)) {
      return createState(
        {
          status: input.hadActiveSession ? "expired" : "signed-out",
          eventKey: input.hadActiveSession
            ? SESSION_EDGE_EVENT_KEYS.sessionExpired
            : SESSION_EDGE_EVENT_KEYS.sessionSignedOut,
          gate: input.result.gate,
          title: input.hadActiveSession ? "Session expired or forced sign-out" : "No active session",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "sign-in",
        },
        input.hadActiveSession,
      );
    }
  }

  if (input.action === "rpc-check") {
    if (input.result.ok) {
      return createState(
        {
          status: "active",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionActive,
          gate: input.result.gate,
          title: "Auth-only RPC check succeeded",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "none",
        },
        input.hadActiveSession,
      );
    }

    if (isSessionMissingResult(input.result) || isSessionExpiredResult(input.result)) {
      return createState(
        {
          status: "expired",
          eventKey: SESSION_EDGE_EVENT_KEYS.sessionExpired,
          gate: input.result.gate,
          title: "Session invalid during RPC call",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "sign-in",
        },
        input.hadActiveSession,
      );
    }

    if (isRpcBusinessErrorResult(input.result)) {
      return createState(
        {
          status: "rpc-error",
          eventKey: SESSION_EDGE_EVENT_KEYS.rpcBusinessError,
          gate: input.result.gate,
          title: "RPC business error returned",
          detail: detailWithAttempt,
          recoverable: true,
          recoveryAction: "retry",
        },
        input.hadActiveSession,
      );
    }
  }

  if (input.result.ok) {
    return createState(
      {
        status: "active",
        eventKey: SESSION_EDGE_EVENT_KEYS.sessionActive,
        gate: input.result.gate,
        title: input.result.title,
        detail: detailWithAttempt,
        recoverable: true,
        recoveryAction: "none",
      },
      input.hadActiveSession,
    );
  }

  return createState(
    {
      status: "unknown-error",
      eventKey: SESSION_EDGE_EVENT_KEYS.unknownError,
      gate: input.result.gate,
      title: "Unhandled session edge error",
      detail: detailWithAttempt,
      recoverable: true,
      recoveryAction: "retry",
    },
    input.hadActiveSession,
  );
}

export function createSessionEdgeLogEntry(state: SessionEdgeState): SessionEdgeLogEntry {
  sessionEdgeLogSequence += 1;

  return {
    id: `session-edge-${sessionEdgeLogSequence}`,
    eventKey: state.eventKey,
    status: state.status,
    title: state.title,
    detail: state.detail,
    createdAt: new Date().toISOString(),
  };
}

export function appendSessionEdgeLogEntry(
  entries: SessionEdgeLogEntry[],
  entry: SessionEdgeLogEntry,
  maxEntries = 50,
): SessionEdgeLogEntry[] {
  return [entry, ...entries].slice(0, maxEntries);
}

export function formatSessionEdgeLogEntry(entry: SessionEdgeLogEntry): string {
  const detail = entry.detail ? ` - ${entry.detail}` : "";
  return `${entry.createdAt} [${entry.eventKey}] ${entry.status.toUpperCase()} ${entry.title}${detail}`;
}

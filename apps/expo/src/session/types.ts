import type { AuthActionResult, AuthGate } from "../auth";

export const SESSION_EDGE_EVENT_KEYS = {
  idle: "SE_IDLE",
  oauthCompleted: "SE_OAUTH_COMPLETED",
  oauthCancelled: "SE_OAUTH_CANCELLED",
  sessionActive: "SE_SESSION_ACTIVE",
  sessionRefreshed: "SE_SESSION_REFRESHED",
  sessionExpired: "SE_SESSION_EXPIRED",
  sessionSignedOut: "SE_SESSION_SIGNED_OUT",
  networkOffline: "SE_NETWORK_OFFLINE",
  rpcBusinessError: "SE_RPC_BUSINESS_ERROR",
  unknownError: "SE_UNKNOWN_ERROR",
} as const;

export type SessionEdgeEventKey = (typeof SESSION_EDGE_EVENT_KEYS)[keyof typeof SESSION_EDGE_EVENT_KEYS];

export type SessionEdgeAction = "oauth" | "session-read" | "session-refresh" | "rpc-check" | "sign-out";

export type SessionEdgeStatus =
  | "idle"
  | "progress"
  | "active"
  | "refreshed"
  | "expired"
  | "signed-out"
  | "offline"
  | "cancelled"
  | "rpc-error"
  | "unknown-error";

export type SessionRecoveryAction = "none" | "retry" | "sign-in" | "check-network";

export interface SessionEdgeState {
  status: SessionEdgeStatus;
  eventKey: SessionEdgeEventKey;
  gate: AuthGate;
  title: string;
  detail?: string;
  recoverable: boolean;
  recoveryAction: SessionRecoveryAction;
  hasActiveSession: boolean;
}

export interface SessionEdgeTransitionInput {
  action: SessionEdgeAction;
  result: AuthActionResult;
  hadActiveSession: boolean;
  attempts?: number;
  timedOut?: boolean;
}

export interface SessionRetryPolicy {
  timeoutMs: number;
  retryDelayMs: number;
  maxAttempts: number;
}

export interface SessionActionExecution {
  result: AuthActionResult;
  attempts: number;
  timedOut: boolean;
}

export interface SessionRunWithPolicyOptions {
  timeoutResult: AuthActionResult;
  policy?: Partial<SessionRetryPolicy>;
  shouldRetry?: (result: AuthActionResult) => boolean;
}

export interface SessionEdgeLogEntry {
  id: string;
  eventKey: SessionEdgeEventKey;
  status: SessionEdgeStatus;
  title: string;
  detail?: string;
  createdAt: string;
}

export interface SessionTimeoutResultInput {
  gate: AuthGate;
  title: string;
  timeoutMs: number;
}

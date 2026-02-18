import { useMemo, useRef, useState } from "react";
import { Button, ScrollView, StyleSheet, Text, View } from "react-native";
import {
  APP_CONFIG_KEYS,
  verifySessionWithAppConfigRpc,
  clearSession,
  createAuthEvent,
  formatAuthEvent,
  getAuthClient,
  getAuthEnvCheck,
  readSessionState,
  signInWithOAuth,
  type AuthActionResult,
  type AuthEvent,
  type AuthProvider,
} from "../../src/auth";
import {
  SESSION_EDGE_RETRY_POLICY,
  appendSessionEdgeLogEntry,
  buildSessionTimeoutResult,
  createInitialSessionEdgeState,
  createSessionEdgeLogEntry,
  deriveSessionEdgeStateFromResult,
  formatSessionEdgeLogEntry,
  getSessionRecoveryActionLabel,
  refreshSessionState,
  runSessionActionWithPolicy,
  type SessionEdgeAction,
  type SessionEdgeLogEntry,
  type SessionEdgeState,
} from "../../src/session";

export const EXPO_ROUTE_STUB = "/settings";

const REQUIRED_OAUTH_PROVIDERS: AuthProvider[] = ["apple", "kakao"];
const OPTIONAL_OAUTH_PROVIDERS: AuthProvider[] = ["google"];
const MAX_EVENT_LOGS = 50;
const MAX_SESSION_EDGE_LOGS = 50;

function appendEvent(events: AuthEvent[], event: AuthEvent): AuthEvent[] {
  return [event, ...events].slice(0, MAX_EVENT_LOGS);
}

function appendSessionEdgeEvent(events: SessionEdgeLogEntry[], event: SessionEdgeLogEntry): SessionEdgeLogEntry[] {
  return appendSessionEdgeLogEntry(events, event, MAX_SESSION_EDGE_LOGS);
}

function withRetryMeta(
  result: AuthActionResult,
  attempts: number,
  timedOut: boolean,
): AuthActionResult {
  if (attempts <= 1 && !timedOut) {
    return result;
  }

  const detailParts: string[] = [];

  if (result.detail) {
    detailParts.push(result.detail);
  }

  detailParts.push(`attempts=${attempts}`);

  if (timedOut) {
    detailParts.push("timeout=true");
  }

  return {
    ...result,
    detail: detailParts.join(" | "),
  };
}

function stringifyPayload(value: unknown): string {
  if (value === undefined) {
    return "(no payload)";
  }

  if (value === null) {
    return "null";
  }

  if (typeof value === "string") {
    return value;
  }

  return JSON.stringify(value, null, 2);
}

export default function SettingsTabAuthSession() {
  const envCheck = useMemo(() => getAuthEnvCheck(), []);
  const [eventLogs, setEventLogs] = useState<AuthEvent[]>([]);
  const [sessionEdgeState, setSessionEdgeState] = useState<SessionEdgeState>(() => createInitialSessionEdgeState());
  const [sessionEdgeLogs, setSessionEdgeLogs] = useState<SessionEdgeLogEntry[]>([]);
  const [sessionPreview, setSessionPreview] = useState<string>("(not checked)");
  const [rpcPreview, setRpcPreview] = useState<string>("(not called)");
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const hadActiveSessionRef = useRef<boolean>(false);

  const appendResult = (result: AuthActionResult) => {
    setEventLogs((current) => appendEvent(current, createAuthEvent(result)));
  };

  const appendSessionEdgeState = (state: SessionEdgeState) => {
    hadActiveSessionRef.current = state.hasActiveSession;
    setSessionEdgeState(state);
    setSessionEdgeLogs((current) => appendSessionEdgeEvent(current, createSessionEdgeLogEntry(state)));
  };

  const applySessionEdgeResult = (
    action: SessionEdgeAction,
    result: AuthActionResult,
    attempts = 1,
    timedOut = false,
  ) => {
    appendSessionEdgeState(
      deriveSessionEdgeStateFromResult({
        action,
        result,
        hadActiveSession: hadActiveSessionRef.current,
        attempts,
        timedOut,
      }),
    );
  };

  const withClient = async (
    actionName: string,
    runner: (client: ReturnType<typeof getAuthClient>) => Promise<AuthActionResult>,
  ) => {
    if (!envCheck.env) {
      appendResult({
        ok: false,
        gate: "AS-5",
        title: "Missing auth env values",
        detail: envCheck.missingKeys.join(", "),
      });
      return;
    }

    setBusyAction(actionName);

    try {
      const client = getAuthClient(envCheck.env);
      const result = await runner(client);
      appendResult(result);
    } finally {
      setBusyAction(null);
    }
  };

  const runRpcCheckWithPolicy = async (client: ReturnType<typeof getAuthClient>) => {
    const execution = await runSessionActionWithPolicy(() => verifySessionWithAppConfigRpc(client), {
      timeoutResult: buildSessionTimeoutResult({
        gate: "AS-4",
        title: "rpc_get_app_config timed out",
        timeoutMs: SESSION_EDGE_RETRY_POLICY.timeoutMs,
      }),
    });

    return {
      execution,
      result: withRetryMeta(execution.result, execution.attempts, execution.timedOut),
    };
  };

  const runSessionRefreshWithPolicy = async (client: ReturnType<typeof getAuthClient>) => {
    const execution = await runSessionActionWithPolicy(() => refreshSessionState(client), {
      timeoutResult: buildSessionTimeoutResult({
        gate: "AS-3",
        title: "Session refresh timed out",
        timeoutMs: SESSION_EDGE_RETRY_POLICY.timeoutMs,
      }),
    });

    return {
      execution,
      result: withRetryMeta(execution.result, execution.attempts, execution.timedOut),
    };
  };

  const handleOAuthLogin = async (provider: AuthProvider) => {
    await withClient(`oauth:${provider}`, async (client) => {
      if (!envCheck.env) {
        return {
          ok: false,
          gate: "AS-5",
          title: "Missing auth env values",
        };
      }

      const result = await signInWithOAuth(client, envCheck.env, provider);
      applySessionEdgeResult("oauth", result);

      if (result.ok) {
        appendResult({
          ok: true,
          gate: "AS-1",
          title: `${provider} login accepted by provider`,
        });

        const sessionResult = await readSessionState(client);
        setSessionPreview(stringifyPayload(sessionResult.payload));
        appendResult(sessionResult);
        applySessionEdgeResult("session-read", sessionResult);

        const { execution: rpcExecution, result: rpcResult } = await runRpcCheckWithPolicy(client);
        setRpcPreview(stringifyPayload(rpcResult.payload));
        appendResult(rpcResult);
        applySessionEdgeResult("rpc-check", rpcResult, rpcExecution.attempts, rpcExecution.timedOut);
      }

      return result;
    });
  };

  const handleSessionCheck = async () => {
    await withClient("session", async (client) => {
      const result = await readSessionState(client);
      setSessionPreview(stringifyPayload(result.payload));
      applySessionEdgeResult("session-read", result);
      return result;
    });
  };

  const handleSessionRefresh = async () => {
    await withClient("refresh", async (client) => {
      const { execution, result } = await runSessionRefreshWithPolicy(client);
      setSessionPreview(stringifyPayload(result.payload));
      applySessionEdgeResult("session-refresh", result, execution.attempts, execution.timedOut);
      return result;
    });
  };

  const handleSignOut = async () => {
    await withClient("signout", async (client) => {
      const result = await clearSession(client);
      setSessionPreview("(signed out)");
      applySessionEdgeResult("sign-out", result);
      return result;
    });
  };

  const handleRpcCall = async () => {
    await withClient("rpc", async (client) => {
      const { execution, result } = await runRpcCheckWithPolicy(client);
      setRpcPreview(stringifyPayload(result.payload));
      applySessionEdgeResult("rpc-check", result, execution.attempts, execution.timedOut);
      return result;
    });
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Auth Session Console (P2-01A + P2-01B)</Text>
      <Text style={styles.body}>
        Scope: login/restore plus edge UX for expiration, refresh, offline, and OAuth cancel recovery.
      </Text>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>AS-5 Environment Matrix Check</Text>
        {envCheck.env ? (
          <Text style={styles.ok}>Configured</Text>
        ) : (
          <Text style={styles.error}>Missing: {envCheck.missingKeys.join(", ")}</Text>
        )}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>AS-1 + AS-2 OAuth Login</Text>
        <Text style={styles.body}>Required providers: Apple, Kakao (D-066)</Text>
        {REQUIRED_OAUTH_PROVIDERS.map((provider) => (
          <View key={provider} style={styles.buttonRow}>
            <Button
              title={`Sign in with ${provider}`}
              onPress={() => {
                void handleOAuthLogin(provider);
              }}
              disabled={!envCheck.env || busyAction !== null}
            />
          </View>
        ))}
        <Text style={styles.body}>Optional provider: Google (D-066)</Text>
        {OPTIONAL_OAUTH_PROVIDERS.map((provider) => (
          <View key={provider} style={styles.buttonRow}>
            <Button
              title={`Sign in with ${provider} (optional)`}
              onPress={() => {
                void handleOAuthLogin(provider);
              }}
              disabled={!envCheck.env || busyAction !== null}
            />
          </View>
        ))}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>AS-3 Session</Text>
        <Text style={styles.body}>Check this after app restart to verify session restore from storage.</Text>
        <View style={styles.buttonRow}>
          <Button
            title="Check session"
            onPress={() => {
              void handleSessionCheck();
            }}
            disabled={!envCheck.env || busyAction !== null}
          />
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Refresh session token"
            onPress={() => {
              void handleSessionRefresh();
            }}
            disabled={!envCheck.env || busyAction !== null}
          />
        </View>
        <View style={styles.buttonRow}>
          <Button
            title="Sign out"
            onPress={() => {
              void handleSignOut();
            }}
            disabled={!envCheck.env || busyAction !== null}
          />
        </View>
        <Text style={styles.code}>{sessionPreview}</Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>AS-4 auth-only RPC</Text>
        <Text style={styles.body}>Keys: {APP_CONFIG_KEYS.join(", ")}</Text>
        <Text style={styles.body}>
          Retry policy: timeout={SESSION_EDGE_RETRY_POLICY.timeoutMs}ms, maxAttempts=
          {SESSION_EDGE_RETRY_POLICY.maxAttempts}, retryDelay={SESSION_EDGE_RETRY_POLICY.retryDelayMs}ms
        </Text>
        <View style={styles.buttonRow}>
          <Button
            title="Call rpc_get_app_config"
            onPress={() => {
              void handleRpcCall();
            }}
            disabled={!envCheck.env || busyAction !== null}
          />
        </View>
        <Text style={styles.code}>{rpcPreview}</Text>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>P2-01B Session Edge UX</Text>
        <Text style={styles.body}>State: {sessionEdgeState.status}</Text>
        <Text style={styles.body}>Event key: {sessionEdgeState.eventKey}</Text>
        <Text style={styles.body}>Recovery: {getSessionRecoveryActionLabel(sessionEdgeState.recoveryAction)}</Text>
        <Text style={styles.body}>{sessionEdgeState.title}</Text>
        <Text style={styles.code}>{sessionEdgeState.detail ?? "(no detail)"}</Text>
        <Text style={styles.sectionTitle}>Session Edge Log</Text>
        {sessionEdgeLogs.length === 0 ? (
          <Text style={styles.body}>No edge events yet.</Text>
        ) : (
          sessionEdgeLogs.map((edgeLog) => (
            <Text key={edgeLog.id} style={styles.logLine}>
              {formatSessionEdgeLogEntry(edgeLog)}
            </Text>
          ))
        )}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Evidence Log</Text>
        {eventLogs.length === 0 ? (
          <Text style={styles.body}>No events yet.</Text>
        ) : (
          eventLogs.map((eventLog) => (
            <Text key={eventLog.id} style={styles.logLine}>
              {formatAuthEvent(eventLog)}
            </Text>
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 24,
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
  },
  section: {
    borderWidth: 1,
    borderRadius: 10,
    borderColor: "#d4d4d8",
    padding: 12,
    gap: 8,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: "600",
  },
  buttonRow: {
    marginTop: 4,
  },
  ok: {
    color: "#166534",
    fontWeight: "600",
  },
  error: {
    color: "#991b1b",
    fontWeight: "600",
  },
  code: {
    fontFamily: "Courier",
    fontSize: 12,
    borderWidth: 1,
    borderRadius: 8,
    borderColor: "#e4e4e7",
    padding: 10,
  },
  logLine: {
    fontFamily: "Courier",
    fontSize: 11,
    lineHeight: 16,
  },
});

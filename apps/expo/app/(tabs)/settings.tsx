import { useMemo, useState } from "react";
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

export const EXPO_ROUTE_STUB = "/settings";

const REQUIRED_OAUTH_PROVIDERS: AuthProvider[] = ["apple", "kakao"];
const OPTIONAL_OAUTH_PROVIDERS: AuthProvider[] = ["google"];
const MAX_EVENT_LOGS = 50;

function appendEvent(events: AuthEvent[], event: AuthEvent): AuthEvent[] {
  return [event, ...events].slice(0, MAX_EVENT_LOGS);
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
  const [sessionPreview, setSessionPreview] = useState<string>("(not checked)");
  const [rpcPreview, setRpcPreview] = useState<string>("(not called)");
  const [busyAction, setBusyAction] = useState<string | null>(null);

  const appendResult = (result: AuthActionResult) => {
    setEventLogs((current) => appendEvent(current, createAuthEvent(result)));
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

      if (result.ok) {
        appendResult({
          ok: true,
          gate: "AS-1",
          title: `${provider} login accepted by provider`,
        });

        const sessionResult = await readSessionState(client);
        setSessionPreview(stringifyPayload(sessionResult.payload));
        appendResult(sessionResult);

        const rpcResult = await verifySessionWithAppConfigRpc(client);
        setRpcPreview(stringifyPayload(rpcResult.payload));
        appendResult(rpcResult);
      }

      return result;
    });
  };

  const handleSessionCheck = async () => {
    await withClient("session", async (client) => {
      const result = await readSessionState(client);
      setSessionPreview(stringifyPayload(result.payload));
      return result;
    });
  };

  const handleSignOut = async () => {
    await withClient("signout", async (client) => {
      const result = await clearSession(client);
      setSessionPreview("(signed out)");
      return result;
    });
  };

  const handleRpcCall = async () => {
    await withClient("rpc", async (client) => {
      const result = await verifySessionWithAppConfigRpc(client);
      setRpcPreview(stringifyPayload(result.payload));
      return result;
    });
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Auth Session Console (P2-01A)</Text>
      <Text style={styles.body}>
        Scope: login - redirect callback - session create/store/restore - auth-only rpc_get_app_config check.
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

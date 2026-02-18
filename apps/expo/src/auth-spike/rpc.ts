import type { SupabaseClient } from "@supabase/supabase-js";
import type { AuthSpikeActionResult } from "./types";

export const AUTH_SPIKE_APP_CONFIG_KEYS = [
  "rate_limits",
  "rate_limits_new_account",
  "auto_hide",
  "popular_feed",
] as const;

const UX_ERROR_CODE_HINTS: Record<string, string> = {
  not_found: "Treat as 404 UX.",
  terms_not_agreed: "Show terms agreement flow.",
  version_conflict: "Show stale-data conflict UX.",
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function readErrorCode(value: unknown): string | null {
  if (!isRecord(value)) {
    return null;
  }

  const errorCode = value.error_code;

  if (typeof errorCode !== "string") {
    return null;
  }

  return errorCode;
}

export async function callAppConfigRpc(client: SupabaseClient): Promise<AuthSpikeActionResult> {
  const { data, error } = await client.rpc("rpc_get_app_config", {
    p_keys: [...AUTH_SPIKE_APP_CONFIG_KEYS],
  });

  if (error) {
    return {
      ok: false,
      gate: "AS-4",
      title: "rpc_get_app_config failed",
      detail: error.message,
    };
  }

  const errorCode = readErrorCode(data);

  if (errorCode) {
    const hint = UX_ERROR_CODE_HINTS[errorCode] ?? "Unknown error_code from RPC response.";

    return {
      ok: false,
      gate: "AS-4",
      title: `rpc_get_app_config returned error_code=${errorCode}`,
      detail: hint,
      payload: data,
    };
  }

  return {
    ok: true,
    gate: "AS-4",
    title: "rpc_get_app_config returned data",
    payload: data,
  };
}

export async function callUnknownKeyRpc(client: SupabaseClient): Promise<AuthSpikeActionResult> {
  const { data, error } = await client.rpc("rpc_get_app_config", {
    p_keys: ["unknown_key"],
  });

  if (error) {
    return {
      ok: false,
      gate: "AS-4",
      title: "Unknown key call failed",
      detail: error.message,
    };
  }

  return {
    ok: true,
    gate: "AS-4",
    title: "Unknown key call completed",
    detail: "Expected payload is {} because unknown keys are ignored.",
    payload: data,
  };
}

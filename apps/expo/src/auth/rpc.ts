import type { SupabaseClient } from "@supabase/supabase-js";
import { RpcBusinessError } from "@cat-playground/shared";
import { callSupabaseRpcWithAdapter, UnknownRpcErrorCodeError } from "../transport";
import type { AuthActionResult } from "./types";

export const APP_CONFIG_KEYS = ["rate_limits", "rate_limits_new_account", "auto_hide", "popular_feed"] as const;

const UX_ERROR_CODE_HINTS: Record<RpcBusinessError["code"], string> = {
  not_found: "Treat as 404 UX.",
  invalid_request: "Show validation message UX.",
  invalid_payload_version: "Show payload version validation UX.",
  rejected_version: "Block write and prompt payload update.",
  terms_not_agreed: "Show terms agreement flow.",
  version_conflict: "Show stale-data conflict UX.",
  duplicate_report: "Show duplicate submission UX.",
  invalid_target_type: "Show invalid target type validation UX.",
  invalid_inventory_item: "Show invalid inventory item validation UX.",
};

function toRpcFailureResult(title: string, error: unknown): AuthActionResult {
  if (error instanceof RpcBusinessError) {
    return {
      ok: false,
      gate: "AS-4",
      title: `${title}: error_code=${error.code}`,
      detail: `${UX_ERROR_CODE_HINTS[error.code]} (HTTP ${error.status})`,
      payload: error.body,
    };
  }

  if (error instanceof UnknownRpcErrorCodeError) {
    return {
      ok: false,
      gate: "AS-4",
      title: `${title}: unknown error_code=${error.errorCode}`,
      detail: "Unknown error_code from RPC response.",
      payload: error.body,
    };
  }

  if (error instanceof Error) {
    return {
      ok: false,
      gate: "AS-4",
      title,
      detail: error.message,
    };
  }

  return {
    ok: false,
    gate: "AS-4",
    title,
    detail: "Unknown runtime error.",
  };
}

export async function verifySessionWithAppConfigRpc(client: SupabaseClient): Promise<AuthActionResult> {
  try {
    const data = await callSupabaseRpcWithAdapter(client, "rpc_get_app_config", {
      p_keys: [...APP_CONFIG_KEYS],
    });

    return {
      ok: true,
      gate: "AS-4",
      title: "rpc_get_app_config returned data",
      payload: data,
    };
  } catch (error) {
    return toRpcFailureResult("rpc_get_app_config failed", error);
  }
}

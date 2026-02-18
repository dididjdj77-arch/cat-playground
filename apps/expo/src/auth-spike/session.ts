import type { Session, SupabaseClient } from "@supabase/supabase-js";
import type { AuthSpikeActionResult } from "./types";

function summarizeSession(session: Session) {
  return {
    userId: session.user.id,
    provider: session.user.app_metadata.provider ?? null,
    expiresAt: session.expires_at ?? null,
    accessTokenHead: session.access_token.slice(0, 8),
  };
}

export async function readSessionState(client: SupabaseClient): Promise<AuthSpikeActionResult> {
  const { data, error } = await client.auth.getSession();

  if (error) {
    return {
      ok: false,
      gate: "AS-3",
      title: "Session lookup failed",
      detail: error.message,
    };
  }

  if (!data.session) {
    return {
      ok: false,
      gate: "AS-3",
      title: "No active session",
      detail: "Sign in first to verify persistence.",
      payload: null,
    };
  }

  return {
    ok: true,
    gate: "AS-3",
    title: "Session is active",
    payload: summarizeSession(data.session),
  };
}

export async function clearSession(client: SupabaseClient): Promise<AuthSpikeActionResult> {
  const { error } = await client.auth.signOut();

  if (error) {
    return {
      ok: false,
      gate: "AS-3",
      title: "Session sign-out failed",
      detail: error.message,
    };
  }

  return {
    ok: true,
    gate: "AS-3",
    title: "Session signed out",
  };
}

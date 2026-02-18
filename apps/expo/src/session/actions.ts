import type { Session, SupabaseClient } from "@supabase/supabase-js";
import type { AuthActionResult } from "../auth";

function summarizeSession(session: Session) {
  return {
    userId: session.user.id,
    provider: session.user.app_metadata.provider ?? null,
    expiresAt: session.expires_at ?? null,
    accessTokenHead: session.access_token.slice(0, 8),
  };
}

export async function refreshSessionState(client: SupabaseClient): Promise<AuthActionResult> {
  const { data, error } = await client.auth.refreshSession();

  if (error) {
    return {
      ok: false,
      gate: "AS-3",
      title: "Session refresh failed",
      detail: error.message,
    };
  }

  if (!data.session) {
    return {
      ok: false,
      gate: "AS-3",
      title: "Session refresh returned no session",
      detail: "Sign in again to continue.",
      payload: null,
    };
  }

  return {
    ok: true,
    gate: "AS-3",
    title: "Session refresh completed",
    payload: summarizeSession(data.session),
  };
}

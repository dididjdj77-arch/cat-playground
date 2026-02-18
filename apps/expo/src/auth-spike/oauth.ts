import * as AuthSession from "expo-auth-session";
import * as WebBrowser from "expo-web-browser";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AuthSpikeActionResult, AuthSpikeEnv, AuthSpikeProvider } from "./types";

WebBrowser.maybeCompleteAuthSession();

function parseCodeFromCallbackUrl(callbackUrl: string): string | null {
  try {
    const parsed = new URL(callbackUrl);
    const queryCode = parsed.searchParams.get("code");

    if (queryCode) {
      return queryCode;
    }

    const fragment = parsed.hash.startsWith("#") ? parsed.hash.slice(1) : parsed.hash;
    const fragmentParams = new URLSearchParams(fragment);
    const fragmentCode = fragmentParams.get("code");

    if (fragmentCode) {
      return fragmentCode;
    }

    return null;
  } catch (error) {
    console.warn("Auth spike callback parse failed", error);
    return null;
  }
}

export async function signInWithOAuth(
  client: SupabaseClient,
  env: AuthSpikeEnv,
  provider: AuthSpikeProvider,
): Promise<AuthSpikeActionResult> {
  const redirectTo = AuthSession.makeRedirectUri({
    scheme: env.redirectScheme,
    path: "auth/callback",
  });

  const { data, error } = await client.auth.signInWithOAuth({
    provider,
    options: {
      redirectTo,
      skipBrowserRedirect: true,
    },
  });

  if (error) {
    return {
      ok: false,
      gate: "AS-1",
      title: `${provider} login failed`,
      detail: error.message,
    };
  }

  if (!data?.url) {
    return {
      ok: false,
      gate: "AS-1",
      title: `${provider} login URL missing`,
      detail: "Supabase returned no OAuth URL.",
    };
  }

  const browserResult = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);

  if (browserResult.type !== "success") {
    return {
      ok: false,
      gate: "AS-2",
      title: `${provider} redirect was not completed`,
      detail: `Browser result: ${browserResult.type}`,
      payload: browserResult,
    };
  }

  const code = parseCodeFromCallbackUrl(browserResult.url);

  if (!code) {
    return {
      ok: false,
      gate: "AS-2",
      title: `${provider} callback missing code`,
      detail: browserResult.url,
    };
  }

  const exchangeResult = await client.auth.exchangeCodeForSession(code);

  if (exchangeResult.error) {
    return {
      ok: false,
      gate: "AS-2",
      title: `${provider} callback exchange failed`,
      detail: exchangeResult.error.message,
    };
  }

  return {
    ok: true,
    gate: "AS-2",
    title: `${provider} redirect round-trip completed`,
    detail: redirectTo,
    payload: {
      userId: exchangeResult.data.session?.user.id ?? null,
    },
  };
}

import type { AuthEnv, AuthEnvCheck } from "./types";

const ENV_KEYS = {
  supabaseUrl: "EXPO_PUBLIC_SUPABASE_URL",
  supabaseAnonKey: "EXPO_PUBLIC_SUPABASE_ANON_KEY",
  redirectScheme: "EXPO_PUBLIC_AUTH_REDIRECT_SCHEME",
} as const;

function readProcessEnv(): Record<string, string | undefined> {
  const maybeProcess = globalThis as { process?: { env?: Record<string, string | undefined> } };
  return maybeProcess.process?.env ?? {};
}

function readEnvValue(source: Record<string, string | undefined>, key: string): string {
  return source[key]?.trim() ?? "";
}

export function getAuthEnvCheck(): AuthEnvCheck {
  const source = readProcessEnv();
  const supabaseUrl = readEnvValue(source, ENV_KEYS.supabaseUrl);
  const supabaseAnonKey = readEnvValue(source, ENV_KEYS.supabaseAnonKey);
  const redirectScheme = readEnvValue(source, ENV_KEYS.redirectScheme);

  const missingKeys: string[] = [];

  if (!supabaseUrl) {
    missingKeys.push(ENV_KEYS.supabaseUrl);
  }

  if (!supabaseAnonKey) {
    missingKeys.push(ENV_KEYS.supabaseAnonKey);
  }

  if (!redirectScheme) {
    missingKeys.push(ENV_KEYS.redirectScheme);
  }

  if (missingKeys.length > 0) {
    return { env: null, missingKeys };
  }

  const env: AuthEnv = {
    supabaseUrl,
    supabaseAnonKey,
    redirectScheme,
  };

  return {
    env,
    missingKeys,
  };
}

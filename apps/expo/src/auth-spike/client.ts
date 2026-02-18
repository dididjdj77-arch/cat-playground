import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { AuthSpikeEnv } from "./types";

let cachedClient: SupabaseClient | null = null;
let cachedDsn = "";

function buildDsn(env: AuthSpikeEnv): string {
  return `${env.supabaseUrl}|${env.supabaseAnonKey}`;
}

export function getAuthSpikeClient(env: AuthSpikeEnv): SupabaseClient {
  const dsn = buildDsn(env);

  if (cachedClient && cachedDsn === dsn) {
    return cachedClient;
  }

  cachedDsn = dsn;
  cachedClient = createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
      flowType: "pkce",
    },
  });

  return cachedClient;
}

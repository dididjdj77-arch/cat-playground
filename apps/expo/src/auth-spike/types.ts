export type AuthSpikeGate = "AS-1" | "AS-2" | "AS-3" | "AS-4" | "AS-5";

export type AuthSpikeLevel = "info" | "success" | "error";

export type AuthSpikeProvider = "apple" | "kakao" | "google";

export interface AuthSpikeEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  redirectScheme: string;
}

export interface AuthSpikeEnvCheck {
  env: AuthSpikeEnv | null;
  missingKeys: string[];
}

export interface AuthSpikeActionResult {
  ok: boolean;
  gate: AuthSpikeGate;
  title: string;
  detail?: string;
  payload?: unknown;
}

export interface AuthSpikeEvent {
  id: string;
  gate: AuthSpikeGate;
  level: AuthSpikeLevel;
  title: string;
  detail?: string;
  createdAt: string;
}

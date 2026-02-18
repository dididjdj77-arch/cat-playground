export type AuthGate = "AS-1" | "AS-2" | "AS-3" | "AS-4" | "AS-5";

export type AuthLevel = "info" | "success" | "error";

export type AuthProvider = "apple" | "kakao" | "google";

export interface AuthEnv {
  supabaseUrl: string;
  supabaseAnonKey: string;
  redirectScheme: string;
}

export interface AuthEnvCheck {
  env: AuthEnv | null;
  missingKeys: string[];
}

export interface AuthActionResult {
  ok: boolean;
  gate: AuthGate;
  title: string;
  detail?: string;
  payload?: unknown;
}

export interface AuthEvent {
  id: string;
  gate: AuthGate;
  level: AuthLevel;
  title: string;
  detail?: string;
  createdAt: string;
}

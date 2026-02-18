export interface ProfileData {
  user_id: string;
  nickname: string | null;
  bio: string | null;
  avatar_key: string | null;
  terms_agreed_at: string | null;
  created_at: string;
}

export interface AgreeTermsResult {
  terms_agreed_at: string;
}

export interface SetNicknameResult {
  nickname: string;
}

export type OnboardingStep =
  | "loading"
  | "needs-login"
  | "needs-terms"
  | "needs-nickname"
  | "complete";

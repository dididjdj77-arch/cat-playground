import type { SupabaseClient } from "@supabase/supabase-js";
import { NotFoundError } from "@cat-playground/shared";
import { callSupabaseRpcWithAdapter } from "../transport/supabase-rpc-adapter";
import type { AgreeTermsResult, ProfileData, SetNicknameResult } from "./types";

export async function fetchMyProfile(
  client: SupabaseClient,
): Promise<{ profile: ProfileData } | null> {
  try {
    return await callSupabaseRpcWithAdapter<{ profile: ProfileData }>(
      client,
      "rpc_get_my_profile",
    );
  } catch (error) {
    if (error instanceof NotFoundError) {
      return null;
    }
    throw error;
  }
}

export async function agreeTerms(
  client: SupabaseClient,
): Promise<AgreeTermsResult> {
  return callSupabaseRpcWithAdapter<AgreeTermsResult>(
    client,
    "rpc_agree_terms",
  );
}

export async function setInitialNickname(
  client: SupabaseClient,
  nickname: string,
): Promise<SetNicknameResult> {
  return callSupabaseRpcWithAdapter<SetNicknameResult>(
    client,
    "rpc_set_initial_nickname",
    { p_nickname: nickname },
  );
}

import { useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, StyleSheet, Text, View } from "react-native";
import { Redirect } from "expo-router";
import { RpcBusinessError } from "@cat-playground/shared";
import { getAuthClient, getAuthEnvCheck, readSessionState } from "../src/auth";
import {
  agreeTerms,
  fetchMyProfile,
  NicknameScreen,
  setInitialNickname,
  TermsScreen,
  type OnboardingStep,
} from "../src/onboarding";

const SERVER_ERROR_MESSAGES: Record<string, string> = {
  nickname_taken: "이미 사용 중인 닉네임입니다.",
  nickname_length_out_of_range: "닉네임 길이가 범위를 벗어났습니다. (2~20자)",
  nickname_already_initialized: "닉네임이 이미 설정되었습니다.",
};

export default function Index() {
  const envCheck = useMemo(() => getAuthEnvCheck(), []);
  const [step, setStep] = useState<OnboardingStep>("loading");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [nicknameServerError, setNicknameServerError] = useState<string | null>(
    null,
  );
  const checkedRef = useRef(false);

  useEffect(() => {
    if (checkedRef.current || !envCheck.env) return;
    checkedRef.current = true;

    const check = async () => {
      const client = getAuthClient(envCheck.env!);

      const sessionResult = await readSessionState(client);
      if (!sessionResult.ok) {
        setStep("needs-login");
        return;
      }

      try {
        const data = await fetchMyProfile(client);
        if (!data) {
          setStep("needs-terms");
          return;
        }

        const { profile } = data;
        if (!profile.terms_agreed_at) {
          setStep("needs-terms");
        } else if (!profile.nickname) {
          setStep("needs-nickname");
        } else {
          setStep("complete");
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : "Profile check failed");
        setStep("needs-login");
      }
    };

    void check();
  }, [envCheck.env]);

  if (step === "needs-login" || !envCheck.env) {
    return <Redirect href="/(tabs)/settings" />;
  }

  if (step === "complete") {
    return <Redirect href="/(tabs)/house" />;
  }

  if (step === "loading") {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" />
        <Text style={styles.body}>프로필 확인 중...</Text>
        {error ? <Text style={styles.error}>{error}</Text> : null}
      </View>
    );
  }

  const client = getAuthClient(envCheck.env);

  if (step === "needs-terms") {
    const handleAgree = async () => {
      setBusy(true);
      setError(null);
      try {
        await agreeTerms(client);
        setStep("needs-nickname");
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "Terms agreement failed",
        );
      } finally {
        setBusy(false);
      }
    };

    return (
      <TermsScreen
        busy={busy}
        onAgree={() => {
          void handleAgree();
        }}
      />
    );
  }

  if (step === "needs-nickname") {
    const handleNickname = async (nickname: string) => {
      setBusy(true);
      setNicknameServerError(null);
      setError(null);
      try {
        await setInitialNickname(client, nickname);
        setStep("complete");
      } catch (err) {
        if (err instanceof RpcBusinessError) {
          const message = (err.body as Record<string, unknown>).message;
          const mapped =
            typeof message === "string"
              ? SERVER_ERROR_MESSAGES[message]
              : undefined;
          setNicknameServerError(mapped ?? err.message);
        } else {
          setError(
            err instanceof Error ? err.message : "Nickname setup failed",
          );
        }
      } finally {
        setBusy(false);
      }
    };

    return (
      <NicknameScreen
        busy={busy}
        serverError={nicknameServerError}
        onSubmit={(nickname) => {
          void handleNickname(nickname);
        }}
      />
    );
  }

  return null;
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    gap: 12,
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
  },
  error: {
    color: "#991b1b",
    fontWeight: "600",
  },
});

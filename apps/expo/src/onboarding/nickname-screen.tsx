import { useState } from "react";
import {
  Button,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

interface NicknameScreenProps {
  busy: boolean;
  serverError: string | null;
  onSubmit: (nickname: string) => void;
}

const NICKNAME_MIN = 2;
const NICKNAME_MAX = 20;

function validateNickname(value: string): string | null {
  const trimmed = value.trim();
  if (trimmed.length < NICKNAME_MIN) {
    return `닉네임은 최소 ${NICKNAME_MIN}자 이상이어야 합니다.`;
  }
  if (trimmed.length > NICKNAME_MAX) {
    return `닉네임은 최대 ${NICKNAME_MAX}자까지 가능합니다.`;
  }
  return null;
}

export function NicknameScreen({
  busy,
  serverError,
  onSubmit,
}: NicknameScreenProps) {
  const [nickname, setNickname] = useState("");
  const [localError, setLocalError] = useState<string | null>(null);

  const handleSubmit = () => {
    const error = validateNickname(nickname);
    if (error) {
      setLocalError(error);
      return;
    }
    setLocalError(null);
    onSubmit(nickname.trim());
  };

  const displayError = localError ?? serverError;

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>닉네임 설정</Text>
      <View style={styles.section}>
        <Text style={styles.body}>
          사용할 닉네임을 입력해주세요. ({NICKNAME_MIN}~{NICKNAME_MAX}자)
        </Text>
        <TextInput
          style={styles.input}
          value={nickname}
          onChangeText={(text) => {
            setNickname(text);
            setLocalError(null);
          }}
          placeholder="닉네임 입력"
          maxLength={NICKNAME_MAX}
          autoCapitalize="none"
          autoCorrect={false}
          editable={!busy}
        />
        {displayError ? (
          <Text style={styles.error}>{displayError}</Text>
        ) : null}
      </View>
      <View style={styles.buttonRow}>
        <Button
          title={busy ? "처리 중..." : "닉네임 설정"}
          onPress={handleSubmit}
          disabled={busy || nickname.trim().length === 0}
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingVertical: 24,
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
  },
  body: {
    fontSize: 14,
    lineHeight: 20,
  },
  section: {
    borderWidth: 1,
    borderRadius: 10,
    borderColor: "#d4d4d8",
    padding: 12,
    gap: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: "#d4d4d8",
    borderRadius: 8,
    padding: 10,
    fontSize: 16,
  },
  error: {
    color: "#991b1b",
    fontWeight: "600",
    fontSize: 13,
  },
  buttonRow: {
    marginTop: 4,
  },
});

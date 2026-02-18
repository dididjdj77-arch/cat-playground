import { Button, ScrollView, StyleSheet, Text, View } from "react-native";

interface TermsScreenProps {
  busy: boolean;
  onAgree: () => void;
}

export function TermsScreen({ busy, onAgree }: TermsScreenProps) {
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>서비스 이용약관 동의</Text>
      <View style={styles.section}>
        <Text style={styles.body}>
          cat-playground 서비스를 이용하려면 이용약관에 동의해야 합니다.
        </Text>
        <Text style={styles.body}>
          동의하면 게시물 작성, 댓글, 좋아요 등 쓰기 기능을 사용할 수 있습니다.
        </Text>
      </View>
      <View style={styles.buttonRow}>
        <Button
          title={busy ? "처리 중..." : "약관에 동의합니다"}
          onPress={onAgree}
          disabled={busy}
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
  buttonRow: {
    marginTop: 4,
  },
});

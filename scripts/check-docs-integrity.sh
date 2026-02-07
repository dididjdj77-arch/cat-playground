#!/usr/bin/env bash
set -euo pipefail

ERRORS=0
fail() { echo "FAIL: $1"; ERRORS=$((ERRORS + 1)); }

echo "=== 1. D-### 번호 중복 검사 ==="
DUPES=$(grep -oP '^## D-\d+' docs/DECISIONS.md | sort | uniq -d || true)
[ -n "$DUPES" ] && fail "중복 D-###: $DUPES" || echo "PASS"

echo "=== 2. O-### 번호 중복 검사 ==="
DUPES=$(grep -oP '^## O-\d+' docs/OPEN.md | sort | uniq -d || true)
[ -n "$DUPES" ] && fail "중복 O-###: $DUPES" || echo "PASS"

echo "=== 3. D-### 섹션별 Class 위치/형식 검사 ==="
# 규칙: 각 '## D-###' 헤더 바로 다음의 첫 non-empty 라인은
# 반드시 "- Class: (POLICY|GUARD|CONFIG|PROCESS)" 이어야 한다.
awk '
  BEGIN { inD=0; need=0; ok=1; }
  /^## D-[0-9]+/ { inD=1; need=1; next; }
  inD && need {
    if ($0 ~ /^[[:space:]]*$/) next;
    if ($0 ~ /^- Class:[[:space:]]*(POLICY|GUARD|CONFIG|PROCESS)[[:space:]]*$/) { need=0; next; }
    ok=0;
    exit 1;
  }
  END { if (!ok) exit 1; }
' docs/DECISIONS.md || fail "D-### 헤더 다음 첫 줄 Class 형식 위반 (예: - Class: POLICY)"
[ "$ERRORS" -eq 0 ] && echo "PASS (section-by-section)" || true

echo "=== 4. INDEX 경로 존재 확인 (- docs/ 항목 첫 토큰만) ==="
# 규칙: INDEX의 "- docs/..." 라인에서 첫 토큰(path)만 추출
# - docs/** 하위 경로 허용 (예: docs/ADR/xxx.md)
# - 반드시 .md로 끝나야 함
while read -r p; do
  if [[ "$p" == BAD_EXT* ]]; then
    fail "INDEX 경로는 .md로 끝나야 함: ${p#BAD_EXT }"
    continue
  fi
  [ ! -f "$p" ] && fail "INDEX 참조 파일 없음: $p"
done < <(
  awk '
    /^[[:space:]]*-[[:space:]]+docs\// {
      path=$2;
      if (path !~ /^docs\//) next;
      if (path !~ /\.md$/) { print "BAD_EXT " path; next; }
      print path;
    }
  ' docs/INDEX.md | sort -u
)
echo "PASS (or errors above)"

echo "=== 5. MOVED 링크 대상 파일 존재 ==="
while read -r p; do
  [ ! -f "$p" ] && fail "MOVED 대상 없음: $p"
done < <(
  grep -oP 'MOVED.*→\s*docs/[^\s#]+' docs/DECISIONS.md | grep -oP 'docs/[^\s#]+' | sort -u
)
echo "PASS (or errors above)"

echo "=== 결과: ERRORS=$ERRORS ==="
exit "$ERRORS"

# CONFIG-BASELINES — 운영 파라미터 기준값

> 운영 중 조정 가능한 수치/임계치의 단일 원문.
> 원칙(Why)은 DECISIONS.md, 저장소 정책은 D-056 참조.
> 수치 변경은 app_config DB 또는 운영 도구로 수행(코드 상수 금지).

---

## 1. Rate Limits (D-053)

### 일반 계정

| 액션 | 분당 | 일간 |
|------|------|------|
| posts | 2 | 20 |
| comments/replies | 10 | 200 |
| likes | 60 | 1500 |
| reports | 3 | 30 |

### 신규 계정 (가입 <= 24h)

| 액션 | 분당 | 일간 |
|------|------|------|
| posts | 1 | 5 |
| comments/replies | 5 | 50 |
| likes | 30 | 500 |
| reports | 2 | 10 |

---

## 2. Auto-Hide Threshold (D-054)

| 파라미터 | 값 |
|----------|----|
| 트리거 인원 (N) | 5명 (서로 다른 신고자) |
| 신고자 신뢰 조건 | 계정 생성 >= 7일 |
| 시간창 (window) | 24시간 (rolling) |
| 트리거 동작 | hidden_at = now() (삭제 아님) |

---

## 3. app_config key 매핑 (D-056)

| key | 대응 섹션 |
|-----|-----------|
| rate_limits | §1 일반 계정 |
| rate_limits_new_account | §1 신규 계정 |
| auto_hide | §2 |
| popular_feed | §4a |

---

## 4. pg_cron Baseline (D-069)

원칙:
- 모든 cron 표현식은 UTC 기준으로 기록/등록한다.
- SSOT로 고정하는 값은 "주기(cadence)"이며, minute offset은 default(조정 가능)로 둔다.
- 운영 커뮤니케이션에는 UTC 기준 표현을 우선 사용한다.

| 작업 | UTC 주기(SSOT) | minute offset(default, configurable) | 비고 |
|------|----------------|-------------------------------------|------|
| observation_groups idempotency cleanup | 매시간 1회 | 15 | D-041, sentinel swap update |
| observation_patch_dedup cleanup | 매시간 1회 | 20 | D-061, row cleanup |
| payload_version_events retention | 매일 1회 (02:00 UTC 기준) | 30 | D-045, 90일 초과 삭제 |
| engagement counter reconcile | 6시간마다 1회 | 0 | like/comment/reply 보정 |

---

## 4a. Popular Feed (D-076)

| 파라미터 | 값 |
|----------|----|
| like 가중치 | 1 |
| reply 가중치 | 2 |
| 윈도우 | 7일 |
| 정렬 | score DESC, created_at DESC |

app_config key: `popular_feed`

---

## 6. 변경 규칙

- 수치 변경: app_config(D-056)로 수행. 코드 상수 금지.
- "행동만 제한 / 읽기 제외" 원칙 변경: ADR 권장.
- 공개 범위 확대(anon 노출 등): ADR 필요.

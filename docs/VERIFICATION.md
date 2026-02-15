# VERIFICATION — CI/QA/런치 게이트(SSOT)

> 이 문서는 검증(게이트/시나리오/런치 체크)을 담은 단일 SSOT이다.
> 목적: 런치 사고(노출/정합/드리프트)를 **자동 게이트**로 막는다.

---

## 1) Public Surface Gate (필수 자동, Phase 2 시작 조건)

G-1 ~ G-4 전부 CI green이어야 Public RPC 또는 공개 웹 라우트 추가/확장 PR 머지 가능.

- [CI 필수][G-1] 차단 0-rows: block 관계에서 공개 피드/조회 RPC 결과가 대상 작성자 기준 0건이어야 한다.
- [CI 필수][G-2] DTO whitelist 0 누출: 공개 DTO에서 nickname 외 비허용 필드 누출이 0건이어야 한다.
- [CI 필수][G-3] 부모 가드 종속 404: 부모 공개 가드 실패 시 comments/replies 공개 조회는 0건이 아니라 404를 반환해야 한다.
- [CI 필수][G-4] 404 통일: 공개 표면의 조회 불가 상태는 모두 404로 통일한다. (D-050)

---

## 2) CI 필수 테스트 (최소 5종)

### T-1 차단 스냅샷 테스트 (0 rows)
- 대상 RPC(최소 2개): posts_feed, threads_feed
- 시나리오:
  - A가 공개 post/thread 작성
  - A가 B를 차단 -> B 조회 결과 0건
  - B가 A를 차단(상호) -> A 조회 결과 0건
- 추가: hidden_at / deleted_at도 0건

### T-2 payload_version normalize 스냅샷 테스트
- v1.0/v1.1(ACTIVE) 성공
- v0.9(DEPRECATED) 성공 또는 normalize_fail_count++
- v0.5(REJECT) -> rejected_version

### T-3 409 version_conflict 시나리오
- 동시 patch로 한쪽 성공(version++), 한쪽 409 version_conflict + current_version(+ snapshot 권장)

### T-4 공개 하우스 DTO 누출 방지 (D-055, D-037)
- 대상 RPC: rpc_get_public_house_slots_summary (+ by_nickname 있다면 포함)
- 검증: 허용 필드만 존재
  - 허용: slot_key, equipped_at, type, standard_name
  - 금지: inventory_item_id / inventory_items.id / raw_text / note / meta / cats.avatar_key / cats.avatar_url

### T-5 댓글 부모 post 가드 종속 404 (D-063)
- post unpublish/hidden/deleted/block/미존재 상태에서 comments 조회는 0건이 아니라 not_found(-> 404)

---

## 3) 드리프트 CI 차단(권장 4종)

### DCI-1 조인 규약 lint (profiles.id 금지)
- 금지: `profiles.id = <*_id>` 형태 조인(도메인 FK는 auth.users.id)
- 허용: `profiles.user_id = <*_id>`

### DCI-2 app_config whitelist 스냅샷
- `CONFIG-BASELINES.md` §3 key 목록과 `rpc_get_app_config` whitelist의 동일성 테스트

### DCI-3 payload rollup 스냅샷 (unknown_count 포함)
- payload_version_rollups 롤업 SQL이 unknown_count를 집계/업데이트하는지 검증

### DCI-4 Public DTO 금지 필드 테스트 확장
- 최소 포함: cats.avatar_key + cats.avatar_url + inventory IDs + raw_text/note/meta
- (추가 후보) reason_*, ended_at 등 owner-only 원장 필드

---

## 4) 수동 QA 시나리오(핵심)

### 다이어리/관찰
- 공통만 저장 / 공통+오버라이드 저장
- excluded 숨김/복구(삭제 없이 상태)
- 드래프트 복원(저장 없이 닫아도 복구)
- 과거 log_date 작성(허용), 미래 log_date 금지
- 멱등성 재시도(중복 생성 없음)
- 동시편집 충돌(409) + 데이터 찢김 없음

### 냥스타그램
- private 저장 -> 다이어리엔 보임, 피드/웹엔 안 보임
- public+미발행 -> 피드/웹 노출 X
- 발행/발행취소 -> 노출 O/X
- 댓글 수정 -> "수정됨" + 내부 감사로그 1개
- hide_from_profile -> 프로필 목록 제외(링크/피드 공개 유지)

### 채널
- /c 토픽 랜딩 + /c/{topic}/{thread} SSR/ISR 확인
- 피드 3종 + cursor pagination
- 답글 1-depth + pagination
- 검색 FTS + noindex
- 차단 후 상호 비노출(피드/검색/프로필/상세)

### 하우스
- 슬롯 바인딩: is_current=true만 장착 가능
- public+미발행 -> 타인 접근 404
- public+발행 -> 타인 접근 가능(guard 통과 시)
- 미인증(anon) -> 404 (auth-only, 존재 은닉)
- DTO 누출 방지(avatar_key/url 포함 금지)

### 운영(신고/자동숨김/차단)
- 신고 누적 -> D-054 기준으로 hidden_at 설정(삭제 X)
- 중복 신고 방지
- 차단 관계에서는 신고도 불가(guard_block)
- unhide 시 reports soft delete 및 감사로그(D-081)

### 썸네일 라이프사이클 (D-072)
- post publish -> 썸네일 생성
- post unpublish/hide/delete -> 썸네일 삭제(직링크 404)
- 재발행 -> 썸네일 재생성 + ISR revalidate

### terms_agreed_at 가드 (D-073)
- terms NULL + write RPC -> terms_not_agreed
- terms 설정 후 -> 정상
- read RPC -> terms 무관

---

## 5) 런치 체크(운영)
- Supabase PITR(Point-in-Time Recovery) 활성화 + 복구 시나리오 점검
- pg_cron job 등록/실행/실패 관측(runbook) 최소 보장
- Storage bucket/policy 적용 검증(원본 private, 썸네일 public, unpublish 시 삭제)

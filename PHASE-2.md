# PHASE-2.md
# Phase 2 — App (Expo) (번들 EP, 고위험만 분리)

## Scope Baseline (PR-1)
- 계획 경로 표준(placeholder 치환): `apps/expo/**`, `apps/web/**`, `packages/shared/**`, `tests/**`, `supabase/functions/**`, `supabase/**`
- 공통 Allowed paths(모든 EP): `docs/**`, `.github/**`, `scripts/**`, `supabase/**`
- Forbidden(모든 EP): Allowed에 적힌 것 외 변경 금지

## EP P2-00 — Transport Adapter(앱) 구현(선행 고정)
**Goal (1~3줄)**  
- DB RPC의 `error_code`를 앱에서 typed error/UX로 변환한다(D-071).  
- 404 통일(D-050)과 409(version_conflict) UX 매핑을 일관화한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `apps/expo/**`, `packages/shared/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- error_code 목록: `docs/API.md`  
- 외부 동작 변화: 앱에서 200+에러바디 노출 제거

**Validation placeholders**  
- `repo:test`(adapter 단위 테스트)  
- 최소 1개 실RPC 통합 호출(placeholder)

**Hardening hints**  
- [ ] adapter 위치(shared vs app) 결정  
- [ ] 에러→UX 매핑 표 1곳 SSOT화

**SSOT refs**  
- `docs/API.md`, `docs/DECISIONS.md`  
- D-050, D-071

**Prerequisites**: P1-04/05(공개 RPC 존재 시)

**OPEN**  
- 앱 네트워크 레이어 구조(레포 근거 필요).

---

## EP P2-01A — 로그인/로그아웃 + 세션 생성/저장/복구(실기기)
**Goal**  
- Apple/Kakao 로그인 성공 + 세션 저장/복구(앱 재시작 포함) 보장.  
- auth-only RPC 1회 호출로 세션 유효성 확인.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Providers: Apple/Kakao 필수(정책 SSOT), Google 옵션  
- auth-only RPC: `rpc_get_app_config`

**Validation placeholders**  
- Auth Spike Gate(AS-1~AS-5) 증거(최소 iOS+Android)  
- `repo:lint`, `repo:typecheck`

**Hardening hints**  
- [ ] 세션 저장 위치/암호화 저장소(플랫폼별) 근거 확보  
- [ ] 로그아웃 시 캐시/세션 정리 규약

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/DECISIONS.md`  
- D-066

**Prerequisites**: P2-00, P0.9-02

**OPEN**: none

---

## EP P2-01B — 세션 만료/갱신/오프라인/취소 UX
(고위험 낮음, 01A와 번들 가능)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 만료/갱신/취소/네트워크 오류를 “일관된 UX + 복구 가능” 상태로 만든다.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Adapter 오류 매핑(terms_not_agreed/not_found/version_conflict 등)

**Validation placeholders**  
- 수동 시나리오: 토큰 만료/강제 로그아웃/오프라인/취소  
- 가능하면 상태 머신 최소 1개 자동 테스트

**Hardening hints**  
- [ ] 재시도/타임아웃 정책 표준화  
- [ ] 로그 이벤트 키 고정(있다면)

**SSOT refs**  
- `docs/API.md`, `docs/DECISIONS.md`  
- D-071, D-050

**Prerequisites**: P2-01A

**OPEN**: none

---

## EP P2-01C — 온보딩: 약관 동의 → 초기 닉네임 설정 → write unlock
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- pre-terms 예외 2개만으로 부트스트랩을 완성한다(D-097).  
- 미동의 write는 403(terms_not_agreed) UX로 처리한다.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- RPC(확정): `agree_terms`, `set_initial_nickname`  
- 오류: `terms_not_agreed`

**Validation placeholders**  
- Negative: terms NULL 상태 write 시도 → terms_not_agreed 처리  
- Positive: 온보딩 완료 후 write 가능

**Hardening hints**  
- [ ] 온보딩 상태 판정(프로필 읽기 경로) SSOT 근거 필요  
- [ ] 예외 목록 확대 금지(D-097) UI에서도 명시

**SSOT refs**  
- `docs/DECISIONS.md`, `docs/API.md`  
- D-073, D-097

**Prerequisites**: P2-01A, P2-00

**OPEN**  
- 프로필 조회 경로(SSOT 근거 필요).

---

## EP P2-02 — 하우스 플로우 번들
(슬롯 편집 + 인벤 관리 + 공개/발행 설정 + 공개 하우스 보기)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 하우스 탭에서 슬롯 배치/비우기/인벤 연결 UX 완성.  
- 공개 하우스 보기는 auth-only 정책을 UI에서 강제.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Routes: `/house`, `/inventory`, `/u/{nickname}/house`  
- Entry: 작성자(닉네임/아바타) 탭 액션 메뉴 → 하우스 보기 (D-099)
- RPC: `rpc_set_house_slot`, `rpc_clear_house_slot`, `rpc_get_public_house_slots_summary`  
- publish/unpublish RPC: **TBD**

**Validation placeholders**  
- 수동: is_current=false 장착 시도 → 실패 UX  
- 수동: anon에서 공개 하우스 진입 → 404/차단 UX

**Hardening hints**  
- [ ] slot_key 목록(D-006)과 UI 상수 동기화  
- [ ] 공개 하우스 DTO 누출 금지(D-037) UI에서도 기본 아바타 처리

**SSOT refs**  
- `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`, `docs/AUTHZ-MODEL.md`  
- D-006, D-035, D-037, D-074, D-099

**Prerequisites**: P1-03

**OPEN**  
- house publish/unpublish RPC 함수명/계약(SSOT 보강 필요).

---

## EP P2-03 — 다이어리 플로우 번들(관찰 upsert/patch + 409 처리 + 드래프트 복원)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- log_date 관찰 저장/수정/충돌 처리 완결.  
- 로컬 드래프트(D-004) + CTA(D-082) 포함.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- RPC: `rpc_upsert_observation_group_with_items`, `rpc_patch_observation_items`  
- error_code: `version_conflict`, `invalid_payload_version`, `rejected_version`

**Validation placeholders**  
- 수동: 409 UX, 미래 날짜 방어(D-010), 드래프트 복원

**Hardening hints**  
- [ ] idempotency_key 생성/보관 전략(재시도 동일 키 유지)  
- [ ] 충돌 시 최신 스냅샷 표시 여부(서버 제공 시에만)

**SSOT refs**  
- `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`, `docs/API.md`  
- D-003, D-004, D-010, D-082

**Prerequisites**: P1-02, P2-00

**OPEN**  
- 관찰 “조회 RPC” 필요 여부(SSOT 보강 가능).

---

## EP P2-04 — 냥스타 플로우 번들(피드/상세/작성/발행/댓글/좋아요/업로드)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 공개/비공개/발행 모델(D-007)을 UI에서 혼란 없이 구현한다.  
- 업로드는 원본 private + meta(images) 저장(D-067/D-088).

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Public RPC: `rpc_get_public_posts_feed`, `rpc_get_public_post_comments`  
- Like RPC: `rpc_toggle_like`  
- write RPC: **TBD**  
- Storage: `assets`(원본 private), 썸네일은 Phase 3(`assets-public`)

**Validation placeholders**  
- 수동: private/public+미발행/발행 전이 UX, 댓글 수정 표기(D-009), hide_from_profile(D-020)

**Hardening hints**  
- [ ] 업로드 포맷/크기 제한(D-067) 사전 검증  
- [ ] 에러 매핑: not_found/terms_not_agreed/invalid_request

**SSOT refs**  
- `docs/DECISIONS.md`, `docs/AUTHZ-MODEL.md`, `docs/DATA-MODEL.md`  
- D-007, D-009, D-020, D-067, D-088, D-090

**Prerequisites**: P1-04, P2-00

**OPEN**  
- post detail 조회 RPC 함수명/shape SSOT 보강 필요.

---

## EP P2-05 — 채널 플로우 번들
(토픽/팔로우/피드3종/스레드/답글/검색)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 채널 사용 흐름(탐색→팔로우→작성/상호작용→검색) 완결.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- RPC: `rpc_get_public_threads_feed` + 나머지 **TBD**  
- UX: 작성자(닉네임/아바타) 탭 액션 메뉴(D-017, D-099)

**Validation placeholders**  
- 수동: 피드3종 + cursor, 검색(FTS), 답글 1-depth

**Hardening hints**  
- [ ] cursor/limit 표준(D-077)  
- [ ] 검색 noindex는 웹에서만(Phase 3)

**SSOT refs**  
- `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`  
- D-013, D-017, D-077, D-099

**Prerequisites**: P1-05, P2-00

**OPEN**  
- 채널 RPC 이름이 SSOT(API)에 누락 → Phase 1에서 선행 보강 필요.

---

## EP P2-06 — 설정 + 운영 UI 번들(프로필/신고/차단/알림)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- v1 설정 화면/운영 기능/알림 inbox 완결.  
- 닉네임 변경은 v1 미지원(D-051)임을 UX에서 명확히 한다.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Route: `/notifications`  
- RPC: `rpc_report_content` + block RPC(**TBD**) + notifications 조회/읽음 RPC(**TBD**) + profile update RPC(**TBD**)

**Validation placeholders**  
- 수동: 중복 신고(duplicate_report), 차단 후 상호작용 불가, 알림 읽음 처리

**Hardening hints**  
- [ ] 알림 type-target 매핑(D-070) UI 반영  
- [ ] 프로필 SEO는 웹 noindex(D-078) — 앱은 안내만

**SSOT refs**  
- `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`, `docs/playbooks/moderation.md`  
- D-051, D-070, D-014

**Prerequisites**: P1-06, P2-00

**OPEN**  
- notifications 읽기/읽음 처리 RPC 함수명/계약 SSOT 필요.

---

## Phase 2 요약
- EP 개수: 7 (+ 2-01A/B/C 포함 시 9)  
- 단독 권장(선행/횡단 의존): P2-00, P2-01C  
- 단독 권장(범위 큰 UI 번들): P2-03, P2-04, P2-06  
- 이유(선행/횡단 의존): P2-00은 전 도메인 에러 매핑의 공통 선행 어댑터이고, P2-01C는 write unlock 가드/온보딩 경계를 가로지른다.  
- 이유(범위 큰 UI 번들): P2-03/04/06은 각 도메인의 핵심 화면/상호작용을 묶어 변경량과 회귀 면적이 크다.  
- 번들 후보(가벼운 것끼리): P2-01A+P2-01B, P2-02+P2-05

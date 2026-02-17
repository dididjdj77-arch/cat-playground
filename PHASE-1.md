# PHASE-1.md
# Phase 1 — Core RPC(도메인별) + 회귀 테스트

## Scope Baseline (PR-1)
- 계획 경로 표준(placeholder 치환): `apps/expo/**`, `apps/web/**`, `packages/shared/**`, `tests/**`, `supabase/functions/**`, `supabase/**`
- 공통 Allowed paths(모든 EP): `docs/**`, `.github/**`, `scripts/**`, `supabase/**`
- Forbidden(모든 EP): Allowed에 적힌 것 외 변경 금지

## EP P1-01 — 인벤토리(owner) RPC: switch/discontinue (+ 불변식 회귀)
**Goal (1~3줄)**  
- 인벤 원장 모델(D-057/D-075)을 DB write RPC로 고정한다.  
- “current 0..1”/reason_code 불변/삭제 없음(D-040)을 회귀로 막는다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- RPC: `rpc_inventory_switch`, `rpc_inventory_discontinue`  
- Table: `inventory_items`

**Validation placeholders**  
- `repo:lint`, `repo:typecheck`, `repo:test`  
- Smoke(placeholder): switch/discontinue 1회씩  
- Negative(placeholder): current 2개 생성 불가 / terms 미동의 write 거부

**Hardening hints**  
- [ ] write guard 순서(D-096) 준수 체크  
- [ ] 롤백: RPC drop/revert + 권한 revoke  
- [ ] 오류 매핑: `invalid_request`, `invalid_inventory_item` 등

**SSOT refs**  
- `docs/DATA-MODEL.md`, `docs/API.md`, `docs/playbooks/rpc-owner.md`  
- D-040, D-057, D-075, D-095, D-096

**Prerequisites**: P0-03A~D, P0-04

**OPEN**  
- correction RPC(v1 UX 미확정) 포함 여부(기본: 예비 등록만).

---

## EP P1-02 — 관찰(owner, 고위험) RPC: upsert + patch + payload_version 검증/이벤트
**Goal (1~3줄)**  
- `rpc_upsert_observation_group_with_items` / `rpc_patch_observation_items` 계약을 SSOT대로 구현한다.  
- 멱등/409/version_conflict/overwrite(D-084)로 데이터 찢김을 차단한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- RPC: `rpc_upsert_observation_group_with_items`, `rpc_patch_observation_items`  
- Function: `validate_payload_version`  
- Tables: `observation_groups`, `observations`, `observation_inventory_refs`, `observation_patch_dedup`, `payload_*`

**Validation placeholders**  
- VERIFICATION: T-2, T-3  
- Smoke(placeholder): idempotency replay + patch replay  
- Negative(placeholder): 미래 log_date 거부(D-010), invalid/rejected payload_version

**Hardening hints**  
- [ ] replay는 “최초 성공과 동일 shape” 반환(D-061)  
- [ ] 충돌 응답 `current_version`(+ snapshot 옵션)  
- [ ] TTL cleanup/센티넬 swap은 Phase 3 잡과 결합

**SSOT refs**  
- `docs/API.md`, `docs/DATA-MODEL.md`, `docs/VERIFICATION.md`, `docs/playbooks/rpc-owner.md`, `docs/playbooks/payload-version-kpi.md`  
- D-010, D-041, D-061, D-084, D-089

**Prerequisites**: P0-03A~D

**OPEN**  
- conflict 응답에 snapshot 포함 여부(비용/크기 고려).

---

## EP P1-03 — 하우스 RPC: 슬롯 bind/clear + house_profile lazy create + 공개 슬롯 요약(auth-only)
**Goal (1~3줄)**  
- slot_key 중심(D-074)으로 하우스 API 표면을 고정한다.  
- 공개 하우스는 auth-only + 404 은닉 + DTO whitelist(D-055)를 회귀로 강제한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- RPC: `rpc_set_house_slot`, `rpc_clear_house_slot`, `rpc_get_public_house_slots_summary`  
- Tables: `house_profiles`, `house_slots`, `inventory_items`, `catalog_items`

**Validation placeholders**  
- VERIFICATION: T-4  
- `ci:public-gate`(관련 변경 포함 시)  
- Negative(placeholder): non-current 장착 거부, anon DB 호출 거부(외부는 404)

**Hardening hints**  
- [ ] publish/unpublish RPC 이름/시그니처는 SSOT 근거 생기기 전엔 TBD 유지  
- [ ] 404 통일(D-050) 적용 누락 방지

**SSOT refs**  
- `docs/API.md`, `docs/AUTHZ-MODEL.md`, `docs/DATA-MODEL.md`, `docs/VERIFICATION.md`, `docs/playbooks/rpc-public.md`  
- D-035, D-037, D-043, D-050, D-055, D-074

**Prerequisites**: P0-03B~D

**OPEN**  
- 공개 하우스 by_nickname 변형 RPC 필요 여부/이름(SSOT 보강 필요).

---

## EP P1-04 — 냥스타 RPC + Public Surface Gate 활성화(머지 조건 전환)
**Goal (1~3줄)**  
- posts CRUD + publish/unpublish + comments + like toggle + 공개 조회 RPC를 완성한다.  
- `ci:public-gate`를 실제 머지 조건으로 전환한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`, `.github/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Public RPC: `rpc_get_public_posts_feed`, `rpc_get_public_post_comments`  
- Like RPC: `rpc_toggle_like`  
- Write RPC 이름: **TBD(SSOT 보강 필요)**  
- Tables: `posts`, `comments`, `likes`, `notifications`(옵션)

**Validation placeholders**  
- `ci:public-gate` (G-1~G-4)  
- VERIFICATION: T-1, T-5  
- Negative: hidden/deleted/unpublished/private 상태 404 통일

**Hardening hints**  
- [ ] publish/unpublish 전이(D-007) + private+published CHECK 동시 방어  
- [ ] 롤백: public RPC revoke + 함수 revert + 게이트 revert(필요 시)

**SSOT refs**  
- `docs/API.md`, `docs/AUTHZ-MODEL.md`, `docs/VERIFICATION.md`, `docs/playbooks/rpc-public.md`  
- D-007, D-050, D-063, D-090

**Prerequisites**: P0-04, P0-03B~D

**OPEN**  
- posts CRUD/publish/unpublish/comment CRUD RPC의 정확 함수명(SSOT/API에 명시 필요).

---

## EP P1-05 — 채널 RPC: 토픽/스레드/답글/팔로우/검색(FTS) + 피드 3종
**Goal (1~3줄)**  
- 채널 v1(D-013) 기능을 RPC 계약으로 완성한다.  
- cursor pagination(D-077), popular 공식(D-076)을 회귀로 고정한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Public read RPC(확정): `rpc_get_public_threads_feed`  
- 나머지 RPC 이름: **TBD(SSOT 보강 필요)**  
- Tables: `topics`, `topic_follows`, `threads`, `replies`, `likes`

**Validation placeholders**  
- `ci:public-gate`  
- Drift(가능하면): DCI-1, FTS 스냅샷

**Hardening hints**  
- [ ] popular 피드 공식은 app_config `popular_feed`로부터 읽기(D-076)  
- [ ] noindex는 웹에서만(Phase 3 정책), RPC에는 비노출 원칙만

**SSOT refs**  
- `docs/DATA-MODEL.md`, `docs/AUTHZ-MODEL.md`, `docs/API.md`, `docs/VERIFICATION.md`  
- D-013, D-076, D-077, D-092

**Prerequisites**: P1-04

**OPEN**  
- search/feed 3종 포함 RPC들의 정확 함수명/파라미터 SSOT 보강 필요.

---

## EP P1-06 — 운영 RPC: 신고/차단/자동숨김/감사로그/알림 생성(트랜잭션 내부)
**Goal (1~3줄)**  
- 운영 최소장치(D-014)를 DB write 경로로 완성한다.  
- 임계값/레이트리밋은 app_config로만 읽고 코드 상수화를 금지한다(D-056).

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `supabase/**`, `tests/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- RPC(확정): `rpc_report_content` (+ 내부 `check_auto_hide`)  
- Block RPC 이름: **TBD**  
- Tables: `reports`, `blocks`, `moderation_actions`, `app_config`, `notifications`(옵션)

**Validation placeholders**  
- moderation 플레이북 smoke/negative 케이스  
- Drift: DCI-2(app_config whitelist 스냅샷)

**Hardening hints**  
- [ ] duplicate_report(409) / invalid_target_type(400) / blocked 불가 정책 준수  
- [ ] unhide(D-081) 포함 여부 결정(미포함 시 후속 EP로 고정)  
- [ ] 롤백: RPC/권한 revert + seed revert

**SSOT refs**  
- `docs/playbooks/moderation.md`, `docs/CONFIG-BASELINES.md`, `docs/API.md`  
- D-014, D-019, D-052, D-053, D-054, D-056, D-081, D-091

**Prerequisites**: P0-03C, P0-03D, P0-04

**OPEN**  
- block create/delete RPC 명칭/시그니처 SSOT 보강 필요.

---

## Phase 1 요약
- EP 개수: 6  
- 단독 권장(고위험): P1-01~P1-06 전부  
- 번들 후보(가벼운 것끼리): 없음(권장하지 않음)

# PHASE-0.md
# Phase 0 — Infra + Spine (DB 스파인 정체성 유지)

## EP P0-01 — 모노레포 스파인 + 공용 경계 + 표준 커맨드 스켈레톤
**Goal (1~3줄)**  
- 이후 모든 EP를 “기계적 반복”으로 만들기 위한 레포 구조/경계/스크립트 이름을 고정한다.  
- 앱(Expo)/웹(Next.js)/공용(shared)/Supabase 영역을 분리하고, 라우팅 스텁만 만든다(기능 구현 금지).

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed paths (대략/TBD 허용):  
  - `docs/**` (필요 시 스켈레톤 문서만)  
  - `TBD: <expo-app-root>/**` (탭 4개 라우팅 스텁만)  
  - `TBD: <next-web-root>/**` (SEO 라우트 스텁만)  
  - `TBD: <shared-root>/**` (DTO whitelist/에러코드 enum 타입 스텁)  
  - `TBD: .github/**` (CI가 표준 스크립트만 호출하도록 스텁)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no**  
- Schema change? **no**  
- RLS/SECURITY DEFINER? **no**  
- Write? **no**

**Interfaces**  
- Route/IA 스텁(동작 변화 최소):  
  - 앱 탭: 하우스/다이어리/소셜/설정  
  - 웹 라우트(스텁): `/c*`, `/p*`, `/search`  
- Repo Canonical Scripts “이름” 고정(구현은 스켈레톤): `repo:lint`, `repo:typecheck`, `repo:test`, `db:reset`, `db:smoke`, `ci:verify`, `ci:public-gate`, `ci:drift`

**Validation placeholders**  
- `repo:lint`, `repo:typecheck`  
- `repo:test`  
- `ci:verify`

**Hardening hints (빈칸 목록)**  
- [ ] 실제 패키지 매니저/스크립트 러너(pnpm/bun/make 등) 확정 및 스크립트 매핑  
- [ ] 앱/웹/공용 루트 경로 확정(레포 실경로 근거 추가)  
- [ ] “공개 응답=whitelist” 타입 강제 위치 결정  
- [ ] 최소 smoke 테스트(스텁 라우트 렌더 1개)  
- [ ] 롤백: 스켈레톤 파일 제거/리버트 경로 명시

**SSOT refs**  
- `roadmap.md`, `docs/PROCESS.md`, `docs/ROUTES-AND-IA.md`, `docs/engineering-philosophy-v1.md`  
- D-001, D-002, D-049

**Prerequisites**: none

**OPEN**  
- 레포 실제 디렉토리명(Expo/Next/shared/supabase) 확정 필요.

---

## EP P0-02 — Supabase 로컬/CI 루프 고정(db:reset → migrate → seed → db:smoke)
**Goal (1~3줄)**  
- 로컬과 CI의 DB 루프를 동일 이름/동일 흐름으로 고정한다.  
- “CI green = 컨펌 근거”가 되도록 재현성을 확보한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed paths:  
  - `TBD: <supabase-root>/**`  
  - `TBD: CI config (.github/** 또는 동등)`  
  - `docs/VERIFICATION.md` (필요 시 “스크립트 이름”만 확인/정정)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no**  
- Schema change? **no**  
- RLS/SECURITY DEFINER? **no**  
- Write? **no**

**Interfaces**  
- 표준 스크립트: `db:reset`, `db:smoke`, `ci:verify`  
- 외부 동작 변화: 로컬에서 돌린 것 = CI에서 동일하게 돈다

**Validation placeholders**  
- `db:reset`  
- `db:smoke`  
- `ci:verify`

**Hardening hints**  
- [ ] db:smoke의 “최소 smoke SQL” 정의  
- [ ] CI에서 DB 의존 테스트의 실행 순서 고정  
- [ ] 실패 시 진단 로그 표준  
- [ ] 롤백: CI 변경 revert + 로컬 스크립트 revert

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/PROCESS.md`, `roadmap.md`

**Prerequisites**: P0-01

**OPEN**  
- Supabase 로컬 실행 방식(CLI/도커)과 실제 경로 확인 필요.

---

## EP P0-03A — DB 마이그레이션 번들 A(코어 스키마 1)
(스키마/인덱스/제약, RLS/SECURITY DEFINER 분리)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- `docs/DATA-MODEL.md` 기반으로 코어 테이블/제약/핵심 인덱스를 먼저 확정한다.  
- 대형 마이그 파일 1개 몰아넣기 금지(3~4 EP 분할의 1/4).

**Scope**  
- Allowed: `TBD: <supabase-root>/migrations/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **no** / Write? **yes**

**Interfaces**  
- Tables: `profiles`, `cats`, `catalog_*`, `inventory_items`, `observation_groups`, `observations`, `observation_inventory_refs`, `observation_patch_dedup`

**Validation placeholders**  
- `db:reset` + `db:smoke`  
- Negative(placeholder): CHECK/UNIQUE 위반 insert 실패

**Hardening hints**  
- [ ] 마이그 파일 분할(번호/파일명 TBD) + 롤백 경로  
- [ ] D-087 길이 CHECK / D-075 reason_code 불변 반영 점검  
- [ ] observation UNIQUE(owner_id, log_date) + idempotency 부분 유니크 반영 점검

**SSOT refs**  
- `docs/DATA-MODEL.md`, `docs/DECISIONS.md`, `docs/playbooks/migrations.md`  
- D-041, D-060, D-061, D-075, D-087

**Prerequisites**: P0-02

**OPEN**  
- 마이그레이션 파일 실제 번호/파일명은 레포 생성 후 확정.

---

## EP P0-03B — DB 마이그레이션 번들 B(코어 스키마 2: 커뮤니티/운영)
(채널/냥스타/하우스/likes/moderation/notifications 중심)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- 커뮤니티/공개 도메인 테이블을 SSOT대로 추가한다.  
- FTS/카운터/수정 이력/차단/신고/알림의 최소 저장소를 확정한다.

**Scope**  
- Allowed: `TBD: <supabase-root>/migrations/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **no** / Write? **yes**

**Interfaces**  
- Tables: `posts`, `comments`, `comment_revisions`, `topics`, `threads`, `replies`, `reply_revisions`, `likes`, `house_profiles`, `house_slots`, `blocks`, `reports`, `moderation_actions`, `notifications`  
- FTS: `threads.fts_vector` + GIN (D-092)

**Validation placeholders**  
- `db:reset` + `db:smoke`  
- Negative(placeholder): 길이 CHECK/enum CHECK 위반

**Hardening hints**  
- [ ] private+published 금지 CHECK 반영(D-007/D-035)  
- [ ] 신고 reason_code CHECK(D-091) 반영  
- [ ] 롤백: FK 의존 고려 drop 순서

**SSOT refs**  
- `docs/DATA-MODEL.md`, `docs/DECISIONS.md`, `docs/playbooks/migrations.md`  
- D-007, D-009, D-035, D-091, D-092

**Prerequisites**: P0-03A

**OPEN**  
- 카운터 보정 방식은 Phase 3 잡과 결합.

---

## EP P0-03C — Ops/app_config + payload KPI + auth bootstrap + storage baseline
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- 운영 파라미터(app_config)와 payload KPI 저장소를 만들어 운영 가능 시스템으로 만든다.  
- Auth 부트스트랩(profiles upsert)과 Storage 공개 경계를 v1 기준선으로 깔아 둔다.

**Scope**  
- Allowed: `TBD: <supabase-root>/migrations/**`, `docs/CONFIG-BASELINES.md`(링크 보강만)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Tables: `app_config`, `ops_metrics`, `payload_versions`, `payload_version_events`, `payload_version_rollups`  
- RPC: `rpc_get_app_config(p_keys text[]) returns jsonb`  
- Storage buckets: `assets`(private), `assets-public`(public)  
- Auth bootstrap 오브젝트 이름: **TBD(레포 근거 필요)**

**Validation placeholders**  
- `db:reset` + `db:smoke`  
- Smoke: `rpc_get_app_config(['rate_limits','auto_hide'])` 반환  
- Negative: anon 호출 거부(권한/EXECUTE/내부 auth check)

**Hardening hints**  
- [ ] seed는 `CONFIG-BASELINES.md` 값과 1:1 정합  
- [ ] Storage 정책을 SQL로 관리할지 운영 설정으로 둘지 결정  
- [ ] auth trigger 실패 흡수/로깅

**SSOT refs**  
- `docs/CONFIG-BASELINES.md`, `docs/playbooks/ops-app-config.md`, `docs/playbooks/payload-version-kpi.md`, `docs/DATA-MODEL.md`  
- D-056, D-066, D-067, D-089

**Prerequisites**: P0-03B

**OPEN**  
- auth bootstrap의 정확한 DB 오브젝트 이름/경로.

---

## EP P0-03D — DB 하드닝: Guard 함수 + RLS 베이스라인 + GRANT/REVOKE
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- `AUTHZ-MODEL.md` §0 정책식을 코드 경로에서 강제할 수 있도록 guard 함수/RLS 베이스를 깐다.  
- “원본 테이블 direct SELECT 금지 + SECURITY DEFINER RPC 단일 경로(D-029)”를 구조로 고정한다.

**Scope**  
- Allowed: `TBD: <supabase-root>/migrations/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Guard 함수: `guard_soft_state()`, `guard_block()`, `guard_visibility_published()`, `guard_terms_agreed()` 등(SSOT 명시된 이름만)  
- 권한: anon/authenticated에 대한 direct SELECT 차단 + EXECUTE 최소화

**Validation placeholders**  
- `db:reset` + `db:smoke`  
- (가능하면) `ci:drift` 기반 테스트는 P0-04에서 확장

**Hardening hints**  
- [ ] SECURITY DEFINER `search_path` 고정(ADR-005)  
- [ ] guard 함수가 플래너를 방해하지 않는 형태로 유지(ADR-005)  
- [ ] 롤백 SQL/리버트 경로

**SSOT refs**  
- `docs/AUTHZ-MODEL.md`, `docs/API.md`, `docs/playbooks/rls-and-guards.md`, `docs/playbooks/rpc-public.md`, `docs/playbooks/rpc-owner.md`  
- D-029, D-050, D-073, D-096  
- ADR-005

**Prerequisites**: P0-03C

**OPEN**  
- RLS 적용 범위를 v1에서 어디까지 강제할지(Owner 테이블 중심 vs 전체).

---

## EP P0-04 — 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- Phase 1부터 “테스트+게이트가 머지 조건”이 되도록 기반 테스트/시드/게이트 골격을 만든다.  
- Public Surface Gate(G-1~G-4)는 이후 실제 머지 조건으로 전환 가능해야 한다.

**Scope**  
- Allowed: `TBD: <test-root>/**`, `TBD: <seed-fixtures>/**`, `TBD: CI config`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Gates: G-1~G-4, DCI-1~DCI-4  
- Fixture: User A/B/C/D, block 관계, 공개 post/thread 샘플, topic 2개, 운영 파라미터 seed

**Validation placeholders**  
- `repo:test`, `ci:verify`  
- (Phase 1 첫 공개 RPC 전까지) `ci:public-gate`는 skip 가능하되 스켈레톤 존재는 필수

**Hardening hints**  
- [ ] fixture 생성 방식(DB seed vs 테스트 런타임) 선택  
- [ ] DTO 금지 필드 목록을 테스트로 강제(DCI-4)  
- [ ] 롤백: 테스트/시드 revert

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/PROCESS.md`, `docs/CONFIG-BASELINES.md`, `docs/API.md`  
- D-050, D-056

**Prerequisites**: P0-03D

**OPEN**  
- 테스트 프레임워크/루트 경로(레포 근거 필요).

---

## EP P0-05 — DB 타입 코드젠 + 공용 경계(whitelist 타입 동시 강제)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- DB 스키마→타입 코드젠을 자동화하고 CI에 포함한다.  
- “공개 응답=whitelist”를 타입+테스트로 강제할 공용 경계를 만든다.

**Scope**  
- Allowed: `TBD: <shared-root>/**`, `TBD: scripts/**`, `TBD: CI config`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- codegen 스크립트(이름 TBD) → `ci:verify` 포함  
- whitelist 타입 → Public Gate/DTO 누출 테스트와 결합

**Validation placeholders**  
- `repo:typecheck`, `repo:test`, `ci:verify`

**Hardening hints**  
- [ ] 코드젠 도구/명령/출력경로 확정  
- [ ] generated 파일 커밋 정책 결정

**SSOT refs**  
- `docs/API.md`, `docs/PROCESS.md`, `roadmap.md`  
- D-071, D-029

**Prerequisites**: P0-01, P0-03A~D

**OPEN**  
- 코드젠 도구/명령/출력경로(레포 근거 필요).

---

## EP P0-06 — Environment Matrix 스켈레톤(값은 0.9에서 채움)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- dev/staging/prod 환경 “필드”를 고정해 재현 가능한 운영 기반을 만든다(값은 TBD).

**Scope**  
- Allowed: `docs/playbooks/ops-app-config.md`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 문서 섹션: Environment Matrix 필드(roadmap §1.4)

**Validation placeholders**  
- 문서 링크/형식 체크(있다면)

**Hardening hints**  
- [ ] 비밀값은 “값”이 아니라 “저장 위치/권한경계”만 기록  
- [ ] OAuth redirect URI / Expo scheme / Next domain 등 누락 필드 체크리스트화

**SSOT refs**  
- `docs/playbooks/ops-app-config.md`, `roadmap.md`, `docs/PROCESS.md`

**Prerequisites**: none

**OPEN**: none

---

## Phase 0 요약
- EP 개수: 9  
- 단독 권장(고위험): P0-03A, P0-03B, P0-03C, P0-03D  
- 번들 후보(가벼운 것끼리): P0-01+P0-02, P0-05+P0-06

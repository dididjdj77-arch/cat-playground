# Execution Packet — P0-01: 모노레포 스파인 + 공용 경계 + 표준 커맨드 스켈레톤

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-01`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-01`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **FAST**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: none

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/VERIFICATION.md`
- `docs/ROUTES-AND-IA.md`
- `docs/engineering-philosophy-v1.md`
- `docs/DECISIONS.md` (관련 Decision: D-001, D-002, D-049)

## Baseline spec (from Phase file)
```markdown
## EP P0-01 — 모노레포 스파인 + 공용 경계 + 표준 커맨드 스켈레톤
**Goal (1~3줄)**  
- 이후 모든 EP를 “기계적 반복”으로 만들기 위한 레포 구조/경계/스크립트 이름을 고정한다.  
- 앱(Expo)/웹(Next.js)/공용(shared)/Supabase 영역을 분리하고, 라우팅 스텁만 만든다(기능 구현 금지).

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed paths:  
  - `docs/**` (필요 시 스켈레톤 문서만)  
  - `apps/expo/**` (탭 4개 라우팅 스텁만)  
  - `apps/web/**` (SEO 라우트 스텁만)  
  - `packages/shared/**` (DTO whitelist/에러코드 enum 타입 스텁)  
  - `.github/**` (CI가 표준 스크립트만 호출하도록 스텁)  
  - `scripts/**` (공통 Allowed paths)  
  - `supabase/**` (공통 Allowed paths)  
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
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 3) RPC/Contract 구현
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

### 4) App(Expo) 구현
- [ ] ROUTES-AND-IA 기준으로 화면/탭/라우트 스택을 구성(스펙 외 UI 확장 금지).
- [ ] Transport Adapter(P2-00) 경유로 RPC 호출/에러 매핑을 일원화.
- [ ] `error_code` 기반 UX 분기: `not_found`=404 UX, `terms_not_agreed`, `version_conflict` 등은 표준 UX로 처리.
- [ ] write 흐름은 **idempotency_key 재사용**(재시도 동일 키) 원칙을 지켜 중복 생성 위험을 줄인다.
- [ ] 수동 시나리오(Phase 파일 Validation placeholders)를 실제 기기(iOS/Android) 기준으로 재현/증거화.

### 5) Web(SEO/SSR/ISR) 구현
- [ ] Next 라우팅 구조(App Router/Pages Router)는 레포 근거로 확정. 불명확하면 OPEN으로 남기고 보수적으로 구현.
- [ ] Transport Adapter(P3-00): `error_code` → HTTP status 변환을 SSR/ISR 경로에서 강제.
- [ ] SEO 규칙: index/noindex, robots/sitemap/metadata, 404 통일(D-050)을 준수.
- [ ] ISR/revalidate는 allowlist + secret header로만 트리거. secret 노출(로그/쿼리/바디) 금지.
- [ ] 보안 네거티브 테스트(T-6)가 머지 조건이 되도록 자동화.

## Validation (must run)
- Risk level: **FAST**
- Setup:
  - `db:reset` (로컬) + 필요 시 CI 동일 루프 확인
  - `repo:lint` / `repo:typecheck` (가능한 경우)
- Smoke tests (at least 1):
  - Phase 파일의 Validation placeholders 중 1개 이상을 **실제 실행**하고 출력/스크린샷을 남긴다.
- Negative tests:
  - 최소 1개는 조건/설명으로라도 명시(가능하면 재현/증거).

### Phase placeholder excerpt
```text
- `repo:lint`, `repo:typecheck`  
- `repo:test`  
- `ci:verify`
```

## DoD
### Functional DoD
```text
- 이후 모든 EP를 “기계적 반복”으로 만들기 위한 레포 구조/경계/스크립트 이름을 고정한다.  
- 앱(Expo)/웹(Next.js)/공용(shared)/Supabase 영역을 분리하고, 라우팅 스텁만 만든다(기능 구현 금지).
```
### Safety DoD
- [ ] Forbidden path 변경 없음(범위 슬립 0).
- [ ] 부분쓰기/권한누출/공개 DTO 누출/404 통일 위반 없음.
### Evidence required in PR
- [ ] 실행한 커맨드/SQL + 출력(또는 스크린샷) 첨부.
- [ ] 변경 파일 목록(자동/수동) 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] DB: 롤백 SQL 또는 revert 커밋 절차.
- [ ] 앱/웹: 기능 플래그/리버트 커밋 절차.

## OPEN (from Phase)
- 레포 실제 디렉토리명(Expo/Next/shared/supabase) 확정 필요.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-01: 모노레포 스파인 + 공용 경계 + 표준 커맨드 스켈레톤

## Summary
- What changed:
  - ...
- Why:
  - ...

## Validation evidence
- Commands/SQL executed:
  - `<command>`  
    ```text
    <output>
    ```
- Smoke results:
  - ...
- Negative results:
  - ...

## Files changed
- ...

## Risks / Notes
- ...

## OPEN / Follow-ups
- ...
```

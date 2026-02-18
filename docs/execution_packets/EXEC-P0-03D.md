# Execution Packet — P0-03D: DB 하드닝: Guard 함수 + RLS 베이스라인 + GRANT/REVOKE

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-03D`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-03D`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **yes**
  - RLS·SECURITY DEFINER: **yes**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/migrations.md`
  - `docs/playbooks/rls-and-guards.md`
  - `docs/playbooks/rpc-owner.md`
  - `docs/playbooks/rpc-public.md`
- Prerequisites: P0-03C

## Hardening safety rules (MUST)
1) Reality check: 참조(스크립트/경로/심볼)는 레포에 실제로 존재하는 것만 사용한다. 신규 DB 오브젝트(함수/정책/권한)는 SSOT에 명시된 이름만 생성한다. SSOT에 없으면 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/DATA-MODEL.md`
- `docs/AUTHZ-MODEL.md`
- `docs/VERIFICATION.md`
- `docs/playbooks/rls-and-guards.md`
- `docs/playbooks/rpc-owner.md`
- `docs/playbooks/rpc-public.md`
- `docs/DECISIONS.md` (관련 Decision: D-029, D-050, D-061, D-073, D-094, D-096)
- `docs/AUTHZ-MODEL.md` (§0 정책식 원문 — guard 함수 설계 필수 참조)
- ADR refs: ADR-005

## Baseline spec (from Phase file)
```markdown
## EP P0-03D — DB 하드닝: Guard 함수 + RLS 베이스라인 + GRANT/REVOKE
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 참조(스크립트/경로/심볼)는 레포에 실제로 존재하는 것만 사용한다. 신규 DB 오브젝트(함수/정책/권한)는 SSOT에 명시된 이름만 생성한다. SSOT에 없으면 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- `AUTHZ-MODEL.md` §0 정책식을 코드 경로에서 강제할 수 있도록 guard 함수/RLS 베이스를 깐다.  
- “원본 테이블 direct SELECT 금지 + SECURITY DEFINER RPC 단일 경로(D-029)”를 구조로 고정한다.

**Scope**  
- Allowed: `supabase/migrations/**`  
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
- D-029, D-050, D-061, D-073, D-096
- ADR-005

**Prerequisites**: P0-03C

**OPEN**  
- RLS 적용 범위를 v1에서 어디까지 강제할지(Owner 테이블 중심 vs 전체).

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 1) DB/Migration 구현
- [ ] 새 migration 파일(들) 생성: 파일 번호/이름은 레포 규칙을 따르고, **큰 파일 1개에 몰아넣지 않는다**.
- [ ] `begin; ... commit;` + `lock_timeout/statement_timeout` 설정(플레이북 migrations 준수).
- [ ] 제약/인덱스/FTS(해당 시) 추가는 DATA-MODEL/DECISIONS 근거와 1:1로 대응되게 작성.
- [ ] RLS 정책 변경은 **스키마 변경과 분리**(Phase 0에서는 P0-03D).
- [ ] 롤백 경로 명시: `_down.sql` 또는 revert 커밋 전략 중 하나를 확정.

### 2) Security/RLS/권한
- [ ] `SECURITY DEFINER` 함수는 `set search_path` 고정(ADR-005) + `auth.uid()` 기반 viewer 도출.
- [ ] guard 함수 적용 순서/정책을 준수(플레이북 rls-and-guards, rpc-owner/public).
- [ ] 원본 테이블 direct SELECT 노출 금지(특히 anon). 필요한 경우 EXECUTE 최소 권한만 부여.
- [ ] anon/authenticated에서의 접근(성공/거부/404 통일)을 **smoke + negative**로 확인.

### 3) Guard 함수 정의 + GRANT/REVOKE
- [ ] SSOT(`AUTHZ-MODEL.md` §0)에 명시된 guard 함수만 생성: `guard_soft_state()`, `guard_block()`, `guard_visibility_published()`, `guard_terms_agreed()` 등.
- [ ] guard 함수 호출 순서를 D-096에 맞게 고정.
- [ ] `guard_terms_agreed()` 적용(D-073).
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 가드/누출 방지를 회귀로 고정.

### Non-goals (이 EP에서 하지 않는 것)
- 도메인 write RPC 구현(트랜잭션 경계, idempotency, replay shape 등) — 별도 EP에서 수행.
- public RPC endpoint 추가 — 이 EP는 guard 함수/RLS/GRANT/REVOKE 인프라만 다룬다.
- AUTHZ-MODEL §0에 없는 guard 함수 신규 생성.

## Validation (must run)
- Risk level: **PRECISE**
- Setup:
  - `db:reset` (로컬) + 필요 시 CI 동일 루프 확인
  - `repo:lint` / `repo:typecheck` (가능한 경우)
- Smoke tests (at least 1):
  - Phase 파일의 Validation placeholders 중 1개 이상을 **실제 실행**하고 출력/스크린샷을 남긴다.
- Negative tests:
  - Phase 파일의 negative placeholder(또는 VERIFICATION 항목)를 **정확히 1개 이상** 재현하고 기대 결과를 증거로 남긴다.

### Phase placeholder excerpt
```text
- `db:reset` + `db:smoke`  
- (가능하면) `ci:drift` 기반 테스트는 P0-04에서 확장
```

## DoD
### Functional DoD
```text
- `AUTHZ-MODEL.md` §0 정책식을 코드 경로에서 강제할 수 있도록 guard 함수/RLS 베이스를 깐다.  
- “원본 테이블 direct SELECT 금지 + SECURITY DEFINER RPC 단일 경로(D-029)”를 구조로 고정한다.
```
### Safety DoD
- [ ] Forbidden path 변경 없음(범위 슬립 0).
- [ ] 부분쓰기/권한누출/공개 DTO 누출/404 통일 위반 없음.
- [ ] 마이그레이션 롤백 경로(다운 SQL 또는 revert 커밋) 명시.
### Evidence required in PR
- [ ] 실행한 커맨드/SQL + 출력(또는 스크린샷) 첨부.
- [ ] 변경 파일 목록(자동/수동) 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] DB: 롤백 SQL 또는 revert 커밋 절차.
- [ ] 앱/웹: 기능 플래그/리버트 커밋 절차.

## OPEN (from Phase)
- RLS 적용 범위를 v1에서 어디까지 강제할지(Owner 테이블 중심 vs 전체).

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-03D: DB 하드닝: Guard 함수 + RLS 베이스라인 + GRANT/REVOKE

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

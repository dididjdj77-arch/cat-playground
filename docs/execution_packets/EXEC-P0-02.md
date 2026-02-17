# Execution Packet — P0-02: Supabase 로컬/CI 루프 고정(db:reset → migrate → seed → db:smoke)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-02`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-02`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **FAST**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: P0-01

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/VERIFICATION.md`

## Baseline spec (from Phase file)
```markdown
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
  - `supabase/**`  
  - `.github/**`  
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
- `db:reset`  
- `db:smoke`  
- `ci:verify`
```

## DoD
### Functional DoD
```text
- 로컬과 CI의 DB 루프를 동일 이름/동일 흐름으로 고정한다.  
- “CI green = 컨펌 근거”가 되도록 재현성을 확보한다.
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
- Supabase 로컬 실행 방식(CLI/도커)과 실제 경로 확인 필요.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-02: Supabase 로컬/CI 루프 고정(db:reset → migrate → seed → db:smoke)

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

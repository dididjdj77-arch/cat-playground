# Execution Packet — P0-05: DB 타입 코드젠 + 공용 경계(whitelist 타입 동시 강제)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-05`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-05`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **FAST**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: P0-01, P0-03A~D

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/DECISIONS.md` (관련 Decision: D-029, D-071)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- - codegen 스크립트(이름 TBD) → `ci:verify` 포함

## Baseline spec (from Phase file)
```markdown
## EP P0-05 — DB 타입 코드젠 + 공용 경계(whitelist 타입 동시 강제)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- DB 스키마→타입 코드젠을 자동화하고 CI에 포함한다.  
- “공개 응답=whitelist”를 타입+테스트로 강제할 공용 경계를 만든다.

**Scope**  
- Allowed: `packages/shared/**`, `scripts/**`, `.github/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**
- codegen 스크립트(이름 TBD) → `ci:verify` 포함
- whitelist 타입 → Public Gate/DTO 누출 테스트와 결합
- 기존 패턴: `packages/shared/src/public-dto.ts` (`PUBLIC_HOUSE_SLOT_WHITELIST`)

**Validation placeholders**  
- `repo:typecheck`, `repo:test`, `ci:verify`

**Hardening hints**
- [ ] 코드젠 도구/명령/출력경로 확정 (Blocker)
- [ ] generated 파일 커밋 정책 확정 (OPEN 참조)

**SSOT refs**  
- `docs/API.md`, `docs/PROCESS.md`, `roadmap.md`  
- D-071, D-029

**Prerequisites**: P0-01, P0-03A~D

**OPEN**  
- 코드젠 도구/명령/출력경로(레포 근거 필요).

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### Non-goals (이 EP에서 하지 않는 것)
- DB 함수/RLS/GRANT/REVOKE/마이그레이션 변경 — Scope(`packages/shared/**`, `scripts/**`, `.github/**`)에 해당하지 않음.
- docs/** 문서 변경 — Scope 외. 필요 시 별도 EP.
- 도메인 RPC 구현.

### 5) 코드젠 파이프라인 구축
- [ ] DB 스키마→TS 타입 코드젠 스크립트를 `scripts/` 하위에 생성(도구/명령/출력경로는 Blocker 해소 후 확정).
- [ ] 생성된 타입이 `packages/shared/` 하위에 출력되도록 경로 설정.
- [ ] `ci:verify`에 코드젠 drift 체크를 포함(생성물과 DB 스키마 불일치 시 실패).

### 6) Whitelist 타입 경계 강화
- [ ] 기존 패턴 참조: `packages/shared/src/public-dto.ts` (`PUBLIC_HOUSE_SLOT_WHITELIST` 등).
- [ ] 공개 응답 whitelist를 타입으로 강제하는 공용 경계를 `packages/shared/` 내에 확장.
- [ ] Public Gate/DTO 누출 테스트와 결합 가능한 형태로 export.

## Validation (must run)
- Risk level: **FAST**
- Setup:
  - `repo:lint` / `repo:typecheck` (가능한 경우)
- Smoke tests (at least 1):
  - Phase 파일의 Validation placeholders 중 1개 이상을 **실제 실행**하고 출력/스크린샷을 남긴다.
- Negative tests:
  - 최소 1개는 조건/설명으로라도 명시(가능하면 재현/증거).

### Phase placeholder excerpt
```text
- `repo:typecheck`, `repo:test`, `ci:verify`
```

## DoD
### Functional DoD
```text
- DB 스키마→타입 코드젠을 자동화하고 CI에 포함한다.  
- “공개 응답=whitelist”를 타입+테스트로 강제할 공용 경계를 만든다.
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
- 코드젠 도구/명령/출력경로(레포 근거 필요).
- generated 파일 커밋 정책(커밋 vs CI-only 생성) — CI 파이프라인 전체에 영향하므로 Blocker 해소 시 함께 확정 필요.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-05: DB 타입 코드젠 + 공용 경계(whitelist 타입 동시 강제)

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

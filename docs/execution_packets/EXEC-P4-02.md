# Execution Packet — P4-02: 실기기 + 웹 최종 확인(워크스루/SEO 크롤/OG/썸네일 404)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-4.md` / EP `P4-02`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P4-02`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **FAST**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: P4-01

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-4.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/DECISIONS.md`
- `docs/VERIFICATION.md`
- `docs/ROUTES-AND-IA.md`
- `docs/DECISIONS.md` (관련 Decision: D-098)

## Baseline spec (from Phase file)
```markdown
## EP P4-02 — 실기기 + 웹 최종 확인(워크스루/SEO 크롤/OG/썸네일 404)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 앱 핵심 플로우 워크스루 + 웹 SEO 크롤 시뮬레이션.  
- 썸네일 직링크 404 등 런치 사고 포인트 재확인.

**Scope**  
- Allowed: runbook/체크리스트 문서(필요 시)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 앱: 하우스/다이어리/소셜/설정 + `/notifications`  
- 웹: `/c*`, `/p*`, `/search` noindex, OG/robots/sitemap

**Validation placeholders**  
- `docs/VERIFICATION.md` 수동 QA 시나리오 체크

**Hardening hints**  
- [ ] “웹은 anon-only” 커뮤니케이션 문구 포함(D-098)  
- [ ] 발견 결함은 원인별 분리 EP

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`  
- D-098

**Prerequisites**: P4-01

**OPEN**: none

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

### 1) 문서/운영 작업
- [ ] 문서 변경은 SSOT 원칙(이유는 DECISIONS/ADR, 수치는 CONFIG-BASELINES)에 맞게 최소 변경.
- [ ] 비밀값은 쓰지 않고, **설정 위치/절차**만 기록.
- [ ] 체크리스트는 실행 가능 형태(누가/언제/어디서/어떤 근거로)로 작성.

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
- `docs/VERIFICATION.md` 수동 QA 시나리오 체크
```

## DoD
### Functional DoD
```text
- 앱 핵심 플로우 워크스루 + 웹 SEO 크롤 시뮬레이션.  
- 썸네일 직링크 404 등 런치 사고 포인트 재확인.
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
none

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P4-02: 실기기 + 웹 최종 확인(워크스루/SEO 크롤/OG/썸네일 404)

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

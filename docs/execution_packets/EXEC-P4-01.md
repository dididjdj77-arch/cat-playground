# Execution Packet — P4-01: 자동 QA(회귀 풀스위트 + 누락 보강 + CI 최종 green)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-4.md` / EP `P4-01`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P4-01`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: Phase 1~3 완료

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-4.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/VERIFICATION.md`

## Baseline spec (from Phase file)
```markdown
## EP P4-01 — 자동 QA(회귀 풀스위트 + 누락 보강 + CI 최종 green)
**Goal (1~3줄)**  
- 회귀 테스트 풀스위트를 돌리고 누락을 보강한다.  
- Public Surface Gate(G-1~G-4)와 revalidate 네거티브(T-6)를 최종 green으로 만든다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `tests/**`, `.github/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- `ci:verify`, `ci:public-gate`, `ci:drift`

**Validation placeholders**  
- CI 최종 green + evidence 첨부(로그/출력)

**Hardening hints**  
- [ ] flaky 제거/격리  
- [ ] 실패 원인 분류 템플릿

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/PROCESS.md`, `roadmap.md`

**Prerequisites**: Phase 1~3 완료

**OPEN**: none

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### Non-goals (이 EP에서 하지 않는 것)
- DB schema/RPC/RLS/GRANT/REVOKE 변경 — Impact flags 전부 no. 이 EP는 테스트/CI 회귀 보강만 다룬다.
- 문서/SSOT 변경 — `docs/**`는 Scope 외.

### 6) 테스트/게이트
- [ ] tests/fixtures 기반으로 재현 가능한 데이터 세팅(User A/B/C, block 관계, 샘플 콘텐츠).
- [ ] VERIFICATION의 해당 테스트(T-1~T-6, DCI-1~4)를 스냅샷/네거티브까지 포함해 구현.
- [ ] CI 스크립트(`ci:verify`, `ci:public-gate`, `ci:drift`)에서 실행되도록 연결.

## Validation (must run)
- Risk level: **PRECISE**
- Setup:
  - `repo:lint` / `repo:typecheck` (가능한 경우)
- Smoke tests (at least 1):
  - Phase 파일의 Validation placeholders 중 1개 이상을 **실제 실행**하고 출력/스크린샷을 남긴다.
- Negative tests:
  - Phase 파일의 negative placeholder(또는 VERIFICATION 항목)를 **정확히 1개 이상** 재현하고 기대 결과를 증거로 남긴다.

### Phase placeholder excerpt
```text
- CI 최종 green + evidence 첨부(로그/출력)
```

## DoD
### Functional DoD
```text
- 회귀 테스트 풀스위트를 돌리고 누락을 보강한다.  
- Public Surface Gate(G-1~G-4)와 revalidate 네거티브(T-6)를 최종 green으로 만든다.
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
# Result Packet — P4-01: 자동 QA(회귀 풀스위트 + 누락 보강 + CI 최종 green)

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

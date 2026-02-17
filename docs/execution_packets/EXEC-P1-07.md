# Execution Packet — P1-07: 프로필/온보딩 Write RPC + 알림 RPC

> Issued: 2026-02-18 (Asia/Seoul)
> Phase ref: `PHASE-1.md` / EP `P1-07`
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P1-07`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **yes**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/rls-and-guards.md`
- Prerequisites: P0-03C, P0-03D

## Hardening safety rules (MUST)
1) Reality check: 레포에 존재하는 경로/규칙을 따른다. 신규 DB 오브젝트는 SSOT(API/DATA-MODEL/DECISIONS/Playbook)에 명시된 이름만 생성한다. SSOT에 없는 신규 이름/표면은 만들지 말고 OPEN.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-1.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/DATA-MODEL.md`
- `docs/AUTHZ-MODEL.md`
- `docs/VERIFICATION.md`
- `docs/DECISIONS.md` (관련 Decision: D-051, D-070, D-073, D-096, D-097)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- (없음 — API.md §7-6, §7-7에 전부 확정됨)

## Targets (이 EP에서 만지는 주요 표면)
- RPC:
  - `rpc_agree_terms`
  - `rpc_set_initial_nickname`
  - `rpc_update_profile`
  - `rpc_get_notifications`
  - `rpc_mark_notification_read`
  - `rpc_mark_all_notifications_read`
- Tables (참고):
  - `profiles`
  - `notifications`

## Baseline spec (from Phase file)
```markdown
## EP P1-07 — 프로필/온보딩 Write RPC + 알림 RPC
**Hardening safety rules (EP마다 반드시 포함)**
1) Reality check: 레포에 존재하는 경로/규칙을 따른다. 신규 DB 오브젝트는 SSOT에 명시된 이름만 생성한다.
2) Conservative risk: 애매하면 yes로 보수적으로 판정.
3) Evidence-only: 확정값은 SSOT 근거가 있을 때만 적는다.

**Goal (1~3줄)**
- 프로필/온보딩 Write RPC(§7-6)와 알림 Read/Write RPC(§7-7)를 DB-side로 완성한다.
- pre-terms 예외(rpc_agree_terms, rpc_set_initial_nickname)는 guard_terms_agreed 스킵을 명시한다(D-097).

**Scope**
- Allowed: `supabase/**`, `tests/**`
- Forbidden: Allowed에 적힌 것 외 변경 금지
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**
- 프로필/온보딩 RPC(확정, API.md §7-6): `rpc_agree_terms`, `rpc_set_initial_nickname`, `rpc_update_profile`
- 알림 RPC(확정, API.md §7-7): `rpc_get_notifications`, `rpc_mark_notification_read`, `rpc_mark_all_notifications_read`
- Tables: `profiles`, `notifications`

**Validation placeholders**
- Smoke: rpc_agree_terms → terms_agreed_at 설정 확인
- Smoke: rpc_get_notifications → 알림 목록 반환
- Negative: terms 미동의 상태에서 rpc_update_profile → terms_not_agreed 거부

**Hardening hints**
- [ ] rpc_agree_terms, rpc_set_initial_nickname은 guard_terms_agreed 스킵(D-097 pre-terms 예외)
- [ ] rpc_update_profile은 guard 호출 순서(D-096) 준수: terms → block → soft_state → domain
- [ ] 닉네임 변경은 v1 미지원(D-051) — rpc_update_profile에서 nickname 변경 차단 또는 무시

**SSOT refs**
- `docs/API.md`, `docs/AUTHZ-MODEL.md`, `docs/DATA-MODEL.md`, `docs/VERIFICATION.md`
- D-051, D-070, D-073, D-096, D-097

**Prerequisites**: P0-03C, P0-03D

**OPEN**: none

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.

### 2) Security/RLS/권한
- [ ] `SECURITY DEFINER` 함수는 `set search_path` 고정(ADR-005) + `auth.uid()` 기반 viewer 도출.
- [ ] guard 함수 적용 순서/정책을 준수(플레이북 rls-and-guards).
- [ ] pre-terms 예외 2개(`rpc_agree_terms`, `rpc_set_initial_nickname`)는 `guard_terms_agreed` 스킵을 코드에 명시.
- [ ] anon/authenticated에서의 접근(성공/거부)을 **smoke + negative**로 확인.

### 3) RPC/Contract 구현
- [ ] write RPC는 트랜잭션 경계 명시(부분쓰기 방지).
- [ ] 비즈니스 에러는 JSON return(`error_code`, 추가 필드)로 전달(raise exception은 hard fail만).
- [ ] guard 호출 순서(D-096) 고정: terms → block → soft_state → domain.
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

### 6) 테스트/게이트
- [ ] tests/fixtures 기반으로 재현 가능한 데이터 세팅.
- [ ] VERIFICATION의 해당 테스트를 스냅샷/네거티브까지 포함해 구현.
- [ ] CI 스크립트(`ci:verify`, `ci:drift`)에서 실행되도록 연결.

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
- Smoke: rpc_agree_terms → terms_agreed_at 설정 확인
- Smoke: rpc_get_notifications → 알림 목록 반환
- Negative: terms 미동의 상태에서 rpc_update_profile → terms_not_agreed 거부
```

## DoD
### Functional DoD
```text
- 프로필/온보딩 Write RPC(§7-6)와 알림 RPC(§7-7)를 DB-side로 완성한다.
- pre-terms 예외는 guard 스킵을 명시적으로 처리한다(D-097).
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

## OPEN (from Phase)
- none

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P1-07: 프로필/온보딩 Write RPC + 알림 RPC

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

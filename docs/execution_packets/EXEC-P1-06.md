# Execution Packet — P1-06: 운영 RPC: 신고/차단/자동숨김/감사로그/알림 생성(트랜잭션 내부)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-1.md` / EP `P1-06`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P1-06`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **yes**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/moderation.md`
  - `docs/playbooks/rls-and-guards.md`
- Prerequisites: P0-03C, P0-03D, P0-04

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-1.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/AUTHZ-MODEL.md`
- `docs/CONFIG-BASELINES.md`
- `docs/playbooks/moderation.md`
- `docs/DECISIONS.md` (관련 Decision: D-014, D-019, D-052, D-053, D-054, D-056, D-081, D-091)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- (해소됨) Block RPC 이름 → API.md §7-3 확정: `rpc_block_user(p_blocked_user_id uuid)`, `rpc_unblock_user(p_blocked_user_id uuid)`

## Targets (이 EP에서 만지는 주요 표면)
- RPC:
  - `rpc_report_content`
  - `rpc_block_user`
  - `rpc_unblock_user`
  - `rpc_unhide_content` (admin-only, D-081)
  - `check_auto_hide` (internal, REVOKE ALL — 외부 EXECUTE 금지)
- Tables / Entities (참고):
  - `app_config`
  - `blocks`
  - `moderation_actions`
  - `notifications`
  - `reports`

## Baseline spec (from Phase file)
```markdown
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
- Block RPC(확정, API.md §7-3): `rpc_block_user`, `rpc_unblock_user`
- Tables: `reports`, `blocks`, `moderation_actions`, `app_config`

**Validation placeholders**  
- moderation 플레이북 smoke/negative 케이스  
- Drift: DCI-2(app_config whitelist 스냅샷)

**Hardening hints**  
- [ ] duplicate_report(409) / invalid_target_type(400) / blocked 불가 정책 준수
- [x] ~~unhide(D-081) 포함 여부 결정~~ → **포함 확정**. `rpc_unhide_content`를 이 EP에서 구현한다(D-081: 기존 reports soft delete + 감사로그)
- [ ] `check_auto_hide`는 internal helper — **REVOKE ALL** 필수(guard 함수 패턴 준수, 외부 EXECUTE 금지)
- [ ] 롤백: RPC/권한 revert + seed revert

**SSOT refs**  
- `docs/playbooks/moderation.md`, `docs/CONFIG-BASELINES.md`, `docs/API.md`  
- D-014, D-019, D-052, D-053, D-054, D-056, D-081, D-091

**Prerequisites**: P0-03C, P0-03D, P0-04

**OPEN**
- (해소됨) block RPC 명칭 → API.md §7-3 확정.

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 2) Security/RLS/권한
- [ ] `SECURITY DEFINER` 함수는 `set search_path` 고정(ADR-005) + `auth.uid()` 기반 viewer 도출.
- [ ] guard 함수 적용 순서/정책을 준수(플레이북 rls-and-guards, rpc-owner/public).
- [ ] 원본 테이블 direct SELECT 노출 금지(특히 anon). 필요한 경우 EXECUTE 최소 권한만 부여.
- [ ] anon/authenticated에서의 접근(성공/거부/404 통일)을 **smoke + negative**로 확인.

### 3) RPC/Contract 구현
- [ ] write RPC는 트랜잭션 경계 명시(부분쓰기 방지) + idempotency/expected_version(해당 시) 구현.
- [ ] 비즈니스 에러는 JSON return(`error_code`, 추가 필드)로 전달(raise exception은 hard fail만).
- [ ] `guard_terms_agreed()` 적용(D-073) + guard 호출 순서(D-096) 고정.
- [ ] replay는 최초 성공과 동일 shape를 반환(status-only 금지, D-061).
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

### 6) 테스트/게이트
- [ ] tests/fixtures 기반으로 재현 가능한 데이터 세팅(User A/B/C, block 관계, 샘플 콘텐츠).
- [ ] VERIFICATION의 해당 테스트(T-1~T-6, DCI-1~4)를 스냅샷/네거티브까지 포함해 구현.
- [ ] CI 스크립트(`ci:verify`, `ci:public-gate`, `ci:drift`)에서 실행되도록 연결.

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
- moderation 플레이북 smoke/negative 케이스  
- Drift: DCI-2(app_config whitelist 스냅샷)
```

## DoD
### Functional DoD
```text
- 운영 최소장치(D-014)를 DB write 경로로 완성한다.  
- 임계값/레이트리밋은 app_config로만 읽고 코드 상수화를 금지한다(D-056).
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
- (해소됨) block create/delete RPC 명칭/시그니처는 API.md §7-3에 확정됨.
- ~~unhide(D-081) 포함 여부 결정(미포함 시 후속 EP로 고정).~~
  - **해소**: P1-06에 포함. auto_hide 구현 시 unhide 없으면 운영에서 복구 수단이 없으므로 같은 EP에서 처리한다.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P1-06: 운영 RPC: 신고/차단/자동숨김/감사로그/알림 생성(트랜잭션 내부)

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

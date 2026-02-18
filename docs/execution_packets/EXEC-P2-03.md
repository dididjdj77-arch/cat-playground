# Execution Packet — P2-03: 다이어리 플로우 번들(관찰 upsert/patch + 409 처리 + 드래프트 복원)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-2.md` / EP `P2-03`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P2-03`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: P1-02, P2-00

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-2.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/DECISIONS.md`
- `docs/API.md`
- `docs/ROUTES-AND-IA.md`
- `docs/DECISIONS.md` (관련 Decision: D-003, D-004, D-010, D-082)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- (해소됨) 관찰 조회 RPC → API.md §8 확정: `rpc_get_my_observation_group(p_log_date date) returns jsonb`

## Targets (이 EP에서 만지는 주요 표면)
- RPC:
  - `rpc_patch_observation_items`
  - `rpc_upsert_observation_group_with_items`
  - `rpc_get_my_observation_group`
- Tables / Entities (참고):
  - `invalid_payload_version`
  - `rejected_version`
  - `version_conflict`

## Baseline spec (from Phase file)
```markdown
## EP P2-03 — 다이어리 플로우 번들(관찰 upsert/patch + 409 처리 + 드래프트 복원)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- log_date 관찰 저장/수정/충돌 처리 완결.  
- 로컬 드래프트(D-004) + CTA(D-082) 포함.

**Scope**  
- Allowed: `apps/expo/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- RPC: `rpc_upsert_observation_group_with_items`, `rpc_patch_observation_items`, `rpc_get_my_observation_group`  
- error_code: `version_conflict`, `invalid_payload_version`, `rejected_version`

**Validation placeholders**  
- 수동: 409 UX, 미래 날짜 방어(D-010), 드래프트 복원

**Hardening hints**
- [ ] idempotency_key 생성/보관 전략(재시도 동일 키 유지)
- [ ] 충돌 시 최신 스냅샷 표시 여부(서버 제공 시에만)
- [ ] `inventory_refs` 전송 규칙 (D-064):
  - 기본: `inventory_refs = null` (기존 refs 유지 — 대부분의 저장 케이스)
  - 클리어 UX가 있는 경우에만: `inventory_refs = {}` (기존 refs 전부 삭제)
  - 부분 업데이트: 특정 타입 키만 포함 시 해당 타입만 upsert, 나머지 유지

**SSOT refs**  
- `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`, `docs/API.md`  
- D-003, D-004, D-010, D-064, D-082

**Prerequisites**: P1-02, P2-00

**OPEN**  
- (해소됨) 관찰 조회 RPC는 API.md §8 `rpc_get_my_observation_group`로 확정됨.

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### Non-goals (이 EP에서 하지 않는 것)
- DB schema/RPC/RLS/GRANT/REVOKE 변경 — Impact flags 전부 no. 이 EP는 앱 다이어리 플로우 구현만 다룬다.

### 4) App(Expo) 구현
- [ ] ROUTES-AND-IA 기준으로 화면/탭/라우트 스택을 구성(스펙 외 UI 확장 금지).
- [ ] Transport Adapter(P2-00) 경유로 RPC 호출/에러 매핑을 일원화.
- [ ] `error_code` 기반 UX 분기: `not_found`=404 UX, `terms_not_agreed`, `version_conflict` 등은 표준 UX로 처리.
- [ ] write 흐름은 **idempotency_key 재사용**(재시도 동일 키) 원칙을 지켜 중복 생성 위험을 줄인다.
- [ ] 수동 시나리오(Phase 파일 Validation placeholders)를 실제 기기(iOS/Android) 기준으로 재현/증거화.

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
- 수동: 409 UX, 미래 날짜 방어(D-010), 드래프트 복원
```

## DoD
### Functional DoD
```text
- log_date 관찰 저장/수정/충돌 처리 완결.  
- 로컬 드래프트(D-004) + CTA(D-082) 포함.
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
- (해소됨) 관찰 조회 RPC → API.md §8 확정: `rpc_get_my_observation_group`.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P2-03: 다이어리 플로우 번들(관찰 upsert/patch + 409 처리 + 드래프트 복원)

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

# Execution Packet — P0-03C: Ops/app_config + payload KPI + auth bootstrap + storage baseline

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-03C`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-03C`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **yes**
  - RLS·SECURITY DEFINER: **yes**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/migrations.md`
  - `docs/playbooks/ops-app-config.md`
  - `docs/playbooks/payload-version-kpi.md`
  - `docs/playbooks/rls-and-guards.md`
- Prerequisites: P0-03B

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/DATA-MODEL.md`
- `docs/AUTHZ-MODEL.md`
- `docs/VERIFICATION.md`
- `docs/CONFIG-BASELINES.md`
- `docs/playbooks/ops-app-config.md`
- `docs/playbooks/payload-version-kpi.md`
- `docs/DECISIONS.md` (관련 Decision: D-045, D-056, D-066, D-067, D-072, D-089, D-094)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- - Auth bootstrap 오브젝트 이름: **TBD(레포 근거 필요)**

## Targets (이 EP에서 만지는 주요 표면)
- RPC:
  - `rpc_get_app_config`
- Tables / Entities (참고):
  - `app_config`
  - `assets`
  - `ops_metrics`
  - `payload_version_events`
  - `payload_version_rollups`
  - `payload_versions`

## Baseline spec (from Phase file)
```markdown
## EP P0-03C — Ops/app_config + payload KPI + auth bootstrap + storage baseline
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- 운영 파라미터(app_config)와 payload KPI 저장소를 만들어 운영 가능 시스템으로 만든다.  
- Auth 부트스트랩(profiles upsert)과 Storage 공개 경계를 v1 기준선으로 깔아 둔다.

**Scope**  
- Allowed: `supabase/migrations/**`, `docs/CONFIG-BASELINES.md`(링크 보강만)  
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

### 3) RPC/Contract 구현
- [ ] write RPC는 트랜잭션 경계 명시(부분쓰기 방지) + idempotency/expected_version(해당 시) 구현.
- [ ] 비즈니스 에러는 JSON return(`error_code`, 추가 필드)로 전달(raise exception은 hard fail만).
- [ ] `guard_terms_agreed()` 적용(D-073) + guard 호출 순서(D-096) 고정.
- [ ] replay는 최초 성공과 동일 shape를 반환(status-only 금지, D-061).
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

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
- Smoke: `rpc_get_app_config(['rate_limits','auto_hide'])` 반환  
- Negative: anon 호출 거부(권한/EXECUTE/내부 auth check)
```

## DoD
### Functional DoD
```text
- 운영 파라미터(app_config)와 payload KPI 저장소를 만들어 운영 가능 시스템으로 만든다.  
- Auth 부트스트랩(profiles upsert)과 Storage 공개 경계를 v1 기준선으로 깔아 둔다.
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
- auth bootstrap의 정확한 DB 오브젝트 이름/경로.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-03C: Ops/app_config + payload KPI + auth bootstrap + storage baseline

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

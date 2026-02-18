# Execution Packet — P0-03A: DB 마이그레이션 번들 A(코어 스키마 1)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-03A`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-03A`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **yes**
  - RLS·SECURITY DEFINER: **no**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/migrations.md`
- Prerequisites: P0-02

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/DECISIONS.md`
- `docs/DATA-MODEL.md`
- `docs/VERIFICATION.md`
- `docs/playbooks/migrations.md`
- `docs/DECISIONS.md` (관련 Decision: D-041, D-057, D-058, D-060, D-061, D-064, D-075, D-087, D-094)

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- - [ ] 마이그 파일 분할(번호/파일명 TBD) + 롤백 경로

## Baseline spec (from Phase file)
```markdown
## EP P0-03A — DB 마이그레이션 번들 A(코어 스키마 1)
(스키마/인덱스/제약, RLS/SECURITY DEFINER 분리)

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- `docs/DATA-MODEL.md` 기반으로 코어 테이블/제약/핵심 인덱스를 먼저 확정한다.  
- 대형 마이그 파일 1개 몰아넣기 금지(3~4 EP 분할의 1/4).

**Scope**  
- Allowed: `supabase/migrations/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **no** / Write? **yes**

**Interfaces**  
- Tables: `profiles`, `cats`, `catalog_*`, `inventory_items`, `observation_groups`, `observations`, `observation_inventory_refs`, `observation_patch_dedup`

**Validation placeholders**  
- `db:reset` + `db:smoke`  
- Negative(placeholder): CHECK/UNIQUE 위반 insert 실패

**Hardening hints**  
- [ ] 마이그 파일 분할(번호/파일명 TBD) + 롤백 경로  
- [ ] D-087 길이 CHECK / D-075 reason_code 불변 반영 점검  
- [ ] observation UNIQUE(owner_id, log_date) + idempotency 부분 유니크 반영 점검

**SSOT refs**  
- `docs/DATA-MODEL.md`, `docs/DECISIONS.md`, `docs/playbooks/migrations.md`  
- D-041, D-060, D-061, D-075, D-087

**Prerequisites**: P0-02

**OPEN**  
- 마이그레이션 파일 실제 번호/파일명은 레포 생성 후 확정.

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

### Non-goals (이 EP에서 하지 않는 것)
- RPC/함수/GRANT/REVOKE/RLS 변경 — Impact flags에서 RLS: **no**. 순수 스키마(테이블/제약/인덱스)만 다룬다.
- Guard 함수 구현 — P0-03D에서 수행.
- 도메인 write RPC 구현 — Phase 1 이후 해당 EP에서 수행.

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
- Negative(placeholder): CHECK/UNIQUE 위반 insert 실패
```

## DoD
### Functional DoD
```text
- `docs/DATA-MODEL.md` 기반으로 코어 테이블/제약/핵심 인덱스를 먼저 확정한다.  
- 대형 마이그 파일 1개 몰아넣기 금지(3~4 EP 분할의 1/4).
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
- 마이그레이션 파일 실제 번호/파일명은 레포 생성 후 확정.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-03A: DB 마이그레이션 번들 A(코어 스키마 1)

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

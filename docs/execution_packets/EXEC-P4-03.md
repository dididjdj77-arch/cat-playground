# Execution Packet — P4-03: 배포(프로덕션 migration 적용 + 앱/웹 배포 + 런치 체크리스트)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-4.md` / EP `P4-03`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P4-03`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **yes**
  - Schema change: **yes**
  - RLS·SECURITY DEFINER: **yes**
  - Write: **yes**
- Playbook refs:
  - `docs/playbooks/migrations.md`
  - `docs/playbooks/rls-and-guards.md`
- Prerequisites: P4-02

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-4.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/DATA-MODEL.md`
- `docs/AUTHZ-MODEL.md`
- `docs/VERIFICATION.md`

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- OPEN: 배포 도구체(스토어/호스팅) SSOT 근거가 필요하면 Env Matrix에 추가.

## Baseline spec (from Phase file)
```markdown
## EP P4-03 — 배포(프로덕션 migration 적용 + 앱/웹 배포 + 런치 체크리스트)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 프로덕션 마이그레이션 적용 및 앱/웹 배포 수행.  
- 런치 체크리스트(VERIFICATION)를 근거로 한 번에 공개.

**Scope**  
- Allowed: 배포 스크립트/문서/런치 체크리스트(레포 근거 필요)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- prod supabase migrations 적용  
- 앱/웹 배포 파이프라인(플랫폼별, SSOT 근거 필요)

**Validation placeholders**  
- 런치 체크: `docs/VERIFICATION.md` §런치 체크  
- 롤백 플랜: DB/앱/웹 각각(가능한 범위에서)

**Hardening hints**  
- [ ] PITR 확인 + 복구 시나리오 최소  
- [ ] cron 등록/실행/실패 관측 최소 보장  
- [ ] storage policy 최종 점검(원본 private/파생 public/비노출 전환 시 삭제)

**SSOT refs**  
- `docs/VERIFICATION.md`, `roadmap.md`, `docs/PROCESS.md`

**Prerequisites**: P4-02

**OPEN**  
- 배포 도구체(스토어/호스팅) SSOT 근거가 필요하면 Env Matrix에 추가.

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 1) 프로덕션 마이그레이션 적용 (기존 migration을 적용, 새로 생성하지 않음)
> 새 migration/RPC/RLS가 필요하면 별도 EP/PR로 먼저 머지한다. 이 EP는 "적용/배포/검증" 런북이다.
- [ ] 프로덕션 DB에 기존 migration 파일들을 순서대로 적용.
- [ ] 적용 전 PITR 백업 확인.
- [ ] 적용 후 스키마 drift 검증 (`ci:drift` 또는 동등 확인).
- [ ] 롤백 경로 명시: revert migration 또는 PITR 복구 절차.

### 2) 문서/운영 작업
- [ ] 문서 변경은 SSOT 원칙(이유는 DECISIONS/ADR, 수치는 CONFIG-BASELINES)에 맞게 최소 변경.
- [ ] 비밀값은 쓰지 않고, **설정 위치/절차**만 기록.
- [ ] 체크리스트는 실행 가능 형태(누가/언제/어디서/어떤 근거로)로 작성.

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
- 런치 체크: `docs/VERIFICATION.md` §런치 체크  
- 롤백 플랜: DB/앱/웹 각각(가능한 범위에서)
```

## DoD
### Functional DoD
```text
- 프로덕션 마이그레이션 적용 및 앱/웹 배포 수행.  
- 런치 체크리스트(VERIFICATION)를 근거로 한 번에 공개.
```
### Safety DoD
- [ ] Forbidden path 변경 없음(범위 슬립 0).
- [ ] 부분쓰기/권한누출/공개 DTO 누출/404 통일 위반 없음.
- [ ] Public Surface Gate(G-1~G-4) 영향이 있으면 `ci:public-gate` green 증거 첨부.
- [ ] 마이그레이션 롤백 경로(다운 SQL 또는 revert 커밋) 명시.
### Evidence required in PR
- [ ] 실행한 커맨드/SQL + 출력(또는 스크린샷) 첨부.
- [ ] 변경 파일 목록(자동/수동) 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] DB: 롤백 SQL 또는 revert 커밋 절차.
- [ ] 앱/웹: 기능 플래그/리버트 커밋 절차.

## OPEN (from Phase)
- 배포 도구체(스토어/호스팅) SSOT 근거가 필요하면 Env Matrix에 추가.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P4-03: 배포(프로덕션 migration 적용 + 앱/웹 배포 + 런치 체크리스트)

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

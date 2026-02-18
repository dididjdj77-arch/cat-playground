# Execution Packet — P0-06: Environment Matrix 스켈레톤(값은 0.9에서 채움)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-06`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-06`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **FAST** (문서 단일 파일 변경, DB/코드 영향 없음)
- Impact flags (from Phase skeleton):
  - Public surface: **no**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs:
  - `docs/playbooks/ops-app-config.md`
- Prerequisites: none

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다. (문서 EP 보정: 새 필드명 생성은 가능하되, 실제 env var/설정 키는 레포 근거 없으면 TBD로 둔다.)
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/playbooks/ops-app-config.md`

## Blockers / SSOT gaps (stop-the-line)
> 아래 항목이 해결되지 않으면 **구현을 진행하지 않는다**. (추측 구현 금지)
- 없음. 이 EP는 필드 목록(스키마)만 확정하고 값은 Phase 0.9에서 채운다.

## Baseline spec (from Phase file)
```markdown
## EP P0-06 — Environment Matrix 스켈레톤(값은 0.9에서 채움)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- dev/staging/prod 환경 “필드”를 고정해 재현 가능한 운영 기반을 만든다(값은 TBD).

**Scope**  
- Allowed: `docs/playbooks/ops-app-config.md`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 문서 섹션: Environment Matrix 필드(roadmap §1.4)

**Validation placeholders**  
- 문서 링크/형식 체크(있다면)

**Hardening hints**  
- [ ] 비밀값은 “값”이 아니라 “저장 위치/권한경계”만 기록  
- [ ] OAuth redirect URI / Expo scheme / Next domain 등 누락 필드 체크리스트화

**SSOT refs**  
- `docs/playbooks/ops-app-config.md`, `roadmap.md`, `docs/PROCESS.md`

**Prerequisites**: none

**OPEN**: none

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 1) 문서/운영 작업
- [ ] 문서 변경은 SSOT 원칙(이유는 DECISIONS/ADR, 수치는 CONFIG-BASELINES)에 맞게 최소 변경.
- [ ] 비밀값은 쓰지 않고, **설정 위치/절차**만 기록.
- [ ] 체크리스트는 실행 가능 형태(누가/언제/어디서/어떤 근거로)로 작성.

## Validation (must run)
- Risk level: **FAST** (문서 EP)
- Setup:
  - 문서 링크/형식 체크(레포에 `check-docs-integrity` 등이 있으면 실행)
- Smoke tests (at least 1):
  - 변경된 `ops-app-config.md`의 Environment Matrix 필드 목록이 존재하고 형식이 올바른지 확인.
- Negative tests:
  - 최소 1개는 조건/설명으로라도 명시(가능하면 재현/증거). 예: "비밀값이 문서에 포함되지 않았는지" 확인.

### Phase placeholder excerpt
```text
- 문서 링크/형식 체크(있다면)
```

## DoD
### Functional DoD
```text
- dev/staging/prod 환경 “필드”를 고정해 재현 가능한 운영 기반을 만든다(값은 TBD).
```
### Safety DoD
- [ ] Forbidden path 변경 없음(범위 슬립 0) — `docs/playbooks/ops-app-config.md` 외 변경 없어야 함.
- [ ] 비밀값(토큰/키/비밀번호)이 문서에 포함되지 않음.
### Evidence required in PR
- [ ] 변경 파일 목록 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] revert 커밋으로 복원.

## OPEN (from Phase)
none

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-06: Environment Matrix 스켈레톤(값은 0.9에서 채움)

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

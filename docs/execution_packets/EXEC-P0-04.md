# Execution Packet — P0-04: 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-04`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-04`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **yes**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs: none
- Prerequisites: P0-03D

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-0.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/VERIFICATION.md`
- `docs/CONFIG-BASELINES.md`
- `docs/DECISIONS.md` (관련 Decision: D-050, D-056)

## Baseline spec (from Phase file)
```markdown
## EP P0-04 — 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal (1~3줄)**  
- Phase 1부터 “테스트+게이트가 머지 조건”이 되도록 기반 테스트/시드/게이트 골격을 만든다.  
- Public Surface Gate(G-1~G-4)는 이후 실제 머지 조건으로 전환 가능해야 한다.

**Scope**  
- Allowed: `tests/**`, `tests/fixtures/**`, `.github/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Gates: G-1~G-4, DCI-1~DCI-4  
- Fixture: User A/B/C/D, block 관계, 공개 post/thread 샘플, topic 2개, 운영 파라미터 seed

**Validation placeholders**  
- `repo:test`, `ci:verify`  
- (Phase 1 첫 공개 RPC 전까지) `ci:public-gate`는 skip 가능하되 스켈레톤 존재는 필수

**Hardening hints**  
- [ ] fixture 생성 방식(DB seed vs 테스트 런타임) 선택  
- [ ] DTO 금지 필드 목록을 테스트로 강제(DCI-4)  
- [ ] 롤백: 테스트/시드 revert

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/PROCESS.md`, `docs/CONFIG-BASELINES.md`, `docs/API.md`  
- D-050, D-056

**Prerequisites**: P0-03D

**OPEN**  
- 테스트 프레임워크/루트 경로(레포 근거 필요).

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### 3) RPC/Contract 구현
- [ ] 공개 읽기 RPC는 `SECURITY DEFINER` + guard_soft_state + guard_block (+ 필요 시 guard_visibility_published) 적용.
- [ ] 반환 컬럼은 **명시적 화이트리스트**(select * 금지).
- [ ] 공개 표면에서 조회 불가 상태는 404로 통일(D-050).
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

### 6) 테스트/게이트
- [ ] tests/fixtures 기반으로 재현 가능한 데이터 세팅(User A/B/C, block 관계, 샘플 콘텐츠).
- [ ] VERIFICATION의 해당 테스트(T-1~T-6, DCI-1~4)를 스냅샷/네거티브까지 포함해 구현.
- [ ] CI 스크립트(`ci:verify`, `ci:public-gate`, `ci:drift`)에서 실행되도록 연결.

### 1) 문서/운영 작업
- [ ] 문서 변경은 SSOT 원칙(이유는 DECISIONS/ADR, 수치는 CONFIG-BASELINES)에 맞게 최소 변경.
- [ ] 비밀값은 쓰지 않고, **설정 위치/절차**만 기록.
- [ ] 체크리스트는 실행 가능 형태(누가/언제/어디서/어떤 근거로)로 작성.

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
- `repo:test`, `ci:verify`  
- (Phase 1 첫 공개 RPC 전까지) `ci:public-gate`는 skip 가능하되 스켈레톤 존재는 필수
```

## DoD
### Functional DoD
```text
- Phase 1부터 “테스트+게이트가 머지 조건”이 되도록 기반 테스트/시드/게이트 골격을 만든다.  
- Public Surface Gate(G-1~G-4)는 이후 실제 머지 조건으로 전환 가능해야 한다.
```
### Safety DoD
- [ ] Forbidden path 변경 없음(범위 슬립 0).
- [ ] 부분쓰기/권한누출/공개 DTO 누출/404 통일 위반 없음.
- [ ] Public Surface Gate(G-1~G-4) 영향이 있으면 `ci:public-gate` green 증거 첨부.
### Evidence required in PR
- [ ] 실행한 커맨드/SQL + 출력(또는 스크린샷) 첨부.
- [ ] 변경 파일 목록(자동/수동) 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] DB: 롤백 SQL 또는 revert 커밋 절차.
- [ ] 앱/웹: 기능 플래그/리버트 커밋 절차.

## OPEN (from Phase)
- 테스트 프레임워크/루트 경로(레포 근거 필요).

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P0-04: 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단

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

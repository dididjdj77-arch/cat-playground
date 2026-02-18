# Execution Packet — P0-04: 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-0.md` / EP `P0-04`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P0-04`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (수정됨 — 스켈레톤 단계에서 공개 엔드포인트 변경 없음):
  - Public surface: **no** (Gate 스켈레톤만 생성, 실제 public endpoint 추가 없음. Phase 1 전환 시 재평가)
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
- Public surface? **no** (스켈레톤만, Phase 1 전환 시 재평가) / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

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

### Non-goals (이 EP에서 하지 않는 것)
- DB 함수/RLS/GRANT/REVOKE/마이그레이션 변경 — P0-03D 또는 별도 EP 영역.
- SECURITY DEFINER RPC 생성 — Scope(`tests/**`, `.github/**`)에 해당하지 않음.
- 도메인 RPC 구현 — Phase 1 이후 EP에서 수행.

### 6) 테스트/게이트
- [ ] tests/fixtures 기반으로 재현 가능한 데이터 세팅(User A/B/C, block 관계, 샘플 콘텐츠).
- [ ] Phase 0 최소 세트: **G-1~G-4 스켈레톤(skip 가능하되 존재 필수)** + **DCI-1~DCI-2 기반 검증**만 exact 구현.
- [ ] T-1~T-6, DCI-3~4는 **placeholder/skeleton**으로 두고 Phase 1 이후 EP에서 exact 전환.
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
- [ ] Public Surface Gate(G-1~G-4) 스켈레톤이 존재하고 `ci:public-gate` skip 또는 green 증거 첨부.
### Evidence required in PR
- [ ] 실행한 커맨드/SQL + 출력(또는 스크린샷) 첨부.
- [ ] 변경 파일 목록(자동/수동) 첨부.
- [ ] OPEN 질문/추가 EP 필요 사항을 명시(있다면).
### Rollback
- [ ] DB: 롤백 SQL 또는 revert 커밋 절차.
- [ ] 앱/웹: 기능 플래그/리버트 커밋 절차.

## OPEN (from Phase)
- 테스트 프레임워크/루트 경로(레포 근거 필요).
- P0-03D 완료 후 guard 함수 검증 대상 목록 확정 필요(어떤 guard를 테스트에서 검증할지).
- Phase 0 최소 테스트 세트(G-1~G-4 + DCI-1~2) 외 나머지를 Phase 1 어느 EP에서 exact 전환할지.

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

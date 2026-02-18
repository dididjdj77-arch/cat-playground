# Execution Packet — P3-00: Transport Adapter(웹 SSR/ISR) 구현(error_code → HTTP)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-3.md` / EP `P3-00`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P3-00`
- Assign EP-ID (controller fills): `EP-YYYYMMDD-<slug>`
- Risk level: **PRECISE**
- Impact flags (from Phase skeleton):
  - Public surface: **yes**
  - Schema change: **no**
  - RLS·SECURITY DEFINER: **no**
  - Write: **no**
- Playbook refs:
  - `docs/playbooks/seo-web.md`
- Prerequisites: P1-04/05

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-3.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/API.md`
- `docs/VERIFICATION.md`
- `docs/playbooks/seo-web.md`
- `docs/DECISIONS.md` (관련 Decision: D-050, D-071)

## Baseline spec (from Phase file)
```markdown
## EP P3-00 — Transport Adapter(웹 SSR/ISR) 구현(error_code → HTTP)
**Goal (1~3줄)**  
- 웹에서 `error_code`를 HTTP 상태코드로 변환(D-071)해 200+에러바디 노출을 제거한다.  
- 공개 표면 조회 불가 상태는 404 통일(D-050)을 강제한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `apps/web/**`, `packages/shared/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Next route handler(또는 서버 액션)에서 API 매핑 적용  
- error_code 표: `docs/API.md`

**Validation placeholders**  
- 스모크: not_found → 404 렌더  
- 네거티브: error_code가 HTML에 노출되지 않음

**Hardening hints**  
- [ ] SSR/ISR 캐시 설정과의 상호작용 정리  
- [ ] 롤백: adapter revert

**SSOT refs**  
- `docs/API.md`, `docs/playbooks/seo-web.md`  
- D-050, D-071

**Prerequisites**: P1-04/05

**OPEN**  
- Next 라우팅 구조(App Router/Pages Router) 레포 근거 필요.

---
```

### 0) Pre-flight (작업 전)
- [ ] **Prerequisites** 충족 여부 확인. 미충족이면 작업 중단.
- [ ] Scope(Allowed/Forbidden) 재확인. Forbidden 변경 필요 시 **새 EP로 분리**.
- [ ] SSOT(API/DECISIONS/DATA-MODEL/AUTHZ/VERIFICATION)에서 **이 EP가 참조하는 이름(RPC/테이블/키)** 이 실제로 존재하는지 확인.
- [ ] `TBD`/SSOT 갭이 남아있으면 **추측 구현 금지**. OPEN에 기록하고 컨트롤러에게 SSOT 보강 요청.
- [ ] Validation 스크립트(`repo:*`, `db:*`, `ci:*`)가 실제 레포에서 무엇을 실행하는지 확인(필요 시 P0-01/02에서 매핑).

### Non-goals (이 EP에서 하지 않는 것)
- DB schema/RPC/RLS/GRANT/REVOKE 변경 — RLS·SECURITY DEFINER: no. 이 EP는 웹 Transport Adapter 구현만 다룬다.

### 5) Web(SEO/SSR/ISR) 구현
- [ ] Next 라우팅 구조(App Router/Pages Router)는 레포 근거로 확정. 불명확하면 OPEN으로 남기고 보수적으로 구현.
- [ ] Transport Adapter(P3-00): `error_code` → HTTP status 변환을 SSR/ISR 경로에서 강제.
- [ ] SEO 규칙: index/noindex, robots/sitemap/metadata, 404 통일(D-050)을 준수.
- [ ] ISR/revalidate는 allowlist + secret header로만 트리거. secret 노출(로그/쿼리/바디) 금지.
- [ ] 보안 네거티브 테스트(T-6)가 머지 조건이 되도록 자동화.

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
- 스모크: not_found → 404 렌더  
- 네거티브: error_code가 HTML에 노출되지 않음
```

## DoD
### Functional DoD
```text
- 웹에서 `error_code`를 HTTP 상태코드로 변환(D-071)해 200+에러바디 노출을 제거한다.  
- 공개 표면 조회 불가 상태는 404 통일(D-050)을 강제한다.
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
- Next 라우팅 구조(App Router/Pages Router) 레포 근거 필요.

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P3-00: Transport Adapter(웹 SSR/ISR) 구현(error_code → HTTP)

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

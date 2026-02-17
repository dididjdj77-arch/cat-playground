# Execution Packet — P3-02: 썸네일 라이프사이클 + revalidate 보안(네거티브 테스트=머지 조건)

> Issued: 2026-02-17 (Asia/Seoul)  
> Phase ref: `PHASE-3.md` / EP `P3-02`  
> 이 문서는 Phase 파일 스켈레톤을 실제 실행자용으로 확장한 **실전 지시서**다.  
> SSOT/API 명세가 빈칸(TBD)인 경우, **추측 구현 금지** — OPEN으로 남기고 선행 SSOT 보강 EP를 요청한다.

## Meta
- Phase EP: `P3-02`
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
  - `docs/playbooks/seo-web.md`
- Prerequisites: P3-01, P0-03C(storage baseline), P1-04 (posts publish/unpublish 트리거 정합)

## Hardening safety rules (MUST)
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

## SSOT read first
- `PHASE-3.md` (Phase skeleton)
- `docs/PROCESS.md`
- `docs/DECISIONS.md`
- `docs/DATA-MODEL.md`
- `docs/AUTHZ-MODEL.md`
- `docs/VERIFICATION.md`
- `docs/playbooks/seo-web.md`
- `docs/DECISIONS.md` (관련 Decision: D-007, D-025, D-067, D-072)

## Baseline spec (from Phase file)
```markdown
## EP P3-02 — 썸네일 라이프사이클 + revalidate 보안(네거티브 테스트=머지 조건)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- publish→썸네일 생성 / unpublish·hide·delete·private→삭제 / ISR revalidate 트리거 구현(D-072/D-067).  
- revalidate 보안 불변식을 테스트로 강제(VERIFICATION T-6).

**Scope**  
- Allowed: `apps/web/**`, `supabase/**`, `supabase/functions/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Storage: `assets`(원본 private), `assets-public`(썸네일 public)  
- Web: `/api/revalidate` + `x-revalidate-secret`  
- allowlist 기반 path 제한
- 썸네일 생성/삭제 트리거는 posts publish/unpublish 의미(D-007)와 정합해야 한다.

**Validation placeholders**  
- VERIFICATION T-6 네거티브 4종(401/403/403/200)  
- 수동: unpublish 후 썸네일 직링크 404

**Hardening hints**  
- [ ] secret 평문 노출 금지(로그/쿼리/바디)  
- [ ] allowlist 상수 1곳 + 테스트 동일 상수 import  
- [ ] 썸네일 삭제 ↔ revalidate 순서/실패 처리(멱등/재시도)  
- [ ] 롤백: 트리거/워커 비활성화 + 엔드포인트 차단

**SSOT refs**  
- `docs/playbooks/seo-web.md`, `docs/VERIFICATION.md`, `docs/DECISIONS.md`, `docs/DATA-MODEL.md`  
- D-067, D-072, D-025

**Prerequisites**: P3-01, P0-03C(storage baseline), P1-04 (posts publish/unpublish 트리거 정합)

**OPEN**  
- 트리거 실행체 선택(pg_net/webhook vs Edge Function).

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
- [ ] 공개 읽기 RPC는 `SECURITY DEFINER` + guard_soft_state + guard_block (+ 필요 시 guard_visibility_published) 적용.
- [ ] 반환 컬럼은 **명시적 화이트리스트**(select * 금지).
- [ ] 공개 표면에서 조회 불가 상태는 404로 통일(D-050).
- [ ] GRANT/REVOKE: anon/authenticated 권한을 SSOT에 맞게 최소로 설정.
- [ ] 테스트/스냅샷(VERIFICATION, drift)으로 계약/가드/누출 방지를 회귀로 고정.

### 5) Web(SEO/SSR/ISR) 구현
- [ ] Next 라우팅 구조(App Router/Pages Router)는 레포 근거로 확정. 불명확하면 OPEN으로 남기고 보수적으로 구현.
- [ ] Transport Adapter(P3-00): `error_code` → HTTP status 변환을 SSR/ISR 경로에서 강제.
- [ ] SEO 규칙: index/noindex, robots/sitemap/metadata, 404 통일(D-050)을 준수.
- [ ] ISR/revalidate는 allowlist + secret header로만 트리거. secret 노출(로그/쿼리/바디) 금지.
- [ ] 보안 네거티브 테스트(T-6)가 머지 조건이 되도록 자동화.

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
- VERIFICATION T-6 네거티브 4종(401/403/403/200)  
- 수동: unpublish 후 썸네일 직링크 404
```

## DoD
### Functional DoD
```text
- publish→썸네일 생성 / unpublish·hide·delete·private→삭제 / ISR revalidate 트리거 구현(D-072/D-067).  
- revalidate 보안 불변식을 테스트로 강제(VERIFICATION T-6).
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
- 트리거 실행체 선택(pg_net/webhook vs Edge Function).

## Result Packet (PR 본문에 채워 넣기)

```markdown
# Result Packet — P3-02: 썸네일 라이프사이클 + revalidate 보안(네거티브 테스트=머지 조건)

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

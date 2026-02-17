# PHASE-4.md
# Phase 4 — QA + 런치(Release-Train)

## Scope Baseline (PR-1)
- 계획 경로 표준(placeholder 치환): `apps/expo/**`, `apps/web/**`, `packages/shared/**`, `tests/**`, `supabase/functions/**`, `supabase/**`
- 공통 Allowed paths(모든 EP): `docs/**`, `.github/**`, `scripts/**`, `supabase/**`
- Forbidden(모든 EP): Allowed에 적힌 것 외 변경 금지

## EP P4-01 — 자동 QA(회귀 풀스위트 + 누락 보강 + CI 최종 green)
**Goal (1~3줄)**  
- 회귀 테스트 풀스위트를 돌리고 누락을 보강한다.  
- Public Surface Gate(G-1~G-4)와 revalidate 네거티브(T-6)를 최종 green으로 만든다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `tests/**`, `.github/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- `ci:verify`, `ci:public-gate`, `ci:drift`

**Validation placeholders**  
- CI 최종 green + evidence 첨부(로그/출력)

**Hardening hints**  
- [ ] flaky 제거/격리  
- [ ] 실패 원인 분류 템플릿

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/PROCESS.md`, `roadmap.md`

**Prerequisites**: Phase 1~3 완료

**OPEN**: none

---

## EP P4-02 — 실기기 + 웹 최종 확인(워크스루/SEO 크롤/OG/썸네일 404)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- 앱 핵심 플로우 워크스루 + 웹 SEO 크롤 시뮬레이션.  
- 썸네일 직링크 404 등 런치 사고 포인트 재확인.

**Scope**  
- Allowed: runbook/체크리스트 문서(필요 시)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 앱: 하우스/다이어리/소셜/설정 + `/notifications`  
- 웹: `/c*`, `/p*`, `/search` noindex, OG/robots/sitemap

**Validation placeholders**  
- `docs/VERIFICATION.md` 수동 QA 시나리오 체크

**Hardening hints**  
- [ ] “웹은 anon-only” 커뮤니케이션 문구 포함(D-098)  
- [ ] 발견 결함은 원인별 분리 EP

**SSOT refs**  
- `docs/VERIFICATION.md`, `docs/ROUTES-AND-IA.md`, `docs/DECISIONS.md`  
- D-098

**Prerequisites**: P4-01

**OPEN**: none

---

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

## Phase 4 요약
- EP 개수: 3  
- 단독 권장(고위험): P4-03  
- 번들 후보(가벼운 것끼리): P4-01+P4-02

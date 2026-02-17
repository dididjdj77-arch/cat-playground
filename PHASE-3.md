# PHASE-3.md
# Phase 3 — Web(Next.js) + 썸네일 + 운영 마무리

## EP P3-00 — Transport Adapter(웹 SSR/ISR) 구현(error_code → HTTP)
**Goal (1~3줄)**  
- 웹에서 `error_code`를 HTTP 상태코드로 변환(D-071)해 200+에러바디 노출을 제거한다.  
- 공개 표면 조회 불가 상태는 404 통일(D-050)을 강제한다.

**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Scope**  
- Allowed: `TBD: <next-web-root>/**`, `TBD: <shared-root>/**`  
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

## EP P3-01 — SEO 웹(anon-only): `/c*`, `/p*`, `/search(noindex)`, robots/sitemap/metadata
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- SEO 유입 목적의 웹을 완성(D-015).  
- v1 SEO surface는 anon 기준 결과로 고정(D-098), noindex 정책 준수.

**Scope**  
- Allowed: `TBD: <next-web-root>/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- Routes: `/c`, `/c/{topicSlug}`, `/c/{topicSlug}/{threadId}`, `/p`, `/p/{postId}`, `/search`(noindex), `/u/{nickname}`(noindex)  
- Public RPC: `rpc_get_public_threads_feed`, `rpc_get_public_posts_feed` (+ 상세/댓글 RPC는 SSOT 근거 있을 때만)

**Validation placeholders**  
- 스모크: index 라우트 200, hidden/deleted 404(D-050)  
- 네거티브: `/search`에 noindex meta 존재

**Hardening hints**  
- [ ] ISR revalidate 주기/정책 정리  
- [ ] 404 통일/존재 은닉 커뮤니케이션 문구

**SSOT refs**  
- `docs/playbooks/seo-web.md`, `docs/ROUTES-AND-IA.md`  
- D-015, D-021, D-050, D-078, D-098

**Prerequisites**: P3-00

**OPEN**  
- 상세 조회 public RPC 함수명 SSOT 보강 필요.

---

## EP P3-02 — 썸네일 라이프사이클 + revalidate 보안(네거티브 테스트=머지 조건)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- publish→썸네일 생성 / unpublish·hide·delete·private→삭제 / ISR revalidate 트리거 구현(D-072/D-067).  
- revalidate 보안 불변식을 테스트로 강제(VERIFICATION T-6).

**Scope**  
- Allowed: `TBD: <next-web-root>/**`, `TBD: <supabase-root>/**`, `TBD: <edge-or-worker-root>/**`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **yes** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Storage: `assets`(원본 private), `assets-public`(썸네일 public)  
- Web: `/api/revalidate` + `x-revalidate-secret`  
- allowlist 기반 path 제한

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

**Prerequisites**: P3-01, P0-03C(storage baseline)

**OPEN**  
- 트리거 실행체 선택(pg_net/webhook vs Edge Function).

---

## EP P3-03 — 스케줄드 작업(pg_cron) + 운영 파라미터 + 집계 보정
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- TTL/retention/보정 잡을 pg_cron으로 등록(D-069)하고 cadence는 CONFIG-BASELINES 기준으로 고정한다.  
- app_config seed/조회 검증 및 레이트리밋 동작 확인을 포함한다.

**Scope**  
- Allowed: `TBD: <supabase-root>/**`, `docs/CONFIG-BASELINES.md`, `docs/playbooks/ops-app-config.md`  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **yes** / RLS·SECURITY DEFINER? **yes** / Write? **yes**

**Interfaces**  
- Jobs: idempotency cleanup(D-041), patch_dedup cleanup(D-061), events retention(D-045), counter reconcile  
- app_config keys: `rate_limits`, `rate_limits_new_account`, `auto_hide`, `popular_feed`

**Validation placeholders**  
- 스모크: cron 등록 목록 확인(placeholder)  
- Drift: DCI-2(app_config whitelist 스냅샷)

**Hardening hints**  
- [ ] cron 표현식은 UTC 기준으로 기록  
- [ ] 실패 관측(runbook) 최소  
- [ ] 롤백: cron 해제/함수 revert

**SSOT refs**  
- `docs/CONFIG-BASELINES.md`, `docs/DECISIONS.md`, `docs/playbooks/ops-app-config.md`  
- D-041, D-045, D-061, D-069, D-076

**Prerequisites**: P1-02, P1-04/05, P0-03C

**OPEN**  
- cron 등록을 SQL 마이그레이션으로 할지 운영 설정으로 둘지.

---

## EP P3-04 — 프로덕션 준비 사전 점검(PITR/cron on-off/runbook 최소)
**Hardening safety rules (EP마다 반드시 포함)**  
1) Reality check: 레포에 실제로 존재하는 파일/경로/심볼/테이블/RPC 이름만 사용한다. 확실치 않으면 만들지 말고 OPEN으로 남긴다.  
2) Conservative risk: Public surface / Schema / RLS·SECURITY DEFINER / Write 여부가 애매하면 yes로 보수적으로 판정하고 필요한 게이트/검증을 포함한다.  
3) Evidence-only: exact SQL, expected output, 마이그레이션 번호/파일명 같은 확정값은 SSOT나 실제 코드 근거가 있을 때만 적는다. 근거 없으면 TBD 유지.

**Goal**  
- Phase 3에서 prod 리스크를 전진 배치한다(roadmap).  
- PITR/cron 운영/관측/체크리스트를 최소 runbook 수준으로 확정한다.

**Scope**  
- Allowed: `docs/playbooks/ops-app-config.md` (+ 필요시 `docs/VERIFICATION.md` 링크 보강)  
- Forbidden: Allowed에 적힌 것 외 변경 금지  
- Public surface? **no** / Schema change? **no** / RLS·SECURITY DEFINER? **no** / Write? **no**

**Interfaces**  
- 운영 체크: PITR, cron on/off 기준, 관측 채널, secrets 저장 위치

**Validation placeholders**  
- 체크리스트 완료(증거/링크)

**Hardening hints**  
- [ ] prod cron 활성/비활성 기준 명시  
- [ ] 복구 시나리오 최소 1개 절차 기록

**SSOT refs**  
- `docs/VERIFICATION.md`, `roadmap.md`, `docs/playbooks/ops-app-config.md`

**Prerequisites**: P3-03

**OPEN**: none

---

## Phase 3 요약
- EP 개수: 5  
- 단독 권장(고위험): P3-00, P3-01, P3-02, P3-03  
- 번들 후보(가벼운 것끼리): P3-04

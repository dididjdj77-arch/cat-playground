# Execution Packets — Issued instructions index

> Generated: 2026-02-17 (Asia/Seoul)

## 사용 방법(컨트롤러/실행자 공통)
- 이 폴더의 각 파일은 Phase 파일(`PHASE-*.md`)의 EP 섹션을 기반으로 만든 **실전 지시서**다.
- 실제 작업 티켓/PR에는 각 EP 파일의 내용을 사용하되, **EP-ID(`EP-YYYYMMDD-<slug>`)를 새로 부여**해서 진행한다.
- Scope(Allowed/Forbidden) 밖 변경이 필요하면, 기존 EP에 섞지 말고 **새 EP로 분리**한다(PROCESS 원칙).
- SSOT/API 명세가 `TBD`인 항목은 **추측 구현 금지**. 선행 SSOT 보강 EP를 먼저 만든다.

## Stop-the-line: SSOT 보강이 필요한 EP들
> 아래 EP는 Phase 스켈레톤 자체가 `SSOT 보강 필요` 또는 함수명 `TBD`를 포함한다.
> 컨트롤러는 **선행 문서 EP(예: API.md 업데이트)** 를 발행하거나, 해당 EP의 Scope에 docs 변경을 허용하도록 Phase/PROCESS를 조정해야 한다.

### 해소됨 (API.md §7-4~§8 보강으로 SSOT 확정)
- ~~P1-03~~ → publish/unpublish RPC 확정 (API.md §7-4: `rpc_publish_house`, `rpc_unpublish_house`)
- ~~P1-04~~ → write RPC 확정 (API.md §7-1)
- ~~P1-05~~ → 채널 RPC 확정 (API.md §7-2)
- ~~P1-06~~ → block RPC 확정 (API.md §7-3: `rpc_block_user`, `rpc_unblock_user`)
- ~~P2-02~~ → house publish/unpublish 확정 (API.md §7-4)
- ~~P2-04~~ → post detail RPC 확정 (API.md §8: `rpc_get_public_post_detail`)
- ~~P2-05~~ → 채널 RPC 확정 (API.md §7-2)
- ~~P2-06~~ → block/notification/profile RPC 확정 (API.md §7-3, §7-6, §7-7)
- ~~P2-01C~~ → 프로필 조회 경로 확정 (API.md §8: `rpc_get_my_profile`)
- ~~P2-03~~ → 관찰 조회 RPC 확정 (API.md §8: `rpc_get_my_observation_group`)
- ~~P3-01~~ → 상세 조회 public RPC 확정 (API.md §8: `rpc_get_public_post_detail`, `rpc_get_public_thread_detail`)

### 미해소
- (현재 없음 — 본 목록의 API/RPC 함수명 TBD 기준)

## EP 파일 목록(Phase 순서)
### PHASE-0
- `P0-01` — 모노레포 스파인 + 공용 경계 + 표준 커맨드 스켈레톤 → `EXEC-P0-01.md`
- `P0-02` — Supabase 로컬/CI 루프 고정(db:reset → migrate → seed → db:smoke) → `EXEC-P0-02.md`
- `P0-03A` — DB 마이그레이션 번들 A(코어 스키마 1) → `EXEC-P0-03A.md`
- `P0-03B` — DB 마이그레이션 번들 B(코어 스키마 2: 커뮤니티/운영) → `EXEC-P0-03B.md`
- `P0-03C` — Ops/app_config + payload KPI + auth bootstrap + storage baseline → `EXEC-P0-03C.md`
- `P0-03D` — DB 하드닝: Guard 함수 + RLS 베이스라인 + GRANT/REVOKE → `EXEC-P0-03D.md`
- `P0-04` — 회귀 테스트(기반) + Fixture seed + Public Surface Gate 스켈레톤 + Drift 차단 → `EXEC-P0-04.md`
- `P0-05` — DB 타입 코드젠 + 공용 경계(whitelist 타입 동시 강제) → `EXEC-P0-05.md`
- `P0-06` — Environment Matrix 스켈레톤(값은 0.9에서 채움) → `EXEC-P0-06.md`

### PHASE-0.9
- `P0.9-01` — Expo 최소 앱: 로그인 → 세션 확인 → auth-only RPC 1회 호출 → `EXEC-P0_9-01.md`
- `P0.9-02` — 환경별 재현성 체크리스트 + Env Matrix 값 채우기(dev/staging/prod) → `EXEC-P0_9-02.md`

### PHASE-1
- `P1-01` — 인벤토리(owner) RPC: switch/discontinue (+ 불변식 회귀) → `EXEC-P1-01.md`
- `P1-02` — 관찰(owner, 고위험) RPC: upsert + patch + payload_version 검증/이벤트 → `EXEC-P1-02.md`
- `P1-03` — 하우스 RPC: 슬롯 bind/clear + house_profile lazy create + 공개 슬롯 요약(auth-only) → `EXEC-P1-03.md`
- `P1-04` — 냥스타 RPC + Public Surface Gate 활성화(머지 조건 전환) → `EXEC-P1-04.md`
- `P1-05` — 채널 RPC: 토픽/스레드/답글/팔로우/검색(FTS) + 피드 3종 → `EXEC-P1-05.md`
- `P1-06` — 운영 RPC: 신고/차단/자동숨김/감사로그/알림 생성(트랜잭션 내부) → `EXEC-P1-06.md`

### PHASE-2
- `P2-00` — Transport Adapter(앱) 구현(선행 고정) → `EXEC-P2-00.md`
- `P2-01A` — 로그인/로그아웃 + 세션 생성/저장/복구(실기기) → `EXEC-P2-01A.md`
- `P2-01B` — 세션 만료/갱신/오프라인/취소 UX → `EXEC-P2-01B.md`
- `P2-01C` — 온보딩: 약관 동의 → 초기 닉네임 설정 → write unlock → `EXEC-P2-01C.md`
- `P2-02` — 하우스 플로우 번들 → `EXEC-P2-02.md`
- `P2-03` — 다이어리 플로우 번들(관찰 upsert/patch + 409 처리 + 드래프트 복원) → `EXEC-P2-03.md`
- `P2-04` — 냥스타 플로우 번들(피드/상세/작성/발행/댓글/좋아요/업로드) → `EXEC-P2-04.md`
- `P2-05` — 채널 플로우 번들 → `EXEC-P2-05.md`
- `P2-06` — 설정 + 운영 UI 번들(프로필/신고/차단/알림) → `EXEC-P2-06.md`

### PHASE-3
- `P3-00` — Transport Adapter(웹 SSR/ISR) 구현(error_code → HTTP) → `EXEC-P3-00.md`
- `P3-01` — SEO 웹(anon-only): `/c*`, `/p*`, `/search(noindex)`, robots/sitemap/metadata → `EXEC-P3-01.md`
- `P3-02` — 썸네일 라이프사이클 + revalidate 보안(네거티브 테스트=머지 조건) → `EXEC-P3-02.md`
- `P3-03` — 스케줄드 작업(pg_cron) + 운영 파라미터 + 집계 보정 → `EXEC-P3-03.md`
- `P3-04` — 프로덕션 준비 사전 점검(PITR/cron on-off/runbook 최소) → `EXEC-P3-04.md`

### PHASE-4
- `P4-01` — 자동 QA(회귀 풀스위트 + 누락 보강 + CI 최종 green) → `EXEC-P4-01.md`
- `P4-02` — 실기기 + 웹 최종 확인(워크스루/SEO 크롤/OG/썸네일 404) → `EXEC-P4-02.md`
- `P4-03` — 배포(프로덕션 migration 적용 + 앱/웹 배포 + 런치 체크리스트) → `EXEC-P4-03.md`

## 번들링 노트(참고)
- Phase 1: 번들 권장하지 않음(모두 단독).
- Phase 2: 단독 권장 P2-00, P2-01C, P2-03, P2-04, P2-06 / 번들 후보 P2-01A+P2-01B, P2-02+P2-05.
- Phase 3: 단독 권장 P3-00~P3-03 / 번들 후보 P3-04.
- Phase 4: 단독 권장 P4-03 / 번들 후보 P4-01+P4-02.

## 치명적 결함 가능성(문서 수정 제안)
- ~~**API/RPC 함수명 TBD**~~: (해소됨) API.md §7-4~§8 보강으로 모든 EP의 RPC 함수명/시그니처가 SSOT에 확정됨.
- **Env Matrix 미완**: P0-01/02/0.9-01에서 레포 경로/딥링크 스킴 등이 OPEN이다. → `ENV-MATRIX`(P0-06/0.9-02)에서 값/설정 위치를 확정해 재현성을 올리는 것을 권장.

v1 최종 로드맵 (rev2) — 고양이놀이터
0) 전제 / 운영 원칙

전제: AI 실행+검증+분석, 사용자는 EP 컨펌 + 머지 컨펌만 수행.

기준: 1인 PM/개발자 풀타임, 자동화/회귀 테스트 중심(런치 사고 최소화).

SSOT 앵커(필수 참조):

EP/PR 운영: docs/PROCESS.md

검증 게이트: docs/VERIFICATION.md

권한/공개/차단 정책 원문: docs/AUTHZ-MODEL.md §0 (다른 곳 복붙 금지)

API/RPC 계약 + Transport Adapter 매핑: docs/API.md

확정 원장: docs/DECISIONS.md (특히 D-049, D-050, D-071, D-072, D-073, D-066)

1) 로드맵 실행 규약 (EP가 “기계적 반복”이 되기 위한 고정 규칙)
1.1 Work Item ID vs EP-ID

로드맵 항목 표기: 0-1, 1-4 같은 Work Item ID(계획/의존성 표기용).

실제 실행 단위: EP-YYYYMMDD-<slug> (EP-ID, SSOT: docs/PROCESS.md).

원칙:

Work Item 1개 = 기본 1 EP

단, “번들 EP”로 명시된 항목은 1 Work Item = 1~N EP 가능(고위험만 분리).

1.2 EP 공통 DoD(모든 Phase 공통)

EP에는 반드시 포함:

스코프(Allowed/Forbidden paths) + 비목표

Validation: 정확한 커맨드/SQL + 기대 결과(smoke + negative 최소 1)

Evidence: 실행 로그/스냅샷/스크린샷(해당 시) + 변경 파일 목록

머지 조건:

CI green + Evidence 충족 + Public Surface Gate(해당 시) green

1.3 “표준 커맨드” 고정 (로컬/CI 패리티)

실제 커맨드 문자열은 repo 도구(npm/pnpm/bun/make 등)에 맞게 구현하되, 이름/역할은 고정한다. (이 고정이 없으면 EP마다 검증이 흔들림)

Repo Canonical Scripts (반드시 존재해야 함)

repo:lint

repo:typecheck

repo:test (단위/통합 포함 가능)

db:reset (reset → migrate → seed)

db:smoke (최소 smoke SQL 실행)

ci:verify (lint + typecheck + test + db 루프)

ci:public-gate (G-1~G-4, SSOT: docs/VERIFICATION.md)

ci:drift (DCI-* 계열, SSOT: docs/VERIFICATION.md)

원칙:

로컬에서도 CI와 동일한 스크립트 이름으로 검증한다.

EP의 Validation 섹션에는 위 스크립트 중 무엇을 돌렸는지 “정확히” 적는다.

1.4 Environment Matrix 고정 (dev/staging/prod)

값 자체(도메인/키)는 프로젝트별로 달라서 모름. 대신 “기입해야 할 필드”를 고정해 재현성을 확보한다.

환경 3종(dev/staging/prod) 공통 기록 항목(필수)

Supabase: project ref, anon key, service role key 저장 위치(server-only), DB connection

Auth/OAuth: provider별 redirect URI, Expo scheme/deeplink host, 웹 콜백 URL

Web: Next.js domain, ISR revalidate secret 저장 위치(server-only), robots/sitemap base URL

Storage: bucket 이름/정책(원본 private, 파생본 public 등은 D-072 기준), CDN/서명 URL 정책

Jobs/Cron: prod에서만 on/off 여부, 관측(runbook) 최소

Observability: Sentry/로그/알림 채널(있다면)

기록 위치(권장): docs/playbooks/ops-app-config.md에 § Environment Matrix 섹션 추가.

1.5 Transport Adapter(에러/상태코드 매핑) 고정

규약 SSOT: DECISIONS D-071, D-065, 매핑 테이블 SSOT: docs/API.md

구현 원칙:

DB RPC는 JSON return 패턴 유지

외부 표면(앱 wrapper / 웹 route handler)에서 error_code → HTTP/UX로 변환

D-050(404 통일)은 공개 표면에서 강제

2) EP 사이클 (전 Phase 공통)

사용자: Phase 시작(or 개별 EP 지시)
↓
어시스턴트: EP 작성(스코프/변경경로/DoD/검증/fixture)
↓
사용자: 컨펌(or 수정지시)
↓
AI 실행자: 구현 → 테스트 실행 → PR + Evidence
↓
CI: 회귀 + lint/typecheck 자동 → green/red
↓
어시스턴트: PR diff + Evidence + CI 분석 → 통과/수정 판정
↓
사용자: 머지 컨펌
↓
다음 EP

사용자 터치포인트: EP 컨펌 + 머지 컨펌 (+ UI는 실기기 눈 확인)

Phase 0 — Infra + Spine (DB 스파인 정체성 유지)

목표: 이후 모든 EP가 “기계적 반복”이 되도록 기반을 한 번에 깔기.
원칙: DB/CI/fixture/guard/RLS 외에는 섞지 않는다(앱 OAuth 작업은 Phase 0.9).

0-1. 모노레포 + 공용 경계 + 표준 커맨드 스켈레톤

구조: 앱(Expo) / 웹(Next.js) / 공용(shared) / supabase

공용(shared):

타입/에러코드 enum/DTO whitelist 타입(“공개 응답은 whitelist만” 코드 레벨 강제)

(선택) Transport Adapter 공용 타입(매핑 테이블은 docs/API.md가 SSOT)

Expo: 탭 4개 스텁(라우팅만)

Web: SEO 라우트 스텁(라우팅만)

Repo Canonical Scripts 생성(§1.3의 이름/역할 고정) + CI가 이 스크립트만 호출하도록 세팅

0-2. Supabase 로컬/CI 루프 고정

로컬 표준화: db:reset(reset → migrate → seed) → db:smoke

CI에 동일 루프 등록: PR마다 자동 검증(“CI green = 컨펌 근거”)

0-3. DB 전체 마이그레이션(스키마/인덱스/제약) 번들

마이그레이션을 3~4개 EP로 분할(대형 파일 하나로 몰지 않음)

각 EP 필수:

smoke SQL

rollback(또는 안전한 revert 경로)

lock/statement timeout 적용

변경 영향(핫패스 인덱스/제약) 간단 요약

0-4. 회귀 테스트(기반) + fixture seed

드리프트 차단 테스트(최소):

사용자 조인 규약 위반 탐지

운영 파라미터 whitelist 스냅샷(SSOT: CONFIG-BASELINES.md 키셋)

공개 DTO 금지 필드 스냅샷(누출 0)

Public Surface Gate(G-1~G-4) 스켈레톤 등록(SSOT: VERIFICATION.md)

Phase 1 첫 공개 RPC 들어오기 전까지 CI에서는 skip

1-4에서 즉시 “진짜 게이트(머지 조건)”로 활성화

표준 fixture seed:

User A/B/C/D(약관 동의/미동의 포함), 차단 관계 포함

공개 post/thread 샘플

토픽 2개

운영 파라미터 seed

0-5. 코드젠 + 공용 패키지 경계 강제

DB 타입 코드젠 자동화(스크립트화, CI 포함)

공용 패키지 내부 경계 강제(예: domain vs api)

“공개 응답 = whitelist”를 타입 + 테스트로 동시 강제

0-6. Environment Matrix 문서화 스켈레톤(값은 Phase 0.9에서 채움)

docs/playbooks/ops-app-config.md에 § Environment Matrix 섹션 추가

dev/staging/prod “필드”를 고정(§1.4)하고 값은 모름(프로젝트별) 상태로 placeholder

Phase 0 산출물

모노레포 + 전체 스키마 + guard/RLS + CI 루프 + fixture + 드리프트 차단 테스트 + Public Gate 스켈레톤 + 표준 커맨드 + Env Matrix 템플릿

Phase 0 종료 DoD (Phase 1 진입 조건)

Write RPC 공통 가드(terms) 전제는 D-073 준수:

pre-terms write 예외는 딱 2개(agree_terms, set_initial_nickname)

v1 SEO 웹은 anon-only surface로 고정(로그인 세션 미지원)

원칙 확정: write는 RPC만, 가드/필터 필요한 read도 RPC 우선(테이블 직접 접근 금지)

CI에서 ci:verify가 항상 재현 가능(로컬/CI 패리티 확보)

Phase 0.9 — Auth 스파이크 (Phase 0 ↔ Phase 1 브릿지, 1 EP)

목표: Phase 2에서 터지면 전체가 멈추는 OAuth/딥링크/세션 리스크를 UI 없이 조기 발견.
원칙: DB 스파인과 분리.

Phase 2 진입 게이트(AS-1~AS-5, 근거/상세는 VERIFICATION 게이트로 이동):
- AS-1: (최대 3) 로그인 성공(필수: Apple/Kakao, 옵션: Google)
- AS-2: redirect/deeplink 왕복 성공(외부 인증 -> 앱 복귀)
- AS-3: 세션 생성/저장 확인(앱 재시작 후 복구 포함)
- AS-4: auth-only RPC 1개 호출 성공(세션 유효 증명)
- AS-5: dev/staging/prod 재현 체크리스트(환경별 재현 가능)

0.9-1. Expo 최소 앱에서 “로그인→세션 확인”만

UI 최소(버튼 3개 수준)

프로바이더 범위(SSOT: D-066):

필수: Apple, Kakao

옵션: Google(시간/필요 시)

Email/password는 복구 채널로 유지(스파이크에서는 “가능하면” 확인)

로그인 경로에서 확인(필수):

외부 인증 → redirect/deeplink 복귀 성공

Supabase session 생성/저장 확인

auth-only RPC 1개 호출 성공(세션 유효 증명)

0.9-2. 환경별 재현성(체크리스트화)

dev/staging/prod에서 “로그인→세션 확인”을 체크리스트/스크립트로 재현 가능해야 함

Env Matrix(§1.4) 값 채우기: redirect URI / scheme / domain / secret 저장 위치

Phase 0.9 산출물

Auth 리스크(딥링크/리다이렉트/세션 생성) 조기 탐지 + 환경별 재현성 확보

Phase 1 — Core RPC(도메인별) + 회귀 테스트

목표: 백엔드 계약을 도메인 단위로 완성. 각 EP = RPC + 회귀 테스트 묶음.
원칙: docs/API.md 계약 SSOT 유지, Public Surface Gate는 1-4에서 활성화.

1-1. 인벤토리 RPC

switch/discontinue 중심(원장/불변식 유지)

회귀: current 불변식, 전이 규칙, reason 불변(관련 D-075 등)

1-2. 관찰 RPC — 고위험

upsert(멱등) + patch(버전 충돌 409) + inventory_refs 처리

회귀: 멱등 재시도, overwrite 규칙, version_conflict(409), 미래 날짜 방어, payload_version 처리

1-3. 하우스 RPC

슬롯 바인딩/클리어 + 프로필 lazy create

공개 하우스 요약(로그인 전용) + DTO whitelist

회귀: 비허용 필드 누출 0, 조회 불가 404 통일(SSOT: D-050)

1-4. 냥스타 RPC + Public Surface Gate 즉시 활성화 (중요 EP)

posts CRUD + publish/unpublish + comments + like toggle

여기서부터 ci:public-gate가 실제 머지 조건

회귀(SSOT: VERIFICATION.md):

차단 관계에서 공개 결과 0

DTO 누출 0

부모 가드 실패 시 자식 조회 404

조회 불가 404 통일

1-5. 채널 RPC

토픽/스레드/답글 + 팔로우 + 검색(FTS)

피드 3종 + cursor pagination

회귀: 차단/soft_state, 인기 점수, 검색 결과 + noindex 가드레일(정책은 SSOT 참조)

1-6. 운영 RPC

신고 + 차단 + 자동숨김 + 감사로그 + 알림 생성(트랜잭션 내부)

회귀: 중복 신고 방지, 차단 시 상호작용 불가, 자동숨김 임계치, unhide 처리

Phase 1 산출물

v1 RPC + 회귀 테스트 완비 + Public Surface Gate가 머지 조건으로 작동

Phase 2 — App (Expo) (번들 EP, 고위험만 분리)

목표: 화면/플로우 단위 번들로 속도 확보.
원칙: 고위험(관찰 upsert/patch, publish 전이, 차단/신고)은 단독 EP 유지.

2-0. Transport Adapter(앱) 구현 (선행 고정)

SSOT: D-071, docs/API.md Transport Adapter 매핑

앱 클라이언트 wrapper에서 body.error_code 파싱 → typed error로 변환

D-050(404 통일)과 409(version_conflict) UX 매핑 포함

2-1. Auth + 온보딩/세션 운영 (고위험 트랙)

Phase 0.9 위에 온보딩(약관 동의 → 초기 닉네임 설정) 얹기(SSOT: D-073)

세션 유지/복구(재시작/백그라운드/만료/갱신) UX 완성

권장 분할:

EP-a: 로그인/로그아웃 + 세션 생성/저장/복구(실기기)

EP-b: 세션 만료/갱신/에러 케이스(네트워크/취소)

EP-c: 온보딩 통과 후 “일반 write 가능”까지 연결

2-2. 하우스 플로우 번들

2D 씬은 v1에서 표시 중심(placeholder 에셋) 허용

슬롯 편집 + 인벤 관리 + 공개/발행 설정 + 공개 하우스 보기(로그인 전용)

2-3. 다이어리 플로우 번들

관찰 작성/저장(upsert) + 수정(patch) + 충돌(409) 처리

log_date 리스트 + 달력 점프

로컬 드래프트 복원

관찰 → 냥스타 CTA

2-4. 냥스타 플로우 번들

피드/상세/작성/발행/발행취소

댓글/좋아요

이미지 업로드(스토리지 → meta)

2-5. 채널 플로우 번들

토픽/팔로우

피드 3종 + cursor

스레드/답글/좋아요

검색(FTS)

닉네임 액션 메뉴

2-6. 설정 + 운영 UI 번들

프로필 편집: bio/avatar 중심

닉네임 변경은 v1 미지원(SSOT: D-051) → “읽기 전용/안내”로 처리

신고/차단 UI

알림(in-app inbox)

Phase 2 산출물

앱 전체 기능 동작. 실기기에서 핵심 플로우 워크스루 가능.

Phase 3 — Web(Next.js) + 썸네일 + 운영 마무리
3-0. Transport Adapter(웹 SSR/ISR) 구현

SSOT: D-071, docs/API.md

Next.js route handler에서 error_code → HTTP 변환(특히 404 통일)

임의 200+에러바디로 노출되는 케이스 제거

3-1. SEO 웹 (anon-only surface)

채널/스레드/공개 글 상세 중심(index)

내부 검색/프로필은 noindex

metadata/robots/sitemap

OG 이미지(공개 썸네일)

3-2. 썸네일 라이프사이클 + revalidate 보안(완성)

SSOT: D-072(파생본 라이프사이클), D-025(SEO 가드레일)
머지 조건(강조): revalidate 보안 불변식 + 네거티브 테스트는 CI/검증 게이트에서 실패 시 머지 불가로 취급한다.

publish → 생성

unpublish/hide/delete/private 전환 → 삭제 + ISR revalidate

삭제/재검증 트리거 메커니즘은 D-072 기준(비동기 처리 포함)

revalidate 보안 DoD:

server-only secret

allowlist(or tag 기반)만 허용

임의 경로 revalidate 금지(401/403 보장)

3-3. 스케줄드 작업 + 운영 파라미터

cleanup/retention/집계 보정 잡 등록

운영 파라미터 seed/조회 검증

레이트리밋 동작 확인

3-4. “프로덕션 준비 사전 점검” (배포 리스크 전진 배치)

PITR 활성화 여부/복구 시나리오 최소 확인(런치 직전에 처음 하지 않기)

prod에서 cron/job on/off 기준 고정 + 관측 최소(runbook 수준)

Phase 3 산출물

SEO 웹 완성 + 썸네일/재검증 파이프라인 + cron/ops 가동 + prod 준비도 상승

Phase 4 — QA + 런치 (Release-Train: 외부 공개는 마지막에 한 번)
4-1. 자동 QA

회귀 테스트 풀스위트 + 누락 보강

CI 최종 green 확인(특히 Public Surface Gate)

4-2. 실기기 + 웹 최종 확인

앱 전체 플로우 워크스루

SEO 웹 크롤 시뮬레이션(robots/noindex/404/OG)

썸네일 직링크 404(비노출 전환 후) 확인

4-3. 배포

프로덕션 migration 적용

앱/웹 배포

런치 체크리스트 수행(SSOT: VERIFICATION.md)

Phase 4 산출물

v1 출시(한 번에 공개).

5) 의존성(요약 매트릭스)

Phase 1 진입: Phase 0 DoD 충족 + 0.9 Auth 스파이크 완료(환경별 재현성)

Public Surface 확장/SEO 라우트 확장: ci:public-gate green이 머지 조건

App/Web에서의 상태코드/UX 일관성: Transport Adapter(2-0, 3-0) 선행 고정

6) 규모 요약(유지)

Phase 0: M / EP 5~7 (+Env Matrix/커맨드 포함)

Phase 0.9: S / EP 1

Phase 1: M / EP 8~10

Phase 2: L / EP 8~12

Phase 3: M / EP 6~8

Phase 4: S~M / EP 3~5

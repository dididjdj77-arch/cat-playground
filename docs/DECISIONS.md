# DECISIONS — 확정(LOCK) 원장

규칙: LOCK만 기록. 변경 시 ADR 필요 여부를 함께 적는다.

## D-001 앱 IA(하단 탭) + 소셜 세그먼트
- 무엇: 하단 탭 4개(하우스/다이어리/소셜/설정). 소셜 세그먼트 2개(냥스타그램, 채널). (추후) 알림, 내 활동.
- 의미: 도메인(기록 vs 공개)을 구조적으로 분리.
- 영향: 라우팅/권한/캐시 구조 전반.
- 변경: ADR 필요.

## D-002 공개/비공개 혼란 방지: 표면 분리
- 무엇:
  - 다이어리 탭 = 내 것(관찰 + 내 냥스타그램), log_date 기준 그룹
  - 소셜/웹 = 공개 + 발행된 것만 탐색/상호작용
- 의미: “이게 공개냐?” 혼란을 설계로 제거.
- 영향: 노출 정책이 앱/웹/서버 공통 규칙.
- 변경: ADR 필요(노출 사고 리스크).

## D-003 다이어리 탭 UX(인라인 2패널 + B1)
- 무엇:
  - 상단 인라인 작성 패널 2개(관찰/내 냥스타), 기본 접힘, 저장 시 자동 접힘
  - 하단 날짜 헤더 그룹 리스트(B1), log_date 기준
  - 과거 날짜 작성 시 과거 섹션으로(최신 취급 금지)
  - 달력은 다이어리 탭 안에서만(한 페이지), 점프용
- 의미: 라이트 입력 + 회고 정합성.
- 영향: 리스트 페이징/가상화 필요.
- 변경: ADR 권장.

## D-004 드래프트 정책(로컬-only)
- 무엇: 드래프트는 로컬 저장만. 서버 반영은 저장 버튼 시점.
- 의미: 서버 복잡도↓, 입력 손실↓.
- 영향: 멀티디바이스 동기화는 v2 선택.
- 변경: ADR 권장.

## D-005 관찰(다묘) 핵심: C2/D2/E2 + 표현/저장 분리
- 무엇:
  - 일괄작성(멀티 체크) + 개별작성(싱글) 모두 지원
  - 공통 입력 + 고양이별 override 옵션
  - UI는 날짜당 1카드처럼, 저장은 고양이별 N 레코드
  - 제외는 삭제가 아니라 excluded 상태(숨김 + 복구)
- 의미: 다묘 UX/정합성의 핵심.
- 영향: 원자적 저장/재시도/동시성 제어 필수.
- 근거(축약, from ADR-002): 그룹/아이템 분리 + Upsert(전체)/Patch(부분) 분리 + 트랜잭션 + idempotency key + version 기반 409 충돌 처리.
- 변경: ADR 필요.

## D-006 하우스(집) 탭 방향
- 무엇:
  - 하우스 탭 = 2D 거실(방 1개, room_key='living_room') 씬 + 슬롯 기반 배치 UI.
  - 하우스는 "등록된 고양이 현황 + 슬롯 기반 장착(배치) 현황"을 보여준다.
  - 인벤토리 원장 변경/히스토리 관리는 하우스와 분리된 '냥벤토리 관리' 플로우에서만 수행한다.
  - 슬롯은 **배치(연결)**이며, 인벤토리 히스토리 이벤트가 아니다(원장 상태/히스토리 변경 없음).
  - 슬롯에서 선택 가능한 인벤토리는 **is_current=true만**(현재 사용중만).
  - v1 living_room의 slot_key는 opaque id를 사용: slot_01..slot_08 (v1 기본 8개)
  - 근거: v1 UI 디자인(앵커/거점 8개)을 기준으로 한다.
  - 확장 정책: 슬롯 수/배치는 "서버 허용 리스트 + 클라이언트 씬 config"를 동시 업데이트하여 조정한다(임의 변경 금지).
- 의미: 하우스(상태/전시) vs 다이어리(빈번 입력) vs 인벤 원장(관리) 분리.
- 영향:
  - 공개 정책은 D-018을 따른다(공개는 슬롯 장착 요약만; 인벤 원장 owner-only 유지).
  - ROUTES/API/QA에서 "슬롯=배치(히스토리 아님)" + "current-only 선택"을 강제해야 한다.
- 변경: ADR 권장.

## D-007 내 냥스타그램 상태 모델(V2 + N1)
- 무엇:
  - log_date 선택(기본 오늘)
  - visibility(private/public)
  - published_at(null/ts)
  - 노출: public AND published_at not null AND not hidden
  - 발행/발행취소: published_at set/unset
  - 불변식: visibility='private' 인 경우 published_at은 항상 NULL이어야 한다(금지 조합: private + published_at NOT NULL)
  - 전이 규칙: visibility를 private로 변경하는 시점에 published_at=NULL을 강제한다(서버/RPC에서 정리 + DB CHECK로 방어)
- 의미: 공개 의도와 발행 의도를 분리해 안전한 공개 UX.
- 영향: 인덱스/쿼리 기준이 2축(log_date/published_at).
- 변경: ADR 필요.

## D-008 냥스타그램 v1 상호작용
- 무엇: 좋아요 + 댓글 CRUD(수정 포함).
- 의미: 커뮤니티 최소 완결.
- 영향: 운영 장치(신고/차단/레이트리밋) 필수 결합.
- 변경: ADR 권장.

## D-009 댓글 수정 정책(현업 표준형)
- 무엇: 시간 제한 없음 + “수정됨” 표시 + 내부 감사로그(이전 본문 1개 보관). 사용자에게 이력 UI는 제공하지 않음.
- 의미: UX 단순 + 분쟁 대응 최소 기반.
- 영향: comment_revisions 등 감사로그 필요.
- 변경: ADR 권장.

## D-010 log_date 방어(미래 금지)
- 무엇: log_date는 오늘 이하만 허용. 극단 과거 허용.
- 의미: 정렬/통계/회고의 일관성.
- 영향: “미래 계획”은 schedule_date 같은 별도 도메인으로 분리해야 함.
- 변경: ADR 필요.

## D-011 SSOT 운영 방식
- Status: Updated 2026-02-04 (remove TODO SSOT, switch to EP-ID + PR)
- 무엇:
  - SSOT: CONTEXT / INDEX / DECISIONS / OPEN (+ ADR/* 필요 시)
  - Work unit: EP-ID + PR (Execution Packet 기반). TODO 문서는 사용하지 않는다.
  - 회차 종료 체크(3줄):
    1) DECISIONS: 신규 D-### 추가/정정 반영 여부
    2) OPEN: 상태 갱신(Resolved → D-### 링크) 반영 여부
    3) PR: EP-ID ↔ PR 링크(또는 PR 본문 Result Packet) 기록 여부
- 의미: “결정(DECISIONS) / 미정(OPEN) / 근거(ADR) / 실행(EP/PR)”를 분리해 누락과 재논의를 줄인다.
- 영향:
  - 구현/문서 변경은 EP 단위로만 진행한다(EP 없이 임의 변경 금지).
  - 근본적 방향 전환은 ADR로 근거를 남긴다(Template 준수).


## D-012 AC-3 정규화(자동완성/추천/제안큐/승인 UI)
- 무엇:
  - 자동완성 목록 → 없으면 자유입력 허용(막지 않음)
  - 자유입력 시: 기존 항목 매핑 추천 OR 신규 등록 요청(pending)
  - 관리자 UI: pending 승인/거절, 별칭 등록, 병합(최소)
  - 데이터: catalog_items / catalog_aliases / catalog_suggestions + raw_text 보존
- 의미: 입력 마찰 없이 데이터 자산화.
- 영향: 운영 UI/정책/권한 필요.
- 변경: ADR 필요.

## D-013 채널 v1 범위(Blind 벤치마킹, 익명성 제외)
- 무엇: 글/답글(1-depth)/좋아요/검색 + 인기/최신/팔로잉 + 토픽 팔로우.
- 의미: 커뮤니티 축적/탐색 엔진을 v1부터 확보.
- 영향: 검색/집계/운영 장치 필수.
- 근거(축약, from ADR-001): 검색은 DB FTS로 시작, 검색결과는 noindex. 성능/정합성 위해 cursor pagination, 집계 보정 잡을 둔다.
- 변경: ADR 필요.

## D-014 운영 최소장치 v1
- 무엇: 액션별 레이트리밋 + 신고 + 차단(상호 비노출) + 조건부 자동숨김 + 감사로그.
- 의미: 공개+SEO 환경에서 생존 조건.
- 영향: 정책 레이어/관리 도구 필요.
- 변경: ADR 권장.

## D-015 웹(SEO) 원칙
- 무엇:
  - 웹 목적=SEO 유입
  - SSR/ISR 전제
  - index: 토픽 랜딩/스레드 상세/공개 글 상세
  - noindex: 내부 검색 결과
- 의미: 유입 엔진을 기술/정책으로 고정.
- 영향: 품질 게이트/캐시 재검증 필요.
- 근거(축약, from ADR-003): hidden/deleted 처리(404 통일)는 D-050 기준. SSR/ISR + 품질 게이트.
- 변경: ADR 필요.

## D-016 토픽 전부 공개(SEO 대상)
- 무엇: 채널 토픽은 전부 공개 읽기 가능(웹 색인 대상).
- 의미: 성장 극대화.
- 영향: 운영/부하 리스크 ↑ (D-014/015 필수).
- 변경: ADR 필요.

## D-017 닉네임 중심 탐색 UX(액션 메뉴)
- 무엇: 닉네임 탭 시 즉시 이동이 아니라 메뉴(고양이정보/하우스보기/냥스타그램). 작성글/활동은 추후 확장.
- 의미: Blind류 UX 유지 + 오동작/이탈 감소.
- 영향: 권한/차단/공개 설정에 따른 메뉴 노출 제어 필요.
- 변경: ADR 권장.

## D-018 인벤토리 원장(owner-only) + 공개는 하우스 슬롯 "장착 요약"만
- 무엇:
  - 인벤토리 원장(inventory_items)은 항상 owner-only로 유지한다.
  - 타인에게 공개 가능한 인벤토리 정보는 "하우스 슬롯에 장착된 아이템 요약"으로 제한한다.
  - 인벤토리 전체 목록 공개/프로필 기반 인벤 공개는 v1 범위 밖(추후 필요 시 OPEN→DECISION으로 승격).
  - 요약 노출은 화이트리스트 기반(예: type, 표준명/별칭, 장착 시점 등)이며 자유입력(note/raw_text 등)은 기본 비노출.
- 의미: 프라이버시 경계를 단순화하고 노출 사고 표면을 최소화한다.
- 영향: DATA-MODEL/AUTHZ/RPC(공개 하우스 조회)에서 "슬롯 요약만"을 강제해야 한다.
- 변경: ADR 필요.


## D-019 차단(Block): 상호 비노출 + 상호작용 불가
- 무엇: A가 B를 차단하면 서로 콘텐츠/프로필 비노출, 상호작용 불가.
- 의미: 분쟁/괴롭힘 리스크 최소화.
- 영향: 모든 조회/검색/프로필 공통 필터.
- 변경: ADR 권장.

## D-020 공개글 프로필 노출 분리: hide_from_profile
- 무엇: 공개+발행 글이라도 프로필 목록에서는 숨길 수 있음(피드/링크는 공개 유지). 문구로 명확화.
- 의미: “공개”와 “프로필 진열” 니즈 분리.
- 영향: 상태 조합 증가 → UX 명확화 필수.
- 변경: ADR 권장.

## D-021 내부 검색 결과 noindex
- 무엇: 검색 결과 페이지는 noindex.
- 의미: 얇은 페이지/중복 색인 방지.
- 영향: SEO 품질 유지.
- 변경: ADR 권장.

## D-022 관찰 저장 가드레일(심화)
- 무엇: Upsert(전체)/Patch(부분) 분리 + 트랜잭션 + idempotency + version 충돌(409).
- 의미: 재시도/동시편집/부분편집에서 데이터 찢김 방지.
- 영향: group.version / expected_version 필요.
- 근거(축약, from ADR-002): 그룹/아이템 분리 구조에서 멱등성과 version 기반 충돌 처리로 데이터 정합성 보장.
- 변경: ADR 필요.

## D-023 채널 기술 가드레일(심화)
- 무엇: 
  - 피드 3종 쿼리/캐시 분리, cursor pagination, FTS 인덱스, likes unique + 카운트 보정 잡.
  - 검색(v1): Postgres FTS(tsvector(title+body) + GIN)로 시작한다.
  - 한국어 대응(v1): 공백 기준 토큰화 + pg_trgm 보조 인덱스로 부분일치(부분검색/오타 내성)를 보완한다.
  - Known limitation(v1): 형태소 분석 없이 "사료" 검색이 "고양이사료"에 미매칭될 수 있다(품질 한계 인정).
  - 확장 경로: pgroonga 또는 외부 검색(MeiliSearch/Typesense) 도입은 ADR로만 수행한다(백엔드 교체 가능).
  - 계약 고정: 검색 RPC 시그니처/응답 DTO는 백엔드 교체와 무관하게 유지한다.
- 의미: v1에서 성능/정합성/운영 리스크 최소화.
- 영향: 집계/보정 작업 설계 필요.
- 변경: ADR 권장.

## D-024 자동숨김 가드레일(심화)
- 무엇: 신고 임계치 조건 충족 시 hidden_at만 설정(삭제 금지). 정책은 설정값화. 감사로그 필수.
- 의미: 신고 악용/운영 사고 방지.
- 영향: 수치(임계치/신뢰조건)는 D-054 기준(운영 파라미터는 D-056).
- 변경: ADR 권장.

## D-025 SEO 가드레일(심화)
- 무엇: SSR/ISR + index 범위 제한 + 품질 게이트(스팸/hidden 제외) + 이벤트 기반 재검증 트리거.
- 의미: SEO를 “기술+운영”으로 보장.
- 영향: hidden/deleted의 404 통일 전략은 D-050 기준.
- 변경: ADR 권장.

## D-026 공개 부하/스크래핑 대응 여지
- 무엇: 공개 페이지는 CDN/ISR 캐시 가능 형태로 설계. 공개 API/인증 API 분리. 필요 시 WAF/봇 룰 확장 여지.
- 의미: 성장 엔진 부하를 인프라로 흡수.
- 영향: 배포/캐시 정책 문서 필요.
- 변경: ADR 권장.

## D-027. SSOT 문서 자동 PR 규칙
- SSOT 문서 변경은 D-### 결정 키를 기준으로 수행한다(헤딩 전체 텍스트 일치에 의존하지 않는다).
- 동일 요청을 여러 번 실행해도 동일 PR을 반환해야 한다(멱등성).
- GitHub Contents API는 대상 브랜치의 최신 sha 기준으로 처리한다.
- sha mismatch(409) 발생 시 최신 sha 재조회 후 1회 재시도한다.

## D-028. Payload Version State Machine + KPI
- 무엇:
  - Observation payload는 payload_version을 가진다(Contract 식별자).
  - payload_version 상태 머신을 둔다: ACTIVE / DEPRECATED / REJECT.
  - 저장 허용 범위:
    - ACTIVE: 저장 허용.
    - DEPRECATED: 저장 허용(단, 집계/상품 API는 정규화 단계 통과 후만 반영).
    - REJECT: 저장 거부(400).
  - 집계 로직:
    - 모든 입력(version)은 집계 전에 normalize_to_active(version)로 ACTIVE 스키마로 정규화 후 집계한다.
    - 정규화 불능 시: 해당 입력은 집계에서 제외하고 normalize_fail_count를 증가시킨다.
  - KPI(운영 지표):
    - last_seen_at, reject_count, normalize_fail_count를 수집한다.
    - 고QPS에서 단일 row 카운터 UPDATE로 인한 경합이 생기지 않도록, KPI는 “이벤트 로그 → 롤업” 방식 구현을 허용한다(세부는 ADR로 정의).
- 의미: Contract/검증 레이어를 “문서”가 아니라 운영 가능한 시스템으로 만든다(구버전 앱 생존 대응).
- 영향: payload_versions 메타 및 normalize 파이프라인(ETL/함수) 정의가 필요.
- 변경: ADR 필요.

## D-029. Common Filter Guard
- 무엇:
  - 외부·공개·상품성 데이터 제공은 “집계 RPC 단일 경로”만 허용한다(원본 테이블 직접 노출 금지).
  - 모든 집계/공개 RPC 내부에서 공통 필터를 강제한다:
    - guard_soft_state(): deleted/hidden 등 soft-state 필터
    - guard_block(): block 관계(상호 비노출) 필터
  - 필터 누락을 방지하기 위해, CI에 “차단 관계 스냅샷 테스트(0 rows)”를 포함한다.
- 의미: 경로 추가/확장 시에도 개인정보/노출 사고를 구조적으로 방지한다.
- 영향: guard 함수(또는 동등 로직)의 재사용 구조 + 테스트가 필요.
- 변경: ADR 권장.

## D-030. JSONB Meta Promotion Rule
- 무엇:
  - JSONB meta 포켓은 임시 확장 슬롯이며, 최종 안식처가 아니다.
  - meta → 컬럼 승격(Promotion) 시 규칙:
    1) 1회성 백필(back-fill) 스크립트를 실행해 기존 row의 meta 값을 컬럼으로 채운다.
    2) 승격된 meta 키는 “읽기-전용(readonly)”으로 전환한다(쓰기 금지).
       - 구버전 클라이언트 호환이 필요하면, 제한된 기간 동안 서버가 해당 키 입력을 수용하되 컬럼으로 canonicalize하고 meta에서 제거한다.
    3) 승격 이후 SSOT는 컬럼이며, dual-write(컬럼+meta 동시 유지)를 금지한다.
- 의미: 초기 유연성은 유지하되, 시간이 지날수록 쿼리/인덱스/집계 비용이 폭발하는 것을 막는다.
- 영향: 승격 템플릿(migrate_meta_key)과 운영 절차(백필/동결/검증)가 필요.
- 변경: ADR 필요.

## D-031. SSOT 우선순위 체계 (협업 프로토콜)
- 무엇: 모든 설계/구현 판단은 SSOT(등록 문서) > DECISIONS(LOCK) > 대화 LOCK 순으로 해석한다. 충돌 시 자동 결론 금지, 차이/영향을 제시한 뒤 질문으로 해소한다.
- 의미: “문서가 진실”이며, 대화/PR/실행자는 문서를 따른다. 임의 추측/임의 결론은 신뢰 사고로 취급한다.
- 영향: 불확실성은 모름/⚠가설/OPEN으로 명시한다. 실행자(데이터 플레인)도 동일 규칙을 따른다.
- 변경: ADR 필요.

## D-032. 고위험 판정 원칙 (영향도 기반)
- 무엇: 고위험은 키워드가 아니라 영향도(Blast radius)와 롤백 가능성으로 판단한다. 아래 6문항 중 하나라도 “예/의심”이면 PRECISE 우선:
  1) 롤백 난이도(되돌리기 비용/다운타임/복구 난이도)
  2) 데이터 유실/오염 가능성(대량 UPDATE/DELETE/정합성 훼손)
  3) 공개/비공개 경계 변화(anon 접근, SEO 노출, 공개 URL/스토리지)
  4) 권한/정책 변화(RLS, SECURITY DEFINER RPC, 우회 가능성)
  5) 스키마/마이그레이션 성격(컬럼/인덱스/제약/키 변경, 백필성 작업 포함)
  6) 외부/클라이언트 영향(API 계약, 앱/웹 동시 영향, 캐시/검색 영향)
- 의미: 본질적 위험을 먼저 판정하고, 안전장치/검증/롤백을 설계에 포함한다.
- 영향: PRECISE는 최소 안전장치(DoD/검증/롤백)를 반드시 포함한다. FAST도 PR/스모크/체크리스트로 되돌리기 가능성을 확보한다.
- 변경: ADR 필요.

## D-033. 컨트롤/데이터 플레인 분업
- 무엇: 컨트롤(사용자+어시스턴트)은 설계/검증/승인, 데이터(omoc/Claude Code 등 실행자)는 컨트롤이 정한 스코프/금지/DoD 범위 내 구현 + PR 산출을 담당한다. SSOT 충돌/불확실 시 임의 결론 대신 질문으로 멈춘다.
- 의미: 판단(설계)과 실행(구현)을 분리해 안정성과 속도를 동시에 확보한다.
- 영향: Execution Packet(작업 지시서) 템플릿/PR 루프는 OPEN(미결정)과 DECISIONS(확정)로 관리하고, 필요 시 ADR로 근거를 남긴다.
- 변경: ADR 필요.

## 해소된 충돌(근거)
- 채널 v1 범위: “답글/좋아요/검색까지 포함” 사용자 확정 발언으로 D-013 고정.
- 닉네임 이동 UX: “바로 페이지 이동 아님, 메뉴로” 사용자 확정 발언으로 D-017 고정.




## D-034. DECISIONS 운영 규칙 개정(번호 고정 + 내용 수정 허용)
- 무엇:
  - D-### 번호는 "영구 할당"이며 재사용 금지.
  - 기존 D-###의 "내용 수정"을 허용한다(오타/명확화/정정/정보 업데이트 포함).
  - 삭제는 금지한다(참조 안정성). 필요 시 해당 D 항목 상단에 Status를 표시한다:
    - Status: active | superseded
    - See: ADR-### 또는 관련 D-### 링크
  - 근본적 방향 전환(정책/권한/아키텍처 패턴 변경)은 ADR로 근거를 남긴다.
  - Git commit 메시지에 변경 이유(Reason)를 남긴다(문서는 현재 상태 우선, 이력은 Git이 관리).
- 의미: 문서는 "현재 상태"가 명확한 것이 최우선이며, 변경 이력은 Git이 담당한다.
- 영향:
  - append-only를 강제하는 CI/린트가 있다면, "삭제/번호 재사용 금지" 중심으로 규칙을 조정한다.
- 변경: ADR 필요 시 추가.

## D-035. 하우스 공개 상태 모델(visibility + published_at)
- 무엇:
  - 하우스 공개 모델은 visibility + published_at 패턴을 사용한다:
    - house_profiles.visibility: private | public
    - house_profiles.published_at: timestamptz | null
  - 타인 노출 조건은 아래를 **모두** 만족해야 한다:
    - house_profiles.visibility = 'public'
    - house_profiles.published_at IS NOT NULL
    - house_profiles.deleted_at IS NULL AND house_profiles.hidden_at IS NULL
    - viewer/target 간 block 관계 아님(로그인 viewer 기준)
  - 접근 정책(LOCK): 공개 하우스 조회는 auth-only(로그인 사용자만)이다.
  - 보안 UX(LOCK): 미인증/비공개/숨김/삭제/차단/미발행은 모두 404로 통일한다(존재 은닉).
  - 비고: 로그인 필요 메시지는 UI 레이어에서 처리한다.
- 의미: "공개 설정"과 "발행(노출 허용)"을 분리해 노출 사고를 줄인다.
- 영향: AUTHZ/RLS/RPC/QA에서 위 조건을 동일한 불리언 식으로 강제해야 한다.
- 변경: ADR 필요.

## D-036. 하우스 공개 ≠ 인벤토리 공개(슬롯 요약만 노출)
- 무엇:
  - inventory_items(인벤 원장)는 항상 owner-only로 유지한다(D-018 유지).
  - 타인이 볼 수 있는 인벤 관련 정보는 "하우스 슬롯에 장착된 아이템 요약(화이트리스트)"로 제한한다.
  - 하우스 공개/발행은 "하우스 페이지 노출 허용"이지, 인벤 전체 목록 공개 스위치를 도입하지 않는다(v1).
- 의미: 프라이버시 경계를 단순화하고 노출 사고 표면을 최소화한다.
- 영향: 공개 하우스 RPC/DTO는 화이트리스트 반환만 허용한다(금지 필드는 D-037 및 D-055 참고).
- 변경: ADR 필요.

## D-037. 공개 하우스 응답에서 고양이 사진(avatar_url) 금지
- 무엇:
  - 공개 하우스 응답/뷰/DTO에는 cats.avatar_url을 **절대 포함하지 않는다**.
  - 공개 화면의 고양이 렌더는 breed 기반 기본 아바타(or generic)만 사용한다.
- 의미: join/컬럼 확장 실수로 발생하는 치명적 누출을 구조적으로 차단한다.
- 영향: RPC/뷰에서 화이트리스트를 강제한다("select *" 금지).
- 변경: ADR 필요.

## D-038. 인벤토리 타입 v1 고정(정식 코드)
- 무엇:
  - inventory_items.type은 v1에서 고정된 정식 코드 목록을 사용한다.
  - v1 정식 코드 목록(SSOT):
    - food (간식 포함)
    - litter
    - toy
    - medicine (영양제 포함)
    - furniture (캣타워/침대/스크래처 포함)
  - v1 제외(v1.1 후보): grooming, carrier, accessory
  - 확장 규칙: 타입 추가는 DECISIONS/ADR + DB 제약 + 앱/서버 enum 동시 반영(부분 반영 금지).
- 의미: 타입 변경은 UX/통계/검색/카탈로그에 파급이 크므로 v1에서 변동을 제한한다.
- 영향: DATA-MODEL 문서에 타입 목록 명시 필요.
- 변경: ADR 필요.

## D-039. 공개 하우스는 스냅샷 미채택(현재 상태 기반)
- 무엇:
  - 공개 하우스는 발행 시점 고정 스냅샷이 아니라, 항상 현재 상태(현재 슬롯 바인딩/현재 데이터)를 계산해 노출한다.
  - publish는 "노출 허용 상태 전환"이며 데이터는 실시간(현재) 기준이다.
- 의미: 스냅샷/MV로 인한 동기화/백필/정합성 비용을 v1에서 피한다.
- 영향: 성능 이슈는 OPEN으로 관리하고 v1.1+에서 MV/캐시를 선택한다.
- 변경: ADR 필요.

## D-040. 인벤토리 수정 정책(삭제 없음)
- 무엇: 사용자는 inventory_items를 논리적으로도 삭제하지 않는다(사용자 기능으로 deleted_at 미사용; v1에서는 항상 NULL).
- 정정 방법(LOCK): 잘못된 항목은 is_current=false로 전환하고, 새 항목을 추가한다(append-only).
- UX: 사용자는 "수정"을 수행할 수 있으나, 내부적으로는 새 row 생성으로 처리한다(원장/이력 보존).
- deleted_at 용도: 운영자/데이터 수리 목적의 예약 필드(사용자 노출/로직 미구현).
- 슬롯 영향: inventory_item이 non-current가 되면 D-043 규칙을 적용한다.
- 의미: 이력 보존 + 원장 무결성 유지.
- 영향: UX에서 "수정" 동작은 내부적으로 새 row 추가로 구현해야 한다.
- 변경: ADR 필요.

## D-041. observation idempotency TTL 정책
- 무엇: observation_groups.idempotency_key 중복 검사 유효 기간은 7일로 한다.
- cleanup 동작(LOCK): 7일 경과 observation_groups의 idempotency_key를 NULL로 설정한다.
  - observation 데이터는 유지된다.
  - 동일 key 재요청 시 새 그룹으로 생성된다(멱등 창 종료).
- 구현: 일 1회 cleanup job으로 수행한다(now() 의존 partial unique index로 TTL을 구현하지 않는다).
- 대안(선택): idempotency_history 테이블 분리 시 TTL 후 history row 삭제(ADR로만).
- 의미: 멱등성 보장 기간과 저장 공간 균형.
- 영향: cleanup job 구현 필요.
- 변경: ADR 필요.

## D-042. observation payload 최소 형태 검증(400)
- 무엇: observation upsert/patch RPC 입구에서 payload의 최소 골격(필수 키/타입)을 검증하고 실패 시 400을 반환한다.
- 의미: 잘못된 JSON 저장으로 normalize/롤업 파손을 방지한다.
- 영향: RPC에 입력 검증 로직 추가 필요.
- 변경: ADR 필요.

## D-043. current 변경 후 슬롯 노출 규칙
- 무엇: 슬롯 저장 시점에는 is_current=true만 장착 가능하다.
- 이후 non-current가 되면:
  - 본인 화면: "현재 아이템 아님" 경고 + 교체 유도
  - 공개 DTO: 해당 슬롯은 빈 슬롯으로 취급(요약에서 제외 또는 empty 표시)
- 구현 상세(LOCK):
  - 공개 RPC: house_slots JOIN inventory_items 시 공개 허용 조건을 만족하는 row만 결합한다(최소: inventory_items.is_current=true).
    - 조건 불만족이면 JOIN 실패 → 슬롯은 공개 결과에서 제외/empty 처리.
  - DB 저장: house_slots.inventory_item_id는 유지한다(참조 보존).
  - 본인 RPC: is_current와 무관하게 슬롯을 반환하고 non_current 플래그를 포함한다.
- 의미: 슬롯 일관성과 공개 품질 유지.
- 영향: 공개/본인 RPC 로직 분리 필요.
- 변경: ADR 필요.

## D-044. House 보안 UX(존재 은닉)
- 무엇: House 공개 조회 경로의 상태코드는 D-035의 보안 UX 규칙을 따른다.
- 규칙: 미인증/비공개/숨김/삭제/차단/미발행은 모두 404로 통일한다.
- See: D-035
- 의미: 존재 은닉을 통한 프라이버시 보호.
- 영향: 공개 하우스 RPC/API에서 상태코드 통일 필요.
- 변경: ADR 필요.

## D-045. payload_version_events retention
- 무엇: payload_version_events는 90일 보관 후 삭제한다. payload_version_rollups는 영구 보관한다.
- 의미: 이벤트 로그 디스크 폭발 방지 + KPI는 롤업으로 장기 보존.
- 영향: cleanup job 또는 파티션 정책 구현 필요.
- 변경: ADR 필요.

## D-046. like_count 동시성 처리 원칙
- 무엇: like_count 증감은 read-modify-write를 금지하고, 원자 UPDATE로 수행한다.
  - 예: SET like_count = like_count + 1 / SET like_count = like_count - 1
- 의미: 동시 요청에서 lost update를 방지한다.
- 비고: 필요 시(고부하/불일치) 배치 보정 또는 이벤트 기반 롤업으로 확장 가능(ADR로만).
- 영향: 좋아요 토글 로직에서 원자 UPDATE 사용 필요.
- 변경: ADR 필요.

## D-047 Execution/Result Packet 운영 표준
- 무엇:
  - 모든 구현 작업은 Execution Packet(EP) 단위로 진행한다.
  - 각 티켓은 Execution Packet(EP)으로 지시하며, EP는 `docs/PACKET-TEMPLATES.md` 형식을 따른다.
  - 결과 제출은 PR 1개로 하며, PR 본문은 Result Packet 형식(`docs/PACKET-TEMPLATES.md`의 섹션 유지)을 채운다.
  - PR 생성 시 기본 본문은 `.github/pull_request_template.md`를 따른다.
  - EP에는 최소한 Allowed changes / Validation / DoD / Evidence required 를 포함한다.
  - Result Packet에 Evidence(실행한 명령/SQL + 출력)가 없으면 “미검증”으로 간주하고 리뷰를 중단한다(불합격).
- 의미: 스코프 누수와 검증 누락을 구조적으로 방지하고, “지시 ↔ 결과 ↔ 증빙”을 PR diff로 검증 가능하게 만든다.
- 영향:
  - 실행자(omoc 포함)는 EP만 보고 수행 가능해야 하며, PR에는 증빙이 남아야 한다.
  - 작업 분해/우선순위는 EP-ID와 EP에 의해 결정된다.
- 변경: ADR 불필요(프로세스). 단, 규칙 변경은 새 D-###로 남긴다.

## D-048 EP 식별자(EP-ID) 관리
- 무엇:
  - EP 식별자는 EP-ID를 SSOT로 사용한다(예: EP-YYYYMMDD-<slug>).
  - Execution Packet ID는 `EP-<EP-ID>`로 표기한다.
  - PR 제목과 본문(Result Packet)에는 EP-ID를 반드시 포함한다.
  - Result Packet은 `EP-ID`로 추적하며, 별도 “Result 번호”는 두지 않는다.
  - (선택) GitHub Issue를 쓰는 경우, Issue 번호는 참고 링크로만 둔다(SSOT는 EP-ID 유지).
- 의미: 번호 충돌을 방지하고, “지시(EP) ↔ 결과(PR/증빙)”를 1:1로 추적 가능하게 만든다.
- 영향: 새 작업은 EP-ID를 발급한 뒤 EP/PR을 생성한다.
- 변경: ADR 불필요(프로세스). 단, 규칙 변경은 새 D-###로 남긴다.

## D-049: 기술 스택/배포 확정 (O-010 해소)
  - 무엇: 제품 런타임 스택 + 배포 기준선을 확정
  - 결정:
    - App: Expo (React Native)
    - Web(SEO): Next.js (SSR/ISR)
    - Backend: Supabase (Postgres/Auth/Storage/Edge Functions)
    - Search v1: Postgres FTS (tsvector)
    - Deploy: Web=Vercel, App=EAS, Backend=Supabase
    - Dev Executor(옵션): Google Antigravity 사용 가능(필수 아님). Codex/Claude Code 등 실행자는 교체 가능.
  - 의미: 런타임/배포 파이프라인 기준선을 고정하되, 실행자(IDE/에이전트)는 교체 가능하게 유지.
  - 근거: docs/CONTEXT.md에 기재된 스택 가정을 “확정”으로 승격하고, 배포를 명시해 구현/운영 편차를 줄인다.

## D-050. 공개 표면 "조회 불가" 상태코드: 404로 통일(존재 은닉)
- 무엇: 웹/앱의 공개 표면에서 “조회 불가” 상태는 모두 404로 통일한다.
  - 포함: 미인증, 비공개, hidden, deleted, 차단(block), 미발행(unpublished)
  - 제외: (v1) 별도의 "삭제됨 안내 페이지" / 410 / 상태별 다른 코드 분기
- 의미: 존재 여부 누출을 방지하고, 분기 누락으로 인한 노출 사고를 줄인다.
- 적용 지점:
  - 라우트(SSR/ISR)에서 최종 응답은 404로 통일
  - 공개/외부 조회 RPC는 guard 적용 후 “비허용”을 상위 레이어가 404로 매핑 가능하도록 설계(계약으로 고정)
- 영향: Guard/QA에서 “404 통일”을 공통 불변식으로 테스트한다.
- See: D-044 (House 보안 UX), O-003
- 변경: ADR 필요.

## D-051. 닉네임 변경 정책
- 무엇:
  - 닉네임 변경: 허용
  - 이전 닉네임 예약: 1시간 (타인 선점 방지)
  - 리다이렉트: 없음 (이전 닉네임 URL → 404)
- 구현(문서 수준):
  - profiles.nickname_changed_at (권장)
  - 변경 시: “이전 닉네임이 1시간 내 다른 사용자에게 사용되었는지” 체크
  - 1시간 경과 후 이전 닉네임 재사용 가능
- 의미: 닉네임 변경 허용하되 단기간 혼란 방지
- 영향: /u/{nickname}/* 라우트는 404로 존재 은닉 유지 (AUTHZ-MODEL §0 참조)
- 변경: ADR 권장

## D-052. 신고 시점 콘텐츠 스냅샷 (O-024 → D-052)
- 무엇:
  - reports.snapshot (jsonb) 컬럼 추가
  - 신고 INSERT 시 target의 핵심 필드 스냅샷 저장
  - 저장 범위: body, author_id, created_at, updated_at (target_type별 조정)
- 보존: reports 레코드와 동일 수명
- 의미: 신고 후 수정/삭제로 인한 증거 인멸 방지
- 영향: 신고 INSERT 시 1회 추가 조회
- 변경: ADR 불필요 (운영 정책)

## D-053. 레이트리밋 v1 기본값
- 무엇(원칙):
  - 읽기(조회/스크롤)는 제한하지 않는다.
  - 쓰기/신고 등 “행동”만 레이트리밋한다.
  - 분당 + 일간 이중 제한을 사용한다.
  - 신규 계정(가입 24h 이내)은 더 보수적 제한을 적용한다.
- 수치(v1 기본값, 조정 가능 파라미터):
  - posts: 2/min, 20/day
  - comments/replies: 10/min, 200/day
  - likes: 60/min, 1500/day
  - reports: 3/min, 30/day
  - 신규 계정(<=24h):
    - posts: 1/min, 5/day
    - comments/replies: 5/min, 50/day
    - likes: 30/min, 500/day
    - reports: 2/min, 10/day
- 의미: 스팸/도배/신고 악용을 최소 비용으로 억제하면서 정상 UX를 보존.
- 영향: 운영 중 수치 조정은 “코드 상수”가 아니라 config/환경변수 등으로 바꾸는 것이 권장(단, 이 PR에서는 문서만 다룸).
- 변경: ADR 불필요(운영 파라미터). 단 “행동만 제한/읽기 제외” 원칙 변경은 ADR 권장.

## D-054. 조건부 자동숨김(신고 기반) v1 임계치/신뢰 조건
- 무엇:
  - 자동숨김 트리거: 서로 다른 신고자 N명 충족 시
  - N = 5
  - 카운트에 포함되는 신고자 신뢰 조건: 계정 생성 7일 이상 (created_at <= now()-7d)
  - 시간창(window): 24시간 내 신고만 카운트(rolling)
  - 트리거 충족 시: 대상에 hidden_at=now() 처리(삭제 아님)
- 의미: 집단 공격/어뷰즈를 어렵게 하면서, 운영자介入 전 1차 방어선 제공.
- 영향: “신고 INSERT 시 카운트/판정”이 필요(정확 구현은 별도 티켓).
- 변경: ADR 권장(운영 정책/공개 경계 영향).

## D-055. PublicHouseSlotSummaryDTO v1 허용 필드(whitelist)
- 무엇(허용 필드):
  - slot_key
  - equipped_at (nullable)
  - type (inventory_items.type)
  - catalog (nullable object):
    - standard_name
    - brand (nullable)  // 포함
  - days_since_equipped (nullable, 서버 파생필드; equipped_at 있을 때만)
- 금지(명시):
  - inventory_item_id / inventory_items.id 등 내부 id
  - raw_text / note / meta
  - cats.avatar_url 포함 어떤 이미지 URL도
  - catalog_item_id 등 내부 참조 id
- 의미: 공개 하우스는 존재 은닉/프라이버시 경계를 지키면서도 표현에 필요한 최소 정보만 제공.
- 영향: public RPC는 whitelist 고정(서버에서 필드 누수 방지).
- 변경: ADR 불필요(기존 ADR-007 원칙의 구체화). 단 공개 범위 확대는 ADR 필요.

## D-056. 운영 파라미터 저장소: app_config (rate_limits / auto_hide)
- 무엇:
  - D-053 레이트리밋 수치는 운영 중 조정 가능한 파라미터이며 DB의 app_config에 저장한다.
  - D-054 자동숨김 임계치도 운영 중 조정 가능한 파라미터이며 DB의 app_config에 저장한다.
- key(v1):
  - rate_limits
  - rate_limits_new_account
  - auto_hide
- 노출/권한(원칙):
  - app_config 원본 테이블 direct SELECT는 금지(권장).
  - 클라이언트가 필요로 하는 값은 SECURITY DEFINER RPC로만 제공하고, 반환 key는 whitelist로 제한한다.
  - 쓰기(변경)는 서비스/운영 도구(서버 사이드)만 수행한다.
    - (주의) admin 권한을 profiles.is_admin 같은 컬럼으로 판별하는 방식은 O-009 결정 후에만 도입한다.
- 의미: “수치 변경 = 코드 배포”를 피하고, 공개/비공개 경계를 단일 지점에서 통제한다.
- 영향: 014_app_config.sql 마이그레이션(테이블+RPC+seed)이 필요.
- 변경: ADR 불필요(운영 파라미터). 단 공개 범위 확대(anon 노출 등)는 ADR 필요.

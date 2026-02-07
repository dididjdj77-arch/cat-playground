# DECISIONS — 확정(LOCK) 원장
규칙: LOCK만 기록. 변경 시 ADR 필요 여부를 함께 적는다.
## Class 분류 체계

| Class | 의미 | 변경 요건 |
|-------|------|-----------|
| POLICY | 정책/원칙 (What/Why) — 도메인 규칙, 공개/비공개 경계, 권한 모델 | ADR 필요 |
| GUARD | 가드레일/방법론 (How) — 구현 제약, 안전장치, 기술 가드레일 | PR + 근거 |
| CONFIG | 운영 파라미터 (수치) — 튜닝값, 임계치, 기본값 | config 변경 (app_config) |
| PROCESS | 프로세스/워크플로우 — EP 운영, 문서 관리, PR 규칙 | PROCESS.md가 SSOT |

### 운영 규칙
- 모든 D-### 항목은 Class를 명시한다.
- MOVED 항목: `Status`와 이동 경로를 명시하고 최소 stub(3~4줄) 유지.
- Class 정의 자체의 변경: ADR 필요.

## D-001 앱 IA(하단 탭) + 소셜 세그먼트
- Class: POLICY
- 무엇: 하단 탭 4개(하우스/다이어리/소셜/설정). 소셜 세그먼트 2개(냥스타그램, 채널). (추후) 알림, 내 활동.
- 의미: 도메인(기록 vs 공개)을 구조적으로 분리.
- 변경: ADR 필요.

## D-002 공개/비공개 혼란 방지: 표면 분리
- Class: POLICY
- 무엇:
  - 다이어리 탭 = 내 것(관찰 + 내 냥스타그램), log_date 기준 그룹
  - 소셜/웹 = 공개 + 발행된 것만 탐색/상호작용
- 의미: “이게 공개냐?” 혼란을 설계로 제거.
- 변경: ADR 필요(노출 사고 리스크).

## D-003 다이어리 탭 UX(인라인 2패널 + B1)
- Class: GUARD
- 무엇:
  - 상단 인라인 작성 패널 2개(관찰/내 냥스타), 기본 접힘, 저장 시 자동 접힘
- 의미: 라이트 입력 + 회고 정합성.
- 변경: ADR 권장.

## D-004 드래프트 정책(로컬-only)
- Class: GUARD
- 무엇: 드래프트는 로컬 저장만. 서버 반영은 저장 버튼 시점.
- 의미: 서버 복잡도↓, 입력 손실↓.
- 변경: ADR 권장.

## D-005 관찰(다묘) 핵심: C2/D2/E2 + 표현/저장 분리
- Class: POLICY
- 무엇:
  - 일괄작성(멀티 체크) + 개별작성(싱글) 모두 지원
- 의미: 다묘 UX/정합성의 핵심.
- See: docs/ADR/ADR-002-observation-storage.md
- 변경: ADR 필요.

## D-006 하우스(집) 탭 방향
- Class: POLICY
- 무엇:
  - 하우스 탭 = 2D 거실(방 1개, room_key='living_room') 씬 + 슬롯 기반 배치 UI.
  - 슬롯은 배치(히스토리 아님)이며 current-only 선택, slot_key는 허용 목록으로 고정한다.
- 의미: 하우스(상태/전시) vs 다이어리(빈번 입력) vs 인벤 원장(관리) 분리.
- 변경: ADR 권장.

## D-007 내 냥스타그램 상태 모델(V2 + N1)
- Class: POLICY
- 무엇:
  - 상태축: log_date, visibility(private/public), published_at(null/ts)
  - 노출 조건: visibility='public' AND published_at IS NOT NULL AND not hidden
  - 금지/전이: private + published_at 금지, visibility를 private로 바꾸면 published_at=NULL 강제
- 의미: 공개 의도와 발행 의도를 분리해 안전한 공개 UX.
- 변경: ADR 필요.

## D-008 냥스타그램 v1 상호작용
- Class: GUARD
- 무엇: 좋아요 + 댓글 CRUD(수정 포함).
- 의미: 커뮤니티 최소 완결.
- 변경: ADR 권장.

## D-009 댓글 수정 정책(현업 표준형)
- Class: GUARD
- 무엇: 시간 제한 없음 + “수정됨” 표시 + 내부 감사로그(이전 본문 1개 보관). 사용자에게 이력 UI는 제공하지 않음.
- 의미: UX 단순 + 분쟁 대응 최소 기반.
- 변경: ADR 권장.

## D-010 log_date 방어(미래 금지)
- Class: POLICY
- 무엇: log_date는 오늘 이하만 허용. 극단 과거 허용.
- 의미: 정렬/통계/회고의 일관성.
- 변경: ADR 필요.

## D-011 SSOT 운영 방식
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#1-ssot-운영-방식-from-d-011
- 무엇: EP-ID + PR 기반 작업 관리. TODO 문서 미사용.
- 변경: PROCESS.md가 SSOT.

## D-012 AC-3 정규화(자동완성/추천/제안큐/승인 UI)
- Class: POLICY
- 무엇:
  - 자동완성 목록 → 없으면 자유입력 허용(막지 않음)
- 의미: 입력 마찰 없이 데이터 자산화.
- 변경: ADR 필요.

## D-013 채널 v1 범위(Blind 벤치마킹, 익명성 제외)
- Class: POLICY
- 무엇: 글/답글(1-depth)/좋아요/검색 + 인기/최신/팔로잉 + 토픽 팔로우.
- 의미: 커뮤니티 축적/탐색 엔진을 v1부터 확보.
- See: docs/ADR/ADR-001-channel-v1.md
- 변경: ADR 필요.

## D-014 운영 최소장치 v1
- Class: GUARD
- 무엇: 액션별 레이트리밋 + 신고 + 차단(상호 비노출) + 조건부 자동숨김 + 감사로그.
- 의미: 공개+SEO 환경에서 생존 조건.
- 변경: ADR 권장.

## D-015 웹(SEO) 원칙
- Class: POLICY
- 무엇:
  - 웹 목적=SEO 유입
- 의미: 유입 엔진을 기술/정책으로 고정.
- See: docs/ADR/ADR-003-web-seo-v1.md
- 변경: ADR 필요.

## D-016 토픽 전부 공개(SEO 대상)
- Class: POLICY
- 무엇: 채널 토픽은 전부 공개 읽기 가능(웹 색인 대상).
- 의미: 성장 극대화.
- 변경: ADR 필요.

## D-017 닉네임 중심 탐색 UX(액션 메뉴)
- Class: GUARD
- 무엇: 닉네임 탭 시 즉시 이동이 아니라 메뉴(고양이정보/하우스보기/냥스타그램). 작성글/활동은 추후 확장.
- 의미: Blind류 UX 유지 + 오동작/이탈 감소.
- 변경: ADR 권장.

## D-018 인벤토리 원장(owner-only) + 공개는 하우스 슬롯 "장착 요약"만
- Class: POLICY
- 무엇:
  - 인벤토리 원장(inventory_items)은 항상 owner-only로 유지한다.
  - 타인 공개는 슬롯 장착 요약만 허용하며 DTO는 whitelist, raw_text/note/meta는 비노출이다.
- 의미: 프라이버시 경계를 단순화하고 노출 사고 표면을 최소화한다.
- 변경: ADR 필요.

## D-019 차단(Block): 상호 비노출 + 상호작용 불가
- Class: POLICY
- 무엇: A가 B를 차단하면 서로 콘텐츠/프로필 비노출, 상호작용 불가.
- 의미: 분쟁/괴롭힘 리스크 최소화.
- 변경: ADR 권장.

## D-020 공개글 프로필 노출 분리: hide_from_profile
- Class: GUARD
- 무엇: 공개+발행 글이라도 프로필 목록에서는 숨길 수 있음(피드/링크는 공개 유지). 문구로 명확화.
- 의미: “공개”와 “프로필 진열” 니즈 분리.
- 변경: ADR 권장.

## D-021 내부 검색 결과 noindex
- Class: GUARD
- 무엇: 검색 결과 페이지는 noindex.
- 의미: 얇은 페이지/중복 색인 방지.
- 변경: ADR 권장.

## D-022 관찰 저장 가드레일(심화)
- Class: GUARD
- 무엇: Upsert(전체)/Patch(부분) 분리 + 트랜잭션 + idempotency + version 충돌(409).
- 의미: 재시도/동시편집/부분편집에서 데이터 찢김 방지.
- See: docs/ADR/ADR-002-observation-storage.md
- See: docs/playbooks/rpc-owner.md
- 변경: ADR 필요.

## D-023 채널 기술 가드레일(심화)
- Class: GUARD
- 무엇:
  - 피드 3종 쿼리/캐시 분리, cursor pagination, FTS 인덱스, likes unique + 카운트 보정 잡.
- 의미: v1에서 성능/정합성/운영 리스크 최소화.
- See: docs/playbooks/rpc-public.md
- 변경: ADR 권장.

## D-024 자동숨김 가드레일(심화)
- Class: GUARD
- 무엇: 신고 임계치 조건 충족 시 hidden_at만 설정(삭제 금지). 정책은 설정값화. 감사로그 필수.
- 의미: 신고 악용/운영 사고 방지.
- 변경: ADR 권장.

## D-025 SEO 가드레일(심화)
- Class: GUARD
- 무엇: SSR/ISR + index 범위 제한 + 품질 게이트(스팸/hidden 제외) + 이벤트 기반 재검증 트리거.
- 의미: SEO를 “기술+운영”으로 보장.
- 변경: ADR 권장.

## D-026 공개 부하/스크래핑 대응 여지
- Class: GUARD
- 무엇: 공개 페이지는 CDN/ISR 캐시 가능 형태로 설계. 공개 API/인증 API 분리. 필요 시 WAF/봇 룰 확장 여지.
- 의미: 성장 엔진 부하를 인프라로 흡수.
- 변경: ADR 권장.

## D-027 SSOT 문서 자동 PR 규칙
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#2-ssot-문서-자동-pr-규칙-from-d-027
- 무엇: D-### 키 기준 변경 + 멱등성 + sha mismatch 재시도.
- 변경: PROCESS.md가 SSOT.

## D-028. Payload Version State Machine + KPI
- Class: POLICY
- 무엇:
  - Observation payload는 payload_version을 가진다(Contract 식별자).
  - payload_version 상태 머신을 둔다: ACTIVE / DEPRECATED / REJECT.
- 의미: Contract/검증 레이어를 “문서”가 아니라 운영 가능한 시스템으로 만든다(구버전 앱 생존 대응).
- 변경: ADR 필요.

## D-029. Common Filter Guard
- Class: POLICY
- 무엇:
  - 외부·공개·상품성 데이터 제공은 “집계 RPC 단일 경로”만 허용한다(원본 테이블 직접 노출 금지).
- 의미: 경로 추가/확장 시에도 개인정보/노출 사고를 구조적으로 방지한다.
- See: docs/playbooks/rls-and-guards.md
- 변경: ADR 권장.

## D-030. JSONB Meta Promotion Rule
- Class: POLICY
- 무엇:
  - JSONB meta 포켓은 임시 확장 슬롯이며, 최종 안식처가 아니다.
- 의미: 초기 유연성은 유지하되, 시간이 지날수록 쿼리/인덱스/집계 비용이 폭발하는 것을 막는다.
- 변경: ADR 필요.

## D-031. SSOT 우선순위 체계 (협업 프로토콜)
- Class: POLICY
- 무엇: 모든 설계/구현 판단은 SSOT(등록 문서) > DECISIONS(LOCK) > 대화 LOCK 순으로 해석한다. 충돌 시 자동 결론 금지, 차이/영향을 제시한 뒤 질문으로 해소한다.
- 의미: “문서가 진실”이며, 대화/PR/실행자는 문서를 따른다. 임의 추측/임의 결론은 신뢰 사고로 취급한다.
- 변경: ADR 필요.

## D-032 고위험 판정 원칙 (영향도 기반)
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#6-고위험-판정-원칙-from-d-032
- 무엇: 영향도(6문항) 기반 PRECISE/FAST 판정. 안전장치 필수.
- 변경: PROCESS.md가 SSOT.

## D-033 컨트롤/데이터 플레인 분업
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#7-컨트롤데이터-플레인-분업-from-d-033
- 무엇: 컨트롤(설계/검증/승인) vs 데이터(구현/PR). 충돌 시 질문.
- 변경: PROCESS.md가 SSOT.

## D-034 DECISIONS 운영 규칙 개정
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#3-decisions-운영-규칙-from-d-034
- 무엇: D-### 번호 영구 할당, 삭제 금지, 내용 수정 허용, 방향 전환은 ADR.
- 변경: PROCESS.md가 SSOT.

## D-035. 하우스 공개 상태 모델(visibility + published_at)
- Class: POLICY
- 무엇:
  - 상태축: house_profiles.visibility(private|public) + published_at(null|ts)
  - 타인 노출 조건(AND): visibility='public' AND published_at IS NOT NULL AND deleted_at/hidden_at IS NULL AND not blocked
  - 비허용 상태(비공개/숨김/삭제/차단/미발행/미인증)는 404로 통일한다.
  - 공개 하우스 조회는 auth-only(로그인 사용자)로 제한한다(LOCK).
- 의미: "공개 설정"과 "발행(노출 허용)"을 분리해 노출 사고를 줄인다.
- See: AUTHZ-MODEL §0-1
- 변경: ADR 필요.

## D-036. 하우스 공개 ≠ 인벤토리 공개(슬롯 요약만 노출)
- Class: POLICY
- 무엇:
  - inventory_items(인벤 원장)는 항상 owner-only로 유지한다(D-018 유지).
- 의미: 프라이버시 경계를 단순화하고 노출 사고 표면을 최소화한다.
- 변경: ADR 필요.

## D-037. 공개 하우스 응답에서 고양이 사진(avatar_url) 금지
- Class: POLICY
- 무엇:
  - 공개 하우스 응답/뷰/DTO에는 cats.avatar_url을 **절대 포함하지 않는다**(렌더는 기본/대체 아바타 사용).
- 의미: join/컬럼 확장 실수로 발생하는 치명적 누출을 구조적으로 차단한다.
- 변경: ADR 필요.

## D-038. 인벤토리 타입 v1 고정(정식 코드)
- Class: GUARD
- 무엇:
  - inventory_items.type은 v1에서 고정된 정식 코드 목록을 사용한다.
- 의미: 타입 변경은 UX/통계/검색/카탈로그에 파급이 크므로 v1에서 변동을 제한한다(목록은 See DATA-MODEL).
- 변경: ADR 필요.

## D-039. 공개 하우스는 스냅샷 미채택(현재 상태 기반)
- Class: POLICY
- 무엇:
  - 공개 하우스는 발행 시점 고정 스냅샷이 아니라, 항상 현재 상태(현재 슬롯 바인딩/현재 데이터)를 계산해 노출한다.
- 의미: 스냅샷/MV로 인한 동기화/백필/정합성 비용을 v1에서 피한다.
- 변경: ADR 필요.

## D-040. 인벤토리 수정 정책(삭제 없음)
- Class: POLICY
- 무엇: 사용자는 inventory_items를 논리적으로도 삭제하지 않는다(사용자 기능으로 deleted_at 미사용; v1에서는 항상 NULL).
- 의미: 이력 보존 + 원장 무결성 유지.
- 변경: ADR 필요.

## D-041. observation idempotency TTL 정책
- Class: GUARD
- 무엇: observation_groups.idempotency_key 중복 검사 유효 기간은 7일로 한다.
- 의미: 멱등성 보장 기간과 저장 공간 균형.
- 변경: ADR 필요.

## D-042. observation payload 최소 형태 검증(400)
- Class: GUARD
- 무엇: observation upsert/patch RPC 입구에서 payload의 최소 골격(필수 키/타입)을 검증하고 실패 시 400을 반환한다.
- 의미: 잘못된 JSON 저장으로 normalize/롤업 파손을 방지한다.
- 변경: ADR 필요.

## D-043. current 변경 후 슬롯 노출 규칙
- Class: POLICY
- 무엇: 슬롯 저장 시점에는 is_current=true만 장착 가능하다.
- 의미: 슬롯 일관성과 공개 품질 유지.
- See: docs/playbooks/rpc-public.md
- 변경: ADR 필요.

## D-044. House 보안 UX(존재 은닉)
- Class: POLICY
- 무엇: House 공개 조회 경로의 상태코드는 D-035의 보안 UX 규칙을 따른다.
- 의미: 존재 은닉을 통한 프라이버시 보호.
- See: D-035
- 변경: ADR 필요.

## D-045. payload_version_events retention
- Class: GUARD
- 무엇: payload_version_events는 90일 보관 후 삭제한다. payload_version_rollups는 영구 보관한다.
- 의미: 이벤트 로그 디스크 폭발 방지 + KPI는 롤업으로 장기 보존.
- 변경: ADR 필요.

## D-046. like_count 동시성 처리 원칙
- Class: POLICY
- 무엇: like_count 증감은 read-modify-write를 금지하고, 원자 UPDATE로 수행한다.
- 의미: 동시 요청에서 lost update를 방지한다.
- 변경: ADR 필요.

## D-047 Execution/Result Packet 운영 표준
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#4-executionresult-packet-운영-from-d-047
- 무엇: 모든 작업은 EP 단위. Evidence 없으면 불합격.
- 변경: PROCESS.md가 SSOT.

## D-048 EP 식별자(EP-ID) 관리
- Class: PROCESS
- Status: MOVED → docs/PROCESS.md#5-ep-id-관리-from-d-048
- 무엇: EP-YYYYMMDD-<slug> 형식. PR에 EP-ID 필수.
- 변경: PROCESS.md가 SSOT.

## D-049: 기술 스택/배포 확정 (O-010 해소)
- Class: POLICY
- 무엇: 제품 런타임 스택 + 배포 기준선을 확정
- 의미: 런타임/배포 파이프라인 기준선을 고정하되, 실행자(IDE/에이전트)는 교체 가능하게 유지.
- 변경: ADR 필요.

## D-050. 공개 표면 "조회 불가" 상태코드: 404로 통일(존재 은닉)
- Class: POLICY
- 무엇: 공개 라우트/공개 RPC에서 guard 불만족(비공개/숨김/삭제/차단/미인증/미발행) 상태를 모두 404로 매핑한다.
- 의미: 존재 여부 누출을 방지하고, 분기 누락으로 인한 노출 사고를 줄인다.
- 영향: 라우트와 공개 RPC 매핑 테이블/QA 시나리오에서 404 통일을 공통 검증한다.
- See: D-044 (House 보안 UX), O-003
- 변경: ADR 필요.

## D-051. 닉네임 변경 정책
- Class: GUARD
- 무엇:
  - 닉네임 변경은 허용하되 이전 닉네임은 1시간 재할당 금지, /u/{nickname}은 리다이렉트 없이 404 유지.
- 의미: 닉네임 변경 허용하되 단기간 혼란 방지
- 변경: ADR 권장

## D-052. 신고 시점 콘텐츠 스냅샷 (O-024 → D-052)
- Class: GUARD
- 무엇:
  - reports.snapshot (jsonb) 컬럼 추가
- 의미: 신고 후 수정/삭제로 인한 증거 인멸 방지
- 변경: ADR 불필요 (운영 정책)

## D-053 레이트리밋 v1 기본값
- Class: GUARD
- 무엇(원칙):
  - 읽기(조회/스크롤)는 제한하지 않는다.
- 수치: See docs/CONFIG-BASELINES.md#1-rate-limits-d-053
- 의미: 스팸/도배 최소 비용 억제 + 정상 UX 보존.
- 변경: 수치는 CONFIG-BASELINES(config 변경). 원칙 변경은 ADR 권장.

## D-054 조건부 자동숨김(신고 기반) v1 임계치/신뢰 조건
- Class: GUARD
- 무엇(원칙):
  - 자동숨김 트리거: 서로 다른 신뢰 신고자 N명 충족 시 hidden_at 설정(삭제 아님).
- 수치: See docs/CONFIG-BASELINES.md#2-auto-hide-threshold-d-054
- 의미: 어뷰즈 방어 + 운영자 개입 전 1차 방어선.
- 변경: 수치는 CONFIG-BASELINES(config 변경). 정책 변경은 ADR 권장.

## D-055. PublicHouseSlotSummaryDTO v1 허용 필드(whitelist)
- Class: GUARD
- 무엇(허용 필드): slot_key, equipped_at(nullable), type, catalog.standard_name
- 금지(명시): inventory_item_id, raw_text/note/meta, cats.avatar_url, catalog_item_id
- 의미: 공개 하우스는 존재 은닉/프라이버시 경계를 지키면서도 표현에 필요한 최소 정보만 제공.
- 변경: ADR 불필요(기존 ADR-007 원칙의 구체화). 단 공개 범위 확대는 ADR 필요.

## D-056 운영 파라미터 저장소: app_config
- Class: GUARD
- 무엇:
  - 운영 중 조정 가능한 파라미터는 DB app_config에 저장한다.
  - key(v1): rate_limits, rate_limits_new_account, auto_hide
- 원칙/경계: direct SELECT 금지(권장), 읽기=SECURITY DEFINER RPC(whitelist), 쓰기=서버/운영만, 비밀값 금지, 새 key는 D-056+whitelist 선행.
- 의미: 수치 변경을 코드 배포와 분리하고 공개/비공개 경계를 단일 지점에서 통제한다.
- See: docs/playbooks/ops-app-config.md
- See: docs/CONFIG-BASELINES.md#3-app_config-key-매핑-d-056
- 변경: ADR 불필요(운영 파라미터). 공개 범위 확대는 ADR 필요.

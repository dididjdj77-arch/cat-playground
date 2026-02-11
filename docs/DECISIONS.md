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
- 변경: ADR 필요.

## D-006 하우스(집) 탭 방향
- Class: POLICY
- 무엇:
  - 하우스 탭 = 2D 거실(방 1개, room_key='living_room') 씬 + 슬롯 기반 배치 UI.
  - 슬롯은 배치(히스토리 아님)이며 current-only 선택, slot_key는 허용 목록으로 고정한다.
  - v1 living_room slot_key: slot_01..slot_08 (8개 고정)
- 의미: 하우스(상태/전시) vs 다이어리(빈번 입력) vs 인벤 원장(관리) 분리.
- 변경: ADR 권장.

## D-007 내 냥스타그램 상태 모델(V2 + N1)
- Class: POLICY
- 무엇:
  - 상태축: log_date, visibility(private/public), published_at(null/ts)
  - 노출 조건: visibility='public' AND published_at IS NOT NULL AND hidden_at IS NULL AND deleted_at IS NULL
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

## D-037. 공개 하우스 응답에서 고양이 아바타 원본키 노출 금지
- Class: POLICY
- 무엇:
  - 공개 하우스 응답/뷰/DTO에는 cats avatar 원본 식별값을 **절대 포함하지 않는다**.
  - 금지 컬럼: cats.avatar_key (canonical), cats.avatar_url (legacy/deprecated).
  - 렌더는 기본/대체 아바타를 사용한다.
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
- TTL cleanup 방식: observation_groups 자체는 삭제하지 않는다. 멱등성 TTL이 만료된 row의 idempotency_key를 sentinel UUID(`00000000-0000-0000-0000-000000000000`)로 교체한다.
  - sentinel 교체 후에도 UNIQUE(owner_id, idempotency_key)는 충돌하지 않는다(sentinel은 공유 가능하도록 부분 유니크 조건 조정 필요).
  - 대안: UNIQUE(owner_id, idempotency_key) WHERE idempotency_key != '00000000-...' 부분 유니크로 변경.
  - observation_patch_dedup은 단순 row DELETE(7일 TTL)로 처리한다(FK cascade 없음).
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
  - **v1 범위**: 닉네임 변경 기능은 v1에서 구현하지 않는다(최초 설정 후 고정). v1.1+에서 구현 시 nickname_reservations 등 저장소 설계가 선행되어야 한다.
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
- 금지(명시): inventory_item_id, raw_text/note/meta, cats.avatar_key, cats.avatar_url(legacy), catalog_item_id
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

## D-057. 인벤 교체/중단 이벤트 모델(switch/discontinue/correction)
- Class: POLICY
- 무엇:
  - inventory_items는 원장 성격을 유지한다(D-040: 삭제 없음 유지).
  - 변경은 "수정"이 아니라 이벤트로 기록한다: switch / discontinue / correction.
  - 필드 의미/불변식: (ended_at IS NULL) == is_current 를 유지한다(See DATA-MODEL §4).
  - **reason_code 의미(LOCK)**: reason_code는 **"해당 row가 생성된 원인"**을 나타내며, 생성 이후 변경하지 않는다(불변).
    - initial: 최초 등록으로 생성된 row
    - switch: 교체 이벤트로 생성된 신규 row
    - correction: 정정 이벤트로 생성된 row
    - (discontinue는 신규 row를 만들지 않으므로 reason_code 값으로 사용하지 않는다)
  - 이벤트 규칙(표준):
    - switch: 기존 current row → ended_at set + is_current=false (reason_code **변경 없음**). 신규 row 추가(reason_code='switch').
    - discontinue: 기존 current row → ended_at set + is_current=false (reason_code **변경 없음**). 신규 row 없음.
    - correction: 기존 current row → ended_at set + is_current=false (reason_code **변경 없음**). 신규 row 추가(reason_code='correction').
  - 종료 원인 추적: v1에서는 별도 end_reason 컬럼을 두지 않는다. "ended_at 직후 생성된 신규 row의 reason_code"로 종료 맥락을 추론한다. discontinue는 신규 row가 없으므로 ended_at만으로 식별한다. 필요 시 v1.1+에서 end_reason 컬럼 승격(ADR-004 방식).
- 의미: 히스토리 신뢰성(회고/원인분석) 확보 + UX 용어/모델 일치.
- 변경: ADR 필요.

## D-058. 관찰 ↔ 인벤 “참조 고정”(observation_inventory_refs)
- Class: POLICY
- 무엇:
  - 관찰 저장 시점에 observation_inventory_refs로 타입별 inventory_item_id를 기록해 당시 맥락을 고정한다.
  - 관찰 Patch(부분수정)로는 refs를 변경하지 않는다(기본 불변).
  - refs가 잘못 기록된 정정이 필요하면: 기존 관찰을 직접 고치기보다
    - (권장) 기존 observations.status를 excluded로 전환하고,
    - 새 관찰 그룹으로 재작성(새 idempotency_key)하여 올바른 refs로 다시 저장한다.
- 의미: 과거 관찰이 “현재 인벤”으로 덮여 재해석되는 모순 방지(회고 SSOT).
- 변경: ADR 필요.

## D-059. 투약(medicine)은 인벤토리에서 제외(도메인 분리)
- Class: POLICY
- 무엇:
  - inventory_items.type v1 SSOT에서 medicine을 제외한다(See DATA-MODEL §4).
  - 투약/복약은 관찰/계획(미래) 도메인에서 다룬다.
- 의미: 인벤 원장 모델(타입별 0..1 current)과 투약 현실(동시 복수/스케줄)의 충돌 회피.
- 변경: ADR 필요.

## D-060. 관찰 그룹: owner당 log_date당 1그룹 (v1 LOCK)
- Class: POLICY
- 무엇:
  - observation_groups에 UNIQUE(owner_id, log_date) WHERE deleted_at IS NULL 을 강제한다.
  - 같은 날짜에 기존 group이 있으면 Upsert는 해당 group을 update(version 증가)한다.
  - D-058 재작성 플로우: 기존 group의 observations를 status='excluded' 일괄 전환 → 기존 group을 soft delete(deleted_at set) → 새 group 생성(새 idempotency_key, 새 observations/refs).
- 의미: UI(다이어리 = log_date 단위 1덩어리)와 스키마 정합. 조회/수정/Patch 대상이 항상 1개.
- See: D-058
- 변경: ADR 필요.

## D-061. 관찰 Patch 멱등성 저장소 (observation_patch_dedup)
- Class: GUARD
- 무엇:
  - rpc_patch_observation_items의 멱등성을 위해 observation_patch_dedup 테이블을 사용한다.
  - unique(owner_id, group_id, idempotency_key). 동일 키 재요청 시 기존 결과(result_json) 반환.
  - D-041과 동일하게 7일 TTL 적용(row cleanup).
  - 동일 idempotency_key + 다른 payload 감지 시: v1은 기존 결과 반환(409 미발생), 서버 로그에 warning 기록.
- 의미: Upsert(observation_groups.idempotency_key)와 Patch(patch_dedup.idempotency_key)의 dedup 저장소를 분리하여 의미 충돌 방지.
- See: D-022, D-041
- 변경: ADR 불필요(기존 가드레일 구체화).

## D-062. House unpublish 전이 규칙
- Class: POLICY
- 무엇:
  - unpublish = published_at를 NULL로 설정. visibility는 변경하지 않는다(기존 값 유지).
  - 재발행(publish)은 published_at = now()만 set.
  - 이 패턴은 냥스타그램 unpublish(D-007)와 동일하다.
- 의미: 공개/발행 모델의 패턴 통일. "public + 미발행"은 D-035 노출 조건에 의해 안전하게 비노출.
- See: D-035, D-007
- 변경: ADR 필요.

## D-063. Comments 공개 조회는 부모 post 가드에 종속
- Class: GUARD
- 무엇:
  - 댓글(comments)의 공개 조회 경로는 반드시 부모 post의 공개 가드(guard_soft_state + guard_block + guard_visibility_published)를 먼저 통과한 후에만 허용한다.
  - 댓글 독립 조회 경로(post 가드 없이 comment_id만으로 조회)는 공개 표면에서 금지한다.
  - 댓글 자체에도 guard_soft_state + guard_block을 적용한다.
- 의미: AUTHZ-MODEL "댓글 읽기: 부모 post 공개 조건 만족 시만"을 구현 경로에서 강제.
- See: AUTHZ-MODEL §댓글, D-029
- 변경: ADR 불필요(기존 정책의 구현 명세화).

## D-064. observation_inventory_refs upsert 머지 규칙
- Class: GUARD
- 무엇:
  - p_inventory_refs = NULL (파라미터 생략): 기존 refs를 변경하지 않는다(유지).
  - p_inventory_refs = 빈 object {}: 기존 refs를 전부 삭제한다(클리어).
  - p_inventory_refs에 특정 타입 키만 포함: 해당 타입만 upsert, 나머지 기존 refs는 유지.
- 의미: NULL과 빈 값의 의미를 구분하여 구현자 해석 차이를 방지.
- See: D-058
- 변경: ADR 불필요(기존 가드레일 구체화).

## D-065. RPC 에러 전달 패턴 (JSON return + 외부 표면 HTTP 매핑)
- Class: GUARD
- 무엇:
  - DB RPC 함수는 비즈니스 에러를 JSON object로 반환한다 (예: `{"error_code":"version_conflict","current_version":5}`).
  - DB 함수는 raise exception을 비즈니스 에러에 사용하지 않는다 (auth check 실패 등 hard fail만 예외).
  - HTTP 상태코드 매핑은 외부 표면(Edge Function/API Route/클라이언트 SDK wrapper)이 담당한다.
  - Supabase PostgREST에서 DB 함수가 예외 없이 정상 return하면 HTTP 200이 기본이며, 클라이언트는 `body.error_code`로 비즈니스 에러를 판별한다.
  - 권한/EXECUTE 거부나 예외(hard fail) 발생은 PostgREST 에러로 4xx/5xx가 될 수 있으며, 이는 비즈니스 에러(JSON return) 범주가 아니다.
  - 매핑 규칙: `error_code -> HTTP 상태코드` 테이블은 API-CONTRACTS에서 관리한다.
- 의미: D-050(404 통일)과 동일한 "외부 표면에서 상태코드 결정" 패턴을 비즈니스 에러(409 등)로 확장하고, DB 함수의 책임을 데이터/로직에 한정한다.
- See: D-050, D-022
- 변경: ADR 불필요(기존 패턴의 명시화).

## D-066. AuthN v1 (Korea-first, Social-first)
- Class: POLICY
- 무엇:
  - Providers(v1):
    - Apple, Kakao는 필수.
    - Google은 옵션(필요 시 on).
    - Email/password는 복구/백업 채널로 유지.
    - Naver는 Supabase native provider 미지원이므로 Brokered OAuth(서버/엣지)로 지원.
  - 가입 UX:
    - 첫 로그인 시 계정을 생성한다.
    - 최초 설정: nickname 필수.
    - terms_agreed_at은 약관 동의 시점에 설정하며, 초기에는 nullable로 시작한다.
    - PII(생년월일/성별)는 v1 필수 수집에서 제외한다.
  - 프로필 부트스트랩:
    - auth.users 생성 이벤트에서 profiles upsert를 수행한다.
    - 트리거는 최소 작업(upsert 1회)만 수행한다.
    - 트리거 예외는 흡수하고 로깅하며(signup 경로 비차단), 후속 정합성 보정은 배치/잡으로 처리 가능해야 한다.
  - 계정 링크:
    - v1은 자동 링크를 금지한다.
    - 명시적 링크(설정 화면)만 허용한다.
    - 두 user_id 병합 기능은 v1에서 제공하지 않는다.
  - 식별자 매핑(v1):
    - profiles.id는 내부 PK를 유지한다.
    - auth.users와 1:1 연결은 profiles.user_id(unique)로 고정한다.
  - 가드:
    - 민감/공개 기능(예: 게시/댓글/공개 전환) 실행 전에는 terms_agreed_at IS NOT NULL을 요구한다.
    - **적용 방식(LOCK)**: guard_terms_agreed()를 공통 guard 함수로 구현하고, **모든 write RPC**(post/comment/reply/thread/like/report/block/house publish·slot bind/inventory switch·discontinue 등)에서 필수 호출한다. read-only RPC에는 적용하지 않는다.
    - See: RPC-SPECS "공통 Guard 패턴"
- 의미: 한국 중심 소셜 로그인 전환율을 확보하면서, 링크/부트스트랩/약관 동의 타이밍으로 인한 가입 실패와 CS 리스크를 줄인다.
- 변경: ADR 권장

## D-067. Assets/Storage v1 (공개 경계 사고 방지 + SEO 이미지 정합)
- Class: POLICY
- 무엇:
  - 버킷(v1):
    - assets (private): 원본 자산 보관
    - assets-public (public): 공개 포스트용 파생 썸네일만 보관
  - 경로(prefix):
    - 원본(private): avatars/{user_id}/{uuid}.webp, posts/{user_id}/{post_id}/{uuid}.webp, cats/{user_id}/{cat_id}/{uuid}.webp
    - 썸네일(public): posts/{post_id}/{uuid}_thumb.webp (공개+발행 콘텐츠만)
  - DB 저장 값:
    - profiles는 avatar_key(storage key path)를 canonical 컬럼으로 사용한다(URL 아님).
    - profiles.avatar_url은 레거시 호환을 위한 deprecated 컬럼으로만 유지하고 신규 쓰기는 금지한다(v1 전환기).
    - cats도 avatar_key를 canonical 컬럼으로 사용한다.
    - cats.avatar_url은 레거시 호환을 위한 deprecated 컬럼으로만 유지하고 신규 쓰기는 금지한다(v1 전환기).
  - 제한:
    - image/jpeg, image/png, image/webp 허용, 최대 10MB.
  - 접근:
    - 원본 업로드/삭제: owner-only
    - 원본 읽기: signed URL(인증) 기본
    - 공개 썸네일 읽기: anon 허용(공개+발행 상태의 파생본만)
  - **파생본(썸네일) 라이프사이클(LOCK)**:
    - 생성: publish 시점에 원본에서 썸네일을 생성해 assets-public에 저장한다.
    - 삭제: unpublish / hide(hidden_at set) / delete(deleted_at set) 시 assets-public의 해당 썸네일을 즉시 삭제한다.
    - 재발행: re-publish 시 썸네일을 재생성한다.
    - 연동: 썸네일 삭제 시 Next.js ISR revalidate도 함께 트리거한다(seo-web playbook 참조).
- 의미: 원본은 private로 보호하면서도 공개 웹 SEO/OG 이미지 요구를 충족한다.
- See: D-015, D-050
- 변경: ADR 권장

## D-068. 관리자(운영) v1 범위 (O-009a 해소)
- Class: POLICY
- 무엇:
  - v1 운영 기능(최소):
    - 신고 큐 조회
    - hide/unhide
    - catalog_suggestions 승인/거절/별칭/병합
  - 권한 모델(v1):
    - profiles.is_admin boolean 기반 allowlist
    - v1.1+에서 역할 분리(admin_roles 등) 검토
  - 운영 액션은 admin 전용 경로(RPC/툴)로 수행하고 moderation_actions에 감사 로그를 남긴다.
  - 관리자 UI(화면/라우팅/노출)는 본 결정의 범위에 포함하지 않는다.
- 의미: 운영 최소 요건과 감사 가능성을 먼저 고정하고, UI는 별도 확장 지점으로 분리한다.
- See: D-014, D-024
- 변경: ADR 권장

## D-069. 스케줄드 작업 실행체 (O-027 해소)
- Class: POLICY
- 무엇:
  - 실행체: Supabase pg_cron(v1)
  - 작업 대상:
    - observation_groups idempotency cleanup (D-041)
    - observation_patch_dedup cleanup (D-061)
    - payload_version_events retention (D-045)
    - like_count/reply_count/comment_count 보정
  - 스케줄/타임존 기준선은 CONFIG-BASELINES에서 관리한다.
    - SSOT 고정 항목: UTC 기준 + 주기(cadence)
    - minute offset은 default 값으로만 두며 운영에서 조정 가능하다(LOCK 아님)
  - 실패 처리:
    - v1은 job_run_details/시스템 로그 기반 관측
    - v1.1+ 알림 연동(슬랙/이메일) 확장 가능
- 의미: 정책 TTL/retention/보정의 실행체를 고정해 운영 공백을 제거한다.
- See: D-041, D-045, D-061
- 변경: ADR 권장

## D-070. 알림 v1 (푸시 제외, in-app inbox)
- Class: POLICY
- 무엇:
  - v1 범위: in-app inbox(조회/읽음 처리)만 제공, 푸시는 제외(v1.1+)
  - 이벤트: comment / reply / like
  - type-target 매핑(v1 LOCK):
    - comment -> target_type='post', target_id=post_id
    - reply -> target_type='thread', target_id=thread_id
    - like -> target_type='post'만 허용(v1 단순화)
  - 스키마: notifications(id, user_id, type, actor_id, target_type, target_id, read_at, created_at)
- 의미: 푸시 인프라 없이도 리텐션 최소 요건을 확보하고, 타입 매핑 혼선을 줄인다.
- 변경: ADR 권장

## D-071. Transport Adapter 규약
- Class: GUARD
- 무엇:
  - DB RPC는 JSON return(D-065 유지). HTTP 매핑은 두 경로:
    - (A) 앱: 클라이언트 SDK wrapper가 body.error_code 파싱/throw
    - (B) 웹 SSR: Next.js route handler에서 error_code→HTTP 변환
  - 매핑 테이블 SSOT는 API-CONTRACTS "Transport Adapter" 섹션
- See: D-065, D-050
- 변경: ADR 불필요

## D-072. 공개 썸네일 파생본 라이프사이클
- Class: POLICY
- 무엇:
  - publish 시 생성 / unpublish·hide·delete·private전환 시 즉시 삭제 / 재발행 시 재생성
  - 삭제 시 ISR revalidate 동시 트리거
- See: D-067, D-025
- 변경: ADR 권장

## D-073. Write RPC 공통 가드: guard_terms_agreed
- Class: GUARD
- 무엇:
  - 모든 write RPC 실행 전 profiles.terms_agreed_at IS NOT NULL 검증
  - 미동의 시 `{"error_code":"terms_not_agreed"}` 반환
  - read RPC 제외
- See: D-066
- 변경: ADR 불필요

## D-074. House 슬롯 API: slot_key 기반 통일
- Class: GUARD
- 무엇:
  - rpc_set_house_slot(p_room_key, p_slot_key, p_inventory_item_id) — upsert
  - rpc_clear_house_slot(p_room_key, p_slot_key) — 비우기
  - house_slots.id(PK)는 API 표면 미노출
- See: D-006
- 변경: ADR 불필요

## D-075. reason_code = "row 생성 원인"(불변)
- Class: GUARD
- 무엇:
  - reason_code는 생성 시 기록, 이후 변경 금지: initial / switch / correction
  - 종료 시 기존 row의 reason_code 변경 안 함(ended_at + is_current=false만)
  - 'discontinue'는 reason_code 값으로 미사용(종료 행위이며 신규 row 없음)
- See: D-057
- 변경: ADR 불필요

## D-076. 채널 Popular 피드 v1 공식 (O-004/O-028 해소)
- Class: CONFIG
- 무엇:
  - score = like_count + reply_count × 2, window = 7d, ORDER BY score DESC, created_at DESC
  - app_config 키 `popular_feed`로 런타임 조정
- 수치: See CONFIG-BASELINES §5
- 변경: 수치는 CONFIG-BASELINES. 공식 구조 변경은 ADR 권장

## D-077. 채널 검색 UX v1 (O-005 해소)
- Class: GUARD
- 무엇:
  - keyset cursor 통일. 파라미터: q(필수), topic(선택), cursor, limit
  - 정렬: FTS rank 기본, created_at desc 폴백. noindex 유지(D-021)
- 변경: ADR 불필요

## D-078. 프로필 SEO: v1 noindex (O-006 해소)
- Class: POLICY
- 무엇:
  - /u/{nickname} v1 noindex. 콘텐츠는 /p/, /c/로 index
- 변경: ADR 권장

## D-079. 작성글/활동 보기: v1 미포함 (O-007 해소)
- Class: POLICY
- 무엇:
  - v1.1+에서 범위 결정
- 변경: ADR 불필요

## D-080. 관리자 UI: v1은 Supabase 내부 도구 + admin RPC (O-009b 해소)
- Class: POLICY
- 무엇:
  - 별도 /admin 웹 UI는 v1 미구현. See: D-068
- 변경: ADR 불필요

## D-081. unhide 시 신고 카운터 처리 (O-022 해소)
- Class: GUARD
- 무엇:
  - unhide 시 해당 target의 기존 reports 일괄 soft delete(deleted_at=now())
  - 이후 신규 신고만 auto-hide 카운트 대상
  - moderation_actions 감사 로그 필수
- See: D-024, D-054
- 변경: ADR 불필요

## D-082. 관찰→냥스타 CTA: v1 UI 플로우만 (O-026 해소)
- Class: GUARD
- 무엇:
  - 관찰 저장 후 CTA → 냥스타 Composer 이동(초안 삽입, 수정 가능)
  - FK/링크테이블 v1 미생성
- 변경: ADR 불필요

## D-083. observation_groups idempotency TTL 방식
- Class: GUARD
- 무엇:
  - observation_groups row 자체는 삭제하지 않는다(log_date 데이터 보존)
  - 멱등성 중복 방지 기간(7일)은 RPC 로직에서 created_at 기준 시간 비교로 판정
  - 7일 초과 요청은 새 idempotency_key 필수(같은 log_date면 기존 group overwrite + version++)
  - observation_patch_dedup은 기존대로 7일 TTL row cleanup(pg_cron)
- See: D-041, D-060, D-061
- 변경: ADR 불필요

## D-084. 같은 log_date + 다른 idempotency_key = overwrite
- Class: GUARD
- 무엇:
  - UNIQUE(owner_id, log_date) WHERE deleted_at IS NULL 유지(D-060)
  - 같은 날짜에 다른 key로 upsert: 기존 group의 idempotency_key를 새 key로 갱신 + version++ + items 교체
  - 멱등성은 갱신된 key 기준으로 동작
- See: D-060
- 변경: ADR 불필요

## D-085. house_profiles 생성 시점: lazy create
- Class: GUARD
- 무엇:
  - 하우스 탭 최초 접근 또는 슬롯 바인딩 시 house_profiles upsert(없으면 생성)
  - auth bootstrap trigger에서는 생성하지 않는다
  - 기본값: visibility='private', published_at=NULL
- 변경: ADR 불필요

## D-086. inventory_items.raw_text: NOT NULL
- Class: GUARD
- 무엇:
  - raw_text NOT NULL, 최소 1자
  - catalog_item_id 있으면 catalog.standard_name을 raw_text에 canonicalize
- 변경: ADR 불필요

## D-087. 콘텐츠 필드 길이 제약 v1
- Class: GUARD
- 무엇:
  - posts.body: 1~5000 / threads.title: 1~120 / threads.body: 1~10000
  - replies.body: 1~5000 / comments.body: 1~2000
  - profiles.nickname: 2~20 / profiles.bio: 0~200
  - inventory_items.raw_text: 1~200 / inventory_items.reason_note: 0~500
  - 모두 DB CHECK로 강제
- 변경: ADR 불필요

## D-088. Post 이미지: v1은 posts.meta JSONB
- Class: GUARD
- 무엇:
  - v1은 posts.meta->'images' (storage key 배열, 최대 5개)로 저장
  - 별도 post_images 테이블은 v1 미생성. 필요 시 ADR-004 승격
- 변경: ADR 불필요

## D-089. unknown payload_version: ACCEPT + warn
- Class: POLICY
- 무엇:
  - payload_versions 테이블에 없는 version은 저장 허용(기능 차단 금지)
  - payload_version_events에 event_type='unknown'으로 기록
  - 롤업에서 unknown 버킷으로 집계
- 변경: ADR 불필요

## D-090. like toggle RPC + notification 생성
- Class: GUARD
- 무엇:
  - rpc_toggle_like(p_target_type, p_target_id): 있으면 삭제+카운트-1, 없으면 삽입+카운트+1
  - 원자 UPDATE(D-046). guard_block 필수. guard_terms_agreed 필수
  - notification: post like만(D-070). block 관계면 미생성
- See: D-046, D-070
- 변경: ADR 불필요

## D-091. reports.reason_code v1 허용 값
- Class: GUARD
- 무엇:
  - CHECK (reason_code IN ('spam','harassment','inappropriate','copyright','other'))
- 변경: ADR 불필요

## D-092. FTS: stored generated + simple config
- Class: GUARD
- 무엇:
  - threads.fts_vector: generated column, to_tsvector('simple', title || ' ' || body)
  - GIN 인덱스. 한국어 형태소는 v1.1+
- 변경: ADR 불필요

## D-093. Notification 생성 경로
- Class: GUARD
- 무엇:
  - 각 write RPC(comment/reply/like) 내부 동일 트랜잭션에서 notifications INSERT
  - trigger 미사용. block 관계면 notification 미생성
- See: D-070
- 변경: ADR 불필요

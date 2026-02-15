# OPEN — 미결정/보류 원장

규칙: 확정 금지. 결정되면 해당 항목은 `Status: Resolved → D-###`만 남기고(제목 유지), 본문(질문/설명)은 삭제한다.

## O-001 레이트리밋 "수치"
- **Status: Resolved → D-053**

## O-002 자동숨김 임계치 및 신뢰 조건
- **Status: Resolved → D-054**

## O-003 hidden/deleted 콘텐츠 SEO 처리(404 vs 410 vs noindex)
- **Status: Resolved → D-050**

## O-004 인기(Popular) 점수 공식/윈도우/집계 주기
- **Status: Resolved → D-076**

## O-005 채널 검색 UX(페이징/필터)
- **Status: Resolved → D-077**

## O-006 프로필 페이지 SEO(index/noindex)
- **Status: Resolved → D-078**

## O-007 "작성글/활동 보기" 제공 시점
- **Status: Resolved → D-079**

## O-009 관리자 UI 범위(운영 도구)
- O-009a 운영 기능/권한 범위: **Status: Resolved → D-068**
- O-009b 관리자 UI(화면/라우팅/노출): **Status: Resolved → D-080**

## O-010 기술 스택/배포 확정
**Status: Resolved → D-049**

## O-011 k-익명 하한 값, 버킷 경계·UI 정책(데이터 상품 API)
- 왜 미결정: 데이터량/버킷 분포/고객군에 따라 적정 k 및 표현 방식이 달라짐.
- 결정에 필요한 질문:
  - 최소 표본 k는 얼마로 둘지?
  - < k 구간은 "< k"로 숨길지, N/A로 처리할지, 아예 row를 제거할지?
  - 버킷 경계(예: 연령/체중/증상 지표 스케일) 정책은 무엇인지?

## O-012 block 필터 성능 최적화(캐시/MV/Redis) 여부·주기
- 왜 미결정: block/unblock의 최신성이 프라이버시 요구사항이라, 캐시는 stale 위험이 있음.
- 결정에 필요한 질문:
  - block 관계 조인의 성능 병목이 실제로 발생하는가(EXPLAIN/slow-query 기반)?
  - 캐시를 한다면 MV/Redis/단순 denormalize 중 무엇이 적합한가?
  - 캐시 적용 시 TTL/무효화(블락 변경 이벤트 기반) 전략은?

## O-013 노이즈 주입 / p-value 자동 검정 도입 타이밍
- 왜 미결정: v1.1에서는 과투자/설명비용/신뢰 이슈가 커질 수 있음. 고객 규모·규제·오용 리스크에 따라 달라짐.
- 결정에 필요한 질문:
  - 통계 검정(p-value) 자동화가 필요한 고객군/요구가 확인되는가?
  - 노이즈 주입이 "프라이버시" vs "데이터 신뢰" 중 무엇을 더 해치지 않는가?
  - 도입 시점(예: 유료 고객 N곳, 데이터량 M 이상, 규제/계약 요구 발생 시)은?

## O-014 공개 하우스 "슬롯 요약 DTO" 허용 필드 세트
- **Status: Resolved → D-055**

## O-015 슬롯 하드캡/유료 정책
- 결정에 필요한 질문:
  - 최대 슬롯 수/기본 제공 수?
  - 유료 증설 단위(+5 등) 및 가격/환불 정책?

## O-016 공개 하우스 노출 위치/탐색
- 결정에 필요한 질문:
  - v1: 프로필에서만 노출 vs 피드/탐색 탭을 언제 도입?
  - SEO index/noindex 및 공유 링크 정책은?

## O-017 공개 하우스 성능 최적화(v1.1+ 후보)
- 왜 미결정: D-039로 스냅샷 미채택이므로 트래픽 증가 시 선택 필요.
- 결정에 필요한 질문:
  - view+join+인덱스 튜닝으로 버틸지
  - MV/캐시(발행/변경 트리거)로 갈지
  - CDN/ISR 캐시 레이어와 결합할지

## O-018 공개 하우스의 anon 접근 정책
- **Status: Resolved → D-035, D-044**

## O-019 슬롯 바인딩의 "current 변경 후 처리"
- **Status: Resolved → D-043**

## O-022 자동숨김 해제 시 신고 카운터 처리
- **Status: Resolved → D-081**

## O-024 신고 시점 콘텐츠 스냅샷
- **Status: Resolved → D-052**

## O-025. 계획/알림 도메인 최소 설계(v1 범위 미확정)
- 배경: 관찰(log_date=오늘 이하)과 달리 "미래" 시간축이 필요(할 일/알림/반복).
- 범위(미결정):
  - 단발 일정(한 번) vs 반복(매일/매주/매월/연 1~2회)
  - 알림 채널(앱 푸시/캘린더 연동 등) — v1에서는 미확정
- 제약/불변식(초안):
  - 관찰과 테이블/도메인은 분리(시간축/권한/UX가 다름).
  - v1에서는 관찰의 log_date "미래 금지" 원칙을 유지(기존 SSOT).

## O-026. 관찰 → 냥스타 CTA 흐름 상세
- **Status: Resolved → D-082**

## O-027. 스케줄드 작업 실행체(TTL cleanup / retention / 집계 보정)
- **Status: Resolved → D-069**

## O-028. Channel popular 피드 임시 공식 (v1)
- **Status: Resolved → D-076**

## O-029. 관찰 멱등성 request_hash 방어 (v1.1+)
- 배경: v1은 동일 idempotency_key 재요청 시 기존 결과 반환 + 서버 로그 warning (D-061).
- 미결정: request_hash 저장 + payload mismatch 시 409 반환을 v1.1+에서 도입할지.
- 결정에 필요한 질문:
  - payload canonicalization(items 배열 순서 등) 비용은?
  - 실제 mismatch 빈도(서버 로그 기반 판단)?

## O-030 SEO ISR 캐시와 block(뷰어별) 필터 결합 규칙
- 왜 미결정: SEO 라우트는 ISR/캐시(anon 기준)가 핵심인데, 로그인 뷰어는 block 필터가 뷰어별이다.
- 결정에 필요한 질문:
  - SEO 라우트는 anon 기준 렌더로 고정하고(캐시 우선) 로그인 사용자도 동일 결과를 볼지?
  - 로그인 뷰어는 cache bypass(동적 렌더)로 전환할지?
  - (혼합) anon은 ISR, auth는 SSR(no-store)로 분리할지?
- 참고: `docs/playbooks/seo-web.md`, `AUTHZ-MODEL.md` §0-2

## O-031 terms_agreed_at 가드 부트스트랩 예외 최소 집합
- 왜 미결정: "모든 write RPC는 guard_terms_agreed()"가 원칙이지만, 약관 동의/초기 프로필 설정 자체가 write다.
- 결정에 필요한 질문:
  - v1에서 terms 부트스트랩 write RPC를 무엇으로 제한할지(예: agree_terms, set_nickname)?
  - 해당 RPC는 guard_terms_agreed 예외로 둘지, 또는 별도 pre-terms 가드로 둘지?
- 참고: `DECISIONS.md` D-066, D-073, `docs/API.md`(write guard)

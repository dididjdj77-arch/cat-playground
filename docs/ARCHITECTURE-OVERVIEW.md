# ARCHITECTURE-OVERVIEW — 전체 설계도(1장)

## 1) 구성
- 앱(Expo RN): 다이어리(관찰/내 글) + 소셜(냥스타/채널)
- 웹(Next.js SSR/ISR): SEO 유입(공개 토픽/스레드/공개 글)
- 백엔드(Supabase): Postgres/Auth/Storage + (권장) Edge Functions/RPC

## 2) 도메인
- House: Cats, Inventory + Catalog(AC-3)
- Diary: ObservationGroup(log_date) + Observations(cat별) + Local Draft
- Nyanstagram: Post(visibility/published_at/log_date/hide_from_profile) + Comment + Like
- Channel: Topic + Thread + Reply(1-depth) + Like + Follow + Search(FTS)
- Moderation: Report + Block + AutoHide(hidden_at) + AuditLog + Admin UI

## 3) 노출 정책(공통)
공개 노출은 항상 아래를 만족:
- deleted_at is null
- hidden_at is null
- block 관계 아님
- (냥스타) visibility=public AND published_at is not null
- (하우스) visibility=public AND published_at is not null

다이어리는 소유자에게 private/미발행도 표시(log_date 기준).

공개 하우스 DTO는 화이트리스트만 반환하며 cats.avatar_url을 포함하지 않는다.

## 4) 고위험 가드레일
- 관찰 저장: Upsert(전체)/Patch(부분) + 트랜잭션 + idempotency + version 충돌(409)
- 채널: 피드3종 분리 + cursor pagination + FTS + like_count/reply_count 보정
- 운영: 레이트리밋 + 신고 + 자동숨김 + 차단(상호 비노출) + 감사로그
- SEO: SSR/ISR + index/noindex + hidden/deleted 처리 + 재검증 트리거

## 5) 대표 플로우
- 관찰 저장: log_date 선택 → 공통+오버라이드 → Upsert → 다이어리 log_date 섹션 반영
- 냥스타 발행: public 저장(미발행) → 발행(published_at set) → 피드/웹 노출
- 채널 SEO: /c/{topic} → /c/{topic}/{thread} (index), /search는 noindex
- 하우스 발행: visibility=public + published_at set → 타인 조회 가능(슬롯 요약만)

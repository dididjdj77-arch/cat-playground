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

## 2a) 도메인 관계(요약)
- User 1:N Cat
- User 1:N ObservationGroup -> 1:N Observation
- User 1:N Post -> 1:N Comment
- Topic 1:N Thread -> 1:N Reply(1-depth)
- User N:M TopicFollow
- Like: User N:M (Post/Comment/Thread/Reply)
- Block: User N:M User (blocker/blocked)
- Report: User 1:N Report -> target(Post/Comment/Thread/Reply/User)
- Catalog(Items/Aliases/Suggestions) -> InventoryItem 연결(catalog_item_id + raw_text)
- User 1:1 HouseProfile
- User 1:N HouseSlot (room_key='living_room') -> N:0..1 InventoryItem
- ObservationGroup 1:N ObservationInventoryRef (타입별 0..1)
- ObservationGroup 1:N ObservationPatchDedup (Patch 멱등성)

## 3) 노출/권한 정책(SSOT)
- 정책식 원문: `AUTHZ-MODEL.md` §0 (복붙 금지, 링크만)
- 상태코드(존재 은닉): `DECISIONS.md` D-050
- 공개 DTO 화이트리스트(하우스): `DECISIONS.md` D-055, D-037

## 4) 고위험 가드레일
- 관찰 저장: Upsert(전체)/Patch(부분) + 트랜잭션 + idempotency + version 충돌(409)
- 채널: 피드3종 분리 + cursor pagination + FTS + like_count/reply_count 보정
- 운영: 레이트리밋 + 신고 + 자동숨김 + 차단(상호 비노출) + 감사로그
- SEO: SSR/ISR + index/noindex + hidden/deleted 처리 + 재검증 트리거

## 5) 대표 플로우
- 관찰 저장: log_date 선택 -> 공통+오버라이드 -> Upsert -> 다이어리 log_date 섹션 반영
- 냥스타 발행: public 저장(미발행) -> 발행(published_at set) -> 피드/웹 노출
- 채널 SEO: /c/{topic} -> /c/{topic}/{thread} (index), /search는 noindex
- 하우스 발행: visibility=public + published_at set -> 타인 조회 가능(슬롯 요약만)

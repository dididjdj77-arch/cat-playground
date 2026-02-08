# DATA-MODEL — DB 스키마(설계 기준)

원칙:
- id: uuid
- created_at/updated_at/ deleted_at(soft delete)
- hidden_at(운영 숨김)
- 공개 조회는 hidden/deleted/blocked 필터 강제
- log_date는 오늘 이하만

## 1) profiles
- profiles(id pk, nickname unique, avatar_url, bio, nickname_changed_at?, created_at, updated_at)
- profile_settings(user_id pk, default_post_visibility?, created_at, updated_at)

## 2) cats
- cats(id pk, owner_id, name, birth_date, sex, breed, avatar_url, created_at, updated_at, deleted_at)
- avatar_url: 개인/비공개 자산. 공개 하우스 응답/뷰/DTO에는 포함 금지(D-037).
- index: (owner_id, deleted_at), (owner_id, name)

## 2a) house
- house_profiles(user_id pk, visibility(private|public), published_at?, hidden_at?, deleted_at?, created_at, updated_at)
  - constraint(권장): CHECK (NOT (visibility='private' AND published_at IS NOT NULL))
  - 전이 규칙: visibility를 private로 변경하면 published_at=NULL 강제(서버/RPC) + DB CHECK로 방어
- house_slots(id pk, owner_id, room_key, slot_key, inventory_item_id?, equipped_at?, created_at, updated_at, deleted_at)
  - unique(owner_id, room_key, slot_key)
  - v1(living_room) slot_key SSOT: slot_01..slot_08
  - slot_key는 opaque id이며 의미/좌표/레이어는 클라이언트 씬 config가 소유한다.

비고:
- v1 room_key는 'living_room' 1개만 사용(방 다중화는 v1.1+).
- 공개 노출 조건은 visibility='public' AND published_at is not null AND not hidden/deleted AND not blocked(D-035).
- 공개 하우스에서 노출되는 인벤 정보는 "슬롯 장착 요약(화이트리스트)"만(D-036).

## 3) catalog (AC-3)
- catalog_items(id, type, standard_name, brand, metadata, created_at, updated_at)
  - unique(type, standard_name)
- catalog_aliases(id, type, alias unique per type, catalog_item_id, created_at)
- catalog_suggestions(id, type, raw_text, suggested_by, status(pending/approved/rejected),
  resolved_catalog_item_id?, reviewed_by?, review_note?, created_at, updated_at)

## 4) inventory_items
- inventory_items(id, owner_id, type, catalog_item_id?, raw_text, is_current, changed_at, ended_at?, reason_code, reason_note?, note?, meta jsonb, created_at, updated_at, deleted_at)
- 의미(필드):
  - changed_at: started_at(사용 시작 시각)으로 해석한다.
  - ended_at: 사용 종료 시각(nullable).
  - is_current: ended_at IS NULL 과 동치로 유지한다(불변식).
  - reason_code: 해당 row의 생성/종료 이벤트 성격을 나타낸다.
    - 'initial'|'switch'|'discontinue'|'correction'
  - reason_note: 짧은 메모(nullable).

- Invariants:
  - (ended_at IS NULL) == (is_current = true)

- 이벤트 규칙(표준):
  - switch: 기존 current row는 ended_at set + is_current=false. 신규 row를 추가하고 신규 row.reason_code='switch', ended_at=NULL, is_current=true.
  - discontinue: 기존 current row만 ended_at set + is_current=false + reason_code='discontinue'. 신규 row는 만들지 않는다.
  - correction: 정정 성격의 이벤트로 기록(reason_code='correction').
- index: (owner_id, type, is_current), (owner_id, deleted_at)
- constraint/index (권장): UNIQUE(owner_id, type) WHERE is_current=true AND deleted_at IS NULL
  - 의미: 한 타입당 current는 최대 1개(0..1)
- v1 type SSOT: food | litter | toy | furniture
- constraint(권장): CHECK (type IN ('food','litter','toy','furniture'))
- deleted_at: 사용자 기능 미사용(v1에서 항상 NULL). 운영/데이터 수리 목적의 예약 필드.

## 5) observation (다묘)
- observation_groups(id, owner_id, log_date, payload_version text, common_payload jsonb, version int, idempotency_key uuid, created_at, updated_at, deleted_at)
  - unique(owner_id, idempotency_key)
  - (선택) unique(owner_id, log_date) — 날짜당 1묶음으로 고정할 때
  - index: (owner_id, log_date), (owner_id, payload_version), (owner_id, idempotency_key)
- observations(id, group_id, owner_id, cat_id, status(active|excluded), override_payload jsonb?, created_at, updated_at, deleted_at)
  - unique(group_id, cat_id)
- 필수: 트랜잭션 + idempotency + expected_version 기반 충돌 처리

## 5a) observation_inventory_refs (관찰 시점 인벤 참조 고정)
- observation_inventory_refs(id pk, owner_id, group_id, inv_type, inventory_item_id, created_at)
  - inv_type SSOT: food | litter | toy | furniture
  - unique(group_id, inv_type) — v1에서는 타입별 0..1
  - FK: group_id → observation_groups.id, inventory_item_id → inventory_items.id
- 의미:
  - 관찰 저장 시점에 “당시 사용중이었던 인벤 항목”을 타입별 inventory_item_id로 고정 저장한다.
  - 관찰 Patch(부분수정)로는 이 참조를 변경하지 않는다(변경 필요 시 DECISIONS D-058 참고).

## 6) nyanstagram
- posts(id, author_id, body, log_date, visibility(private|public), published_at?, hide_from_profile bool,
  like_count int, comment_count int, hidden_at?, created_at, updated_at, deleted_at)
  - constraint(권장): CHECK (NOT (visibility='private' AND published_at IS NOT NULL))
  - 전이 규칙: visibility를 private로 변경하면 published_at=NULL 강제(서버/RPC) + DB CHECK로 방어
  - index: (author_id, log_date desc), (visibility,published_at desc where public+published), (published_at desc)
- comments(id, post_id, author_id, body, edited_at?, like_count, hidden_at?, created_at, updated_at, deleted_at)
- comment_revisions(id, comment_id, previous_body, created_at) — 이전 본문 1개만 유지(내부 감사)

## 7) channel
- topics(id, slug unique, name, description?, is_public=true, created_at, updated_at, deleted_at)
- topic_follows(user_id, topic_id, created_at) pk(user_id, topic_id)
- threads(id, topic_id, author_id, title, body, like_count, reply_count, hidden_at?, created_at, updated_at, deleted_at)
  - FTS: tsvector(title+body) + GIN
- replies(id, thread_id, author_id, body, edited_at?, like_count, hidden_at?, created_at, updated_at, deleted_at)
  - 1-depth(부모 reply 없음)

## 8) likes(공통)
- likes(id, user_id, target_type(post|comment|thread|reply), target_id, created_at)
  - unique(user_id, target_type, target_id)

## 9) moderation
- blocks(blocker_id, blocked_id, created_at) pk(blocker_id, blocked_id)
- reports(id, reporter_id, target_type, target_id, reason_code, note?, snapshot jsonb, created_at, deleted_at)
  - constraint(권장): UNIQUE(reporter_id, target_type, target_id) WHERE deleted_at IS NULL
  - 의미: 동일 사용자의 동일 대상 중복 신고 방지
- moderation_actions(id, actor_id, action, target_type, target_id, meta jsonb?, created_at)

## 10) 집계/보정(권장)
- like_count/reply_count/comment_count는 트리거 또는 배치로 보정 가능(OPEN: 주기/방식)

## 11) payload_versions / KPI
- payload_versions(version text pk, state(ACTIVE|DEPRECATED|REJECT), meta jsonb?, created_at, updated_at)
- payload_version_events(id, ts, version, event_type(seen|reject|normalize_fail), request_id?, reason?, created_at)
- payload_version_rollups(version, bucket_ts, seen_count, reject_count, normalize_fail_count, last_seen_at)

## 12) ops_metrics
- ops_metrics(id, ts, metric_key, metric_value_num?, metric_value_text?, meta jsonb?, created_at)
  - index: (metric_key, ts desc)

## 13) app_config (운영 파라미터 SSOT)
- app_config(key text pk, value jsonb not null, updated_at timestamptz, updated_by uuid? fk profiles.id)
- key(v1):
  - rate_limits
  - rate_limits_new_account
  - auto_hide
- 주의:
  - 비밀값(토큰/키/내부 전용 플래그)은 절대 저장 금지.
  - 새로운 key 추가 시: D-056 + RPC whitelist 업데이트가 선행.

# DATA-MODEL — DB 스키마(설계 기준)

원칙:
- id: uuid
- created_at/updated_at/ deleted_at(soft delete)
- hidden_at(운영 숨김)
- 공개 조회는 hidden/deleted/blocked 필터 강제
- log_date는 오늘 이하만
- 텍스트 필드 길이 제한은 DB CHECK로 강제한다 (D-075). 구체 수치는 각 테이블 정의 참조.
- 모든 owner_id/author_id FK는 auth.users.id를 참조한다(D-094).

## 1) profiles
- profiles(id pk, user_id unique fk -> auth.users.id, nickname unique, avatar_key, avatar_url? deprecated, bio, terms_agreed_at?, is_admin bool default false, nickname_changed_at?, created_at, updated_at, deleted_at?)
  - avatar_key: canonical storage key path (private 원본)
  - avatar_url(deprecated): 레거시 호환 컬럼. 신규 쓰기 금지, 단계적 제거 대상.
  - `terms_agreed_at`는 약관 동의 시점에 설정하며, 초기 signup 직후에는 nullable 허용(D-066).
  - 민감/공개 기능(예: 게시/댓글/공개 전환)은 terms_agreed_at IS NOT NULL 가드를 요구한다(D-066).
- profile_settings(user_id pk, default_post_visibility?, created_at, updated_at)

## 1a) assets/storage
- 원본 자산: private bucket(`assets`) + signed URL 접근(인증 기본)
- 공개 썸네일: public bucket(`assets-public`)에 파생본만 저장
- 경로(prefix) 기준:
  - 원본: avatars/{user_id}/{uuid}.webp, posts/{user_id}/{post_id}/{uuid}.webp, cats/{user_id}/{cat_id}/{uuid}.webp
  - 공개 썸네일: posts/{post_id}/{uuid}_thumb.webp (공개+발행 콘텐츠만)
- 프로필/고양이 이미지 DB 값은 URL이 아니라 `avatar_key`(storage key path)를 저장한다(D-067).

## 2) cats
- cats(id pk, owner_id, name, birth_date, sex, breed, avatar_key, avatar_url? deprecated, created_at, updated_at, deleted_at)
- avatar_key: canonical storage key path (private 원본)
- avatar_url(deprecated): 레거시 호환 컬럼. 신규 쓰기 금지, 단계적 제거 대상.
- 공개 하우스 응답/뷰/DTO에는 avatar_key/avatar_url 모두 포함 금지(D-037).
- index: (owner_id, deleted_at), (owner_id, name)

## 2a) house
- house_profiles(user_id pk, visibility(private|public), published_at?, hidden_at?, deleted_at?, created_at, updated_at)
  - constraint(권장): CHECK (NOT (visibility='private' AND published_at IS NOT NULL))
  - 전이 규칙: visibility를 private로 변경하면 published_at=NULL 강제(서버/RPC) + DB CHECK로 방어
- house_slots(id pk, owner_id, room_key, slot_key, inventory_item_id?, equipped_at?, created_at, updated_at, deleted_at)
  - unique(owner_id, room_key, slot_key)
  - FK: inventory_item_id → inventory_items.id (nullable)
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
- inventory_items(id, owner_id, type, catalog_item_id?, raw_text text NOT NULL, is_current, changed_at, ended_at?, reason_code, reason_note?, note?, meta jsonb, created_at, updated_at, deleted_at)
- 의미(필드):
  - changed_at: 사용 시작일(사용자 입력 가능). NOT NULL, default now().
  - ended_at: 사용 종료 시각(nullable).
  - is_current: ended_at IS NULL 과 동치로 유지한다(불변식).
  - reason_code: 해당 row가 **생성된 원인**(불변, 변경 금지). See D-075.
    - 'initial'|'switch'|'correction'
    - v1: NOT NULL + default='initial'
    - 'discontinue'는 값으로 미사용(종료 행위, 신규 row 없음)
  - reason_note: 짧은 메모(nullable).

- Invariants:
  - (ended_at IS NULL) == (is_current = true)

- 이벤트 규칙(표준):
  - switch: 기존 current → ended_at set + is_current=false(reason_code 불변). 신규 row(reason_code='switch').
  - discontinue: 기존 current → ended_at set + is_current=false(reason_code 불변). 신규 row 없음.
  - correction: 기존 row → ended_at set + is_current=false. 신규 row(reason_code='correction').
- index: (owner_id, type, is_current), (owner_id, deleted_at)
- constraint/index (권장): UNIQUE(owner_id, type) WHERE is_current=true AND deleted_at IS NULL
  - 의미: 한 타입당 current는 최대 1개(0..1)
- constraint: CHECK (char_length(raw_text) BETWEEN 1 AND 200) — D-086, D-087
- constraint: CHECK (reason_code IN ('initial','switch','correction')) — D-075
- constraint: CHECK (char_length(reason_note) <= 500) — D-087
- v1 type SSOT: food | litter | toy | furniture
- constraint(권장): CHECK (type IN ('food','litter','toy','furniture'))
- deleted_at: 사용자 기능 미사용(v1에서 항상 NULL). 운영/데이터 수리 목적의 예약 필드.

## 5) observation (다묘)
- observation_groups(id, owner_id, log_date, payload_version text, common_payload jsonb, version int, idempotency_key uuid NOT NULL, created_at, updated_at, deleted_at)
  - unique(owner_id, idempotency_key) WHERE idempotency_key <> '00000000-0000-0000-0000-000000000000' (부분 유니크)
  - unique(owner_id, log_date) WHERE deleted_at IS NULL — 날짜당 1그룹 (D-060)
  - index: (owner_id, log_date), (owner_id, payload_version), (owner_id, idempotency_key)
  - TTL(D-041): 7일 경과 row의 idempotency_key를 sentinel UUID('00000000-0000-0000-0000-000000000000')로 교체한다. row 자체는 삭제하지 않는다.
  - observation_patch_dedup은 단순 row DELETE로 TTL cleanup한다(FK cascade 없음).
- observations(id, group_id, owner_id, cat_id, status(active|excluded), override_payload jsonb?, created_at, updated_at, deleted_at)
  - status 의미: excluded는 해당 관찰 항목을 "이번 그룹 집계에서 제외"하는 상태이며, payload_versions.state의 DEPRECATED와는 다른 개념이다.
  - unique(group_id, cat_id)
- 필수: 트랜잭션 + idempotency + expected_version 기반 충돌 처리

## 5b) observation_patch_dedup (Patch 멱등성)
- observation_patch_dedup(id pk, owner_id, group_id, idempotency_key uuid NOT NULL, result_json jsonb, created_at)
  - unique(owner_id, group_id, idempotency_key)
  - FK: group_id → observation_groups.id
- 의미:
  - rpc_patch_observation_items의 멱등성을 보장한다. 동일 (owner_id, group_id, idempotency_key) 재요청 시 result_json을 반환.
  - D-041과 동일하게 7일 TTL(row cleanup).
- See: D-061

## 5a) observation_inventory_refs (관찰 시점 인벤 참조 고정)
- observation_inventory_refs(id pk, owner_id, group_id, inv_type, inventory_item_id, created_at)
  - inv_type SSOT: food | litter | toy | furniture
  - unique(group_id, inv_type) — v1에서는 타입별 0..1
  - FK: group_id → observation_groups.id, inventory_item_id → inventory_items.id
- 의미:
  - 관찰 저장 시점에 “당시 사용중이었던 인벤 항목”을 타입별 inventory_item_id로 고정 저장한다.
  - 관찰 Patch(부분수정)로는 이 참조를 변경하지 않는다(변경 필요 시 DECISIONS D-058 참고).
- Upsert 머지 규칙 (D-064):
  - p_inventory_refs = NULL → 기존 refs 유지 (변경 없음)
  - p_inventory_refs = {} → 기존 refs 전부 삭제
  - p_inventory_refs에 특정 타입만 포함 → 해당 타입만 upsert, 나머지 유지

## 6) nyanstagram
- posts(id, author_id, body, log_date, visibility(private|public), published_at?, hide_from_profile bool,
  like_count int, comment_count int, meta jsonb default '{}', hidden_at?, created_at, updated_at, deleted_at)
  - constraint(권장): CHECK (NOT (visibility='private' AND published_at IS NOT NULL))
  - constraint: CHECK (char_length(body) BETWEEN 1 AND 5000) — D-087
  - meta: v1은 images(storage key 배열, max 5)를 저장. See D-088.
  - 전이 규칙: visibility를 private로 변경하면 published_at=NULL 강제(서버/RPC) + DB CHECK로 방어
  - index: (author_id, log_date desc), (visibility,published_at desc where public+published), (published_at desc)
- comments(id, post_id, author_id, body, edited_at?, like_count, hidden_at?, created_at, updated_at, deleted_at)
  - constraint: CHECK (char_length(body) BETWEEN 1 AND 2000) — D-087
- comment_revisions(id, comment_id, previous_body, created_at) — 이전 본문 1개만 유지(내부 감사)

## 7) channel
- topics(id, slug unique, name, description?, is_public=true, created_at, updated_at, deleted_at)
- topic_follows(user_id, topic_id, created_at) pk(user_id, topic_id)
- threads(id, topic_id, author_id, title, body, like_count, reply_count, hidden_at?, created_at, updated_at, deleted_at)
  - constraint: CHECK (char_length(title) BETWEEN 1 AND 120) — D-087
  - constraint: CHECK (char_length(body) BETWEEN 1 AND 10000) — D-087
  - fts_vector tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(body,''))) STORED — D-092
  - index: GIN(fts_vector)
- replies(id, thread_id, author_id, body, edited_at?, like_count, hidden_at?, created_at, updated_at, deleted_at)
  - constraint: CHECK (char_length(body) BETWEEN 1 AND 5000) — D-087
  - 1-depth(부모 reply 없음)
  - 수정 정책: comments와 동일(D-009 적용). edited_at 표기 + 내부 감사로그(reply_revisions).
- reply_revisions(id, reply_id, previous_body, created_at) — 이전 본문 1개만 유지(내부 감사)

## 8) likes(공통)
- likes(id, user_id, target_type(post|comment|thread|reply), target_id, created_at)
  - unique(user_id, target_type, target_id)
  - unlike은 hard DELETE로 처리한다(soft delete 미사용).

## 8a) notifications (in-app inbox, v1)
- notifications(id, user_id, type(comment|reply|like), actor_id, target_type(post|thread), target_id, read_at?, created_at)
  - index: (user_id, created_at desc), (user_id, read_at)
  - type-target 매핑(v1 LOCK):
    - comment -> target_type='post', target_id=post_id
    - reply -> target_type='thread', target_id=thread_id
    - like -> target_type='post'만 허용(v1 단순화)

## 9) moderation
- blocks(blocker_id, blocked_id, created_at) pk(blocker_id, blocked_id)
- reports(id, reporter_id, target_type, target_id, reason_code, note?, snapshot jsonb, created_at, deleted_at)
  - constraint(권장): UNIQUE(reporter_id, target_type, target_id) WHERE deleted_at IS NULL
  - 의미: 동일 사용자의 동일 대상 중복 신고 방지
- moderation_actions(id, actor_id, action, target_type, target_id, meta jsonb?, created_at)

## 10) 집계/보정(권장)
- like_count/reply_count/comment_count: v1은 write RPC 내 원자 increment/decrement만 구현(D-046, D-100). 배치 보정(전체 재계산)은 Phase 3 pg_cron 잡으로 구현(D-069)

## 11) payload_versions / KPI
- payload_versions(version text pk, state(ACTIVE|DEPRECATED|REJECT), meta jsonb?, created_at, updated_at)
- payload_version_events(id, ts, version, event_type(seen|reject|normalize_fail|unknown), request_id?, reason?, created_at)
- payload_version_rollups(version, bucket_ts, seen_count, reject_count, normalize_fail_count, unknown_count, last_seen_at)

## 12) ops_metrics
- ops_metrics(id, ts, metric_key, metric_value_num?, metric_value_text?, meta jsonb?, created_at)
  - index: (metric_key, ts desc)

## 13) app_config (운영 파라미터 SSOT)
- app_config(key text pk, value jsonb not null, updated_at timestamptz, updated_by uuid? fk profiles.id)
- key(v1):
  - rate_limits
  - rate_limits_new_account
  - auto_hide
  - popular_feed
- 주의:
  - 비밀값(토큰/키/내부 전용 플래그)은 절대 저장 금지.
  - 새로운 key 추가 시: D-056 + RPC whitelist 업데이트가 선행.

# DATA-MODEL — DB 스키마(설계 기준)

원칙:
- id: uuid
- created_at/updated_at/ deleted_at(soft delete)
- hidden_at(운영 숨김)
- 공개 조회는 hidden/deleted/blocked 필터 강제
- log_date는 오늘 이하만

## 1) profiles
- profiles(id pk, nickname unique, avatar_url, bio, created_at, updated_at)
- profile_settings(user_id pk, inventory_visibility=private|public, default_post_visibility?, created_at, updated_at)

## 2) cats
- cats(id pk, owner_id, name, birth_date, sex, breed, avatar_url, created_at, updated_at, deleted_at)
- index: (owner_id, deleted_at), (owner_id, name)

## 3) catalog (AC-3)
- catalog_items(id, type, standard_name, brand, metadata, created_at, updated_at)
  - unique(type, standard_name)
- catalog_aliases(id, type, alias unique per type, catalog_item_id, created_at)
- catalog_suggestions(id, type, raw_text, suggested_by, status(pending/approved/rejected),
  resolved_catalog_item_id?, reviewed_by?, review_note?, created_at, updated_at)

## 4) inventory_items
- inventory_items(id, owner_id, type, catalog_item_id?, raw_text, is_current, changed_at, note?, created_at, updated_at, deleted_at)
- index: (owner_id, type, is_current), (owner_id, deleted_at)

## 5) observation (다묘)
- observation_groups(id, owner_id, log_date, common_payload jsonb, version int, idempotency_key?, created_at, updated_at, deleted_at)
  - (선택) unique(owner_id, log_date) — 날짜당 1묶음으로 고정할 때
- observations(id, group_id, owner_id, cat_id, status(active|excluded), override_payload jsonb?, created_at, updated_at, deleted_at)
  - unique(group_id, cat_id)
- 필수: 트랜잭션 + idempotency + expected_version 기반 충돌 처리

## 6) nyanstagram
- posts(id, author_id, body, log_date, visibility(private|public), published_at?, hide_from_profile bool,
  like_count int, comment_count int, hidden_at?, created_at, updated_at, deleted_at)
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
- reports(id, reporter_id, target_type, target_id, reason_code, note?, created_at)
- moderation_actions(id, actor_id, action, target_type, target_id, meta jsonb?, created_at)

## 10) 집계/보정(권장)
- like_count/reply_count/comment_count는 트리거 또는 배치로 보정 가능(OPEN: 주기/방식)

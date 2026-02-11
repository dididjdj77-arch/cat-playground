# SCHEMA-MIGRATIONS — 스키마 마이그레이션 체크리스트

## 필수 마이그레이션 (v1.1 기준)

### ✅ 완료된 마이그레이션
- (아직 없음)

### 🔲 진행 예정 마이그레이션

#### 1. house 도메인 추가
- [ ] house_profiles 테이블 생성
  - user_id (pk)
  - visibility (private|public)
  - published_at (nullable)
  - hidden_at (nullable)
  - deleted_at (nullable)
  - created_at, updated_at
  - **CHECK**: NOT (visibility = 'private' AND published_at IS NOT NULL)
- [ ] house_slots 테이블 생성
  - id (pk, uuid)
  - owner_id
  - room_key (text, default 'living_room')
  - slot_key (text)
  - inventory_item_id (nullable)
  - equipped_at (nullable)
  - created_at, updated_at, deleted_at
  - unique(owner_id, room_key, slot_key)
  - FK: inventory_item_id → inventory_items.id (nullable)
- [ ] inventory_items current 무결성 인덱스 추가(부분 유니크)
  - UNIQUE(owner_id, type) WHERE is_current=true AND deleted_at IS NULL

#### 2. observation_groups 확장
- [ ] payload_version 컬럼 추가 (text, not null)
- [ ] idempotency_key: uuid, NOT NULL (D-041 TTL은 row cleanup으로 처리, NULL 비우기 금지)
- [ ] UNIQUE(owner_id, log_date) WHERE deleted_at IS NULL — 날짜당 1그룹 (D-060)
- [ ] 인덱스 추가:
  - (owner_id, log_date)
  - (owner_id, payload_version)
  - (owner_id, idempotency_key)

#### 2a. observation_patch_dedup 추가 (D-061)
- [ ] observation_patch_dedup 테이블 생성
  - id (pk, uuid)
  - owner_id (uuid, not null)
  - group_id (uuid, fk → observation_groups.id)
  - idempotency_key (uuid, not null)
  - result_json (jsonb)
  - created_at
  - UNIQUE(owner_id, group_id, idempotency_key)

#### 3. inventory_items 확장
- [ ] meta 컬럼 추가 (jsonb, default '{}')
- [ ] raw_text: NOT NULL, CHECK(char_length BETWEEN 1 AND 200) — D-086, D-087
- [ ] reason_code: CHECK (reason_code IN ('initial','switch','correction')) — D-075
- [ ] reason_note: CHECK(char_length <= 500) — D-087

#### 4. profiles / auth bootstrap 정리 (D-066, D-067, D-068)
- [ ] profiles-auth 1:1 연결 키 고정
  - profiles.user_id (uuid, NOT NULL, UNIQUE, FK -> auth.users.id)
  - 주의: v1에서 profiles.id는 내부 PK 유지(독립 PK 유지)
- [ ] profiles 약관/운영 컬럼 정리
  - terms_agreed_at (timestamptz, nullable 유지; NOT NULL 금지)
  - is_admin (boolean, NOT NULL, default false)
- [ ] profiles 아바타 컬럼 명확화
  - profiles.avatar_key 컬럼 추가/유지 (canonical)
  - 기존 profiles.avatar_url -> profiles.avatar_key backfill
  - profiles.avatar_url은 deprecated로 유지(신규 write 금지), 제거는 후속 migration으로 분리
- [ ] cats 아바타 컬럼 정합(B안)
  - cats.avatar_key 컬럼 추가 (canonical)
  - 기존 cats.avatar_url -> cats.avatar_key backfill
  - cats.avatar_url은 deprecated로 유지(신규 write 금지), 제거는 후속 migration으로 분리
- [ ] auth bootstrap trigger 최소 작업 원칙
  - auth.users -> profiles upsert 1회
  - trigger 예외는 signup 경로를 끊지 않도록 흡수
  - bootstrap_errors 로그 테이블(예: auth_profile_bootstrap_errors) 또는 동등 로깅 경로 준비

#### 5. payload_versions + KPI 시스템
- [ ] payload_versions 테이블 생성
  - version (text, pk)
  - state (ACTIVE|DEPRECATED|REJECT)
  - meta (jsonb, nullable)
  - created_at, updated_at
- [ ] payload_version_events 테이블 생성
  - id (pk)
  - ts (timestamp)
  - version (text)
  - event_type (seen|reject|normalize_fail)
  - request_id (nullable)
  - reason (nullable)
  - created_at
- [ ] payload_version_rollups 테이블 생성
  - version (text)
  - bucket_ts (timestamp)
  - seen_count, reject_count, normalize_fail_count
  - last_seen_at

#### 6. ops_metrics
- [ ] ops_metrics 테이블 생성
  - id (pk)
  - ts (timestamp)
  - metric_key (text)
  - metric_value_num (nullable)
  - metric_value_text (nullable)
  - meta (jsonb, nullable)
  - created_at
  - index: (metric_key, ts desc)

#### 7. posts CHECK 제약 추가
- [ ] posts 테이블에 CHECK 추가
  - CHECK: NOT (visibility = 'private' AND published_at IS NOT NULL)
- [ ] posts.body CHECK(char_length BETWEEN 1 AND 5000) — D-087
- [ ] posts.meta jsonb default '{}' — D-088

#### 7a. channel 길이 제약 + FTS (D-087, D-092)
- [ ] threads.title CHECK(char_length BETWEEN 1 AND 120)
- [ ] threads.body CHECK(char_length BETWEEN 1 AND 10000)
- [ ] threads.fts_vector: generated column + GIN index (config='simple')
- [ ] replies.body CHECK(char_length BETWEEN 1 AND 5000)
- [ ] comments.body CHECK(char_length BETWEEN 1 AND 2000)

#### 8. comment_revisions 테이블 생성 (D-009)
- [ ] comment_revisions 테이블 생성
  - id (pk, uuid)
  - comment_id (fk → comments.id)
  - previous_body (text, not null)
  - created_at
  - index: (comment_id)

#### 8a. reply_revisions 테이블 생성 (D-009 적용)
- [ ] reply_revisions 테이블 생성
  - id (pk, uuid)
  - reply_id (fk → replies.id)
  - previous_body (text, not null)
  - created_at
  - index: (reply_id)

#### 9. reports snapshot 추가 (D-052)
- [ ] reports.snapshot (jsonb, nullable) 컬럼 추가
- [ ] reports.deleted_at (timestamptz, nullable) 컬럼 확인/없으면 추가

#### 10. 닉네임 변경 지원 (D-051)
- [ ] **v1 스킵**: 닉네임 변경 기능은 v1에서 구현하지 않는다(D-051 v1 범위 참조).

#### 11. app_config (D-056)
- [ ] app_config 테이블 생성
  - key (text, pk)
  - value (jsonb, not null)
  - updated_at, updated_by
- [ ] RLS + RPC(read):
  - 원본 테이블 direct select 금지(권장)
  - rpc_get_app_config(keys[])로만 읽기 + key whitelist
- [ ] seed 초기 데이터:
  - rate_limits (D-053)
  - rate_limits_new_account (D-053)
  - auto_hide (D-054)
  - popular_feed (D-076)

#### 12. notifications (D-070)
- [ ] notifications 테이블 생성
  - id (pk, uuid)
  - user_id (uuid, not null)
  - type (comment|reply|like)
  - actor_id (uuid, not null)
  - target_type (post|thread)
  - target_id (uuid, not null)
  - read_at (timestamptz, nullable)
  - created_at (timestamptz, not null default now())
- [ ] 인덱스 추가
  - (user_id, created_at desc)
  - (user_id, read_at)
- [ ] type-target 매핑 CHECK/가드 반영(v1 LOCK)
  - comment -> target_type='post'
  - reply -> target_type='thread'
  - like -> target_type='post'만 허용

#### 13. Storage buckets/policies (D-067)
- [ ] private 원본 버킷 생성: assets
- [ ] public 썸네일 버킷 생성: assets-public
- [ ] 경로(prefix) 가드 반영
  - 원본: avatars/{user_id}/{uuid}, posts/{user_id}/{post_id}/{uuid}, cats/{user_id}/{cat_id}/{uuid}
  - 공개 썸네일: posts/{post_id}/{uuid}_thumb (공개+발행 콘텐츠 파생본만)
- [ ] 접근 정책
  - assets: owner write/read(signed URL) 기본
  - assets-public: 썸네일 anon read 허용(공개+발행 상태 파생본만)

#### 14. admin DB objects only (D-068)
- [ ] profiles.is_admin 기반 allowlist 컬럼/인덱스 준비
- [ ] 운영 감사 테이블(moderation_actions) 스키마 점검/보강
- [ ] 주의: 관리자 전용 RPC 생성/계약 정의는 SCHEMA-MIGRATIONS 범위가 아니다
  - RPC 계약/생성은 docs/RPC-SPECS.md + 구현 EP 체크리스트에서 관리

#### 15. pg_cron 실행체 연결 (D-069)
- [ ] pg_cron extension/job 등록 경로 준비
- [ ] 대상 작업 등록
  - observation_groups idempotency cleanup (D-041)
  - observation_patch_dedup cleanup (D-061)
  - payload_version_events retention (D-045)
  - like/comment/reply 집계 보정
- [ ] 등록 원칙
  - DB job schedule은 UTC 기준으로 등록
  - SSOT로 고정하는 것은 주기(cadence)이며, minute offset은 default 값(운영 조정 가능)으로 둔다
  - 주기/환산표 기준 문서는 docs/CONFIG-BASELINES.md에서 관리

## 마이그레이션 실행 원칙
1. 백업 먼저
2. 테스트 환경에서 선행 검증
3. 롤백 스크립트 준비
4. 마이그레이션 로그 기록
5. 완료 후 체크리스트 업데이트

## 마일스톤 (1) migration file order (요약)
- 001_extensions.sql
- 002_profiles.sql
- 003_cats.sql
- 004_catalog.sql
- 005_inventory.sql
- 006_observation.sql
- 007_nyanstagram.sql (posts + comments + comment_revisions)
- 008_channel.sql (topics + threads + replies + reply_revisions + FTS)
- 009_likes.sql
- 010_house.sql
- 011_moderation.sql (blocks + reports + moderation_actions)
- 012_ops.sql (ops_metrics + payload_versions + events + rollups)
- 013_notifications.sql
- 014_app_config.sql (테이블 + RPC + seed)
- 015_auth_trigger.sql
- 016_storage.sql (buckets + policies)
- 017_length_checks.sql (D-075 CHECK 제약 일괄)
- 018_guard_functions.sql
- 019_rls.sql

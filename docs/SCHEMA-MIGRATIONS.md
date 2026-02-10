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

#### 4. profile_settings 정리
- [ ] inventory_visibility 컬럼 정리 (레거시일 수 있음; 존재 시 제거/비활성)

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

## 마이그레이션 실행 원칙
1. 백업 먼저
2. 테스트 환경에서 선행 검증
3. 롤백 스크립트 준비
4. 마이그레이션 로그 기록
5. 완료 후 체크리스트 업데이트

## 마일스톤 (1) migration file order (요약)
- 001_extensions.sql
- 002_profiles.sql
- …
- 013_seed.sql
- 014_app_config.sql

# SCHEMA-MIGRATIONS — 스키마 마이그레이션 체크리스트

현재 스키마 기준(문서상)과 해야 할 migration 목록

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
- [ ] house_slots 테이블 생성
  - id (pk, uuid)
  - owner_id
  - room_key (text, default 'living_room')
  - slot_key (text)
  - inventory_item_id (nullable)
  - equipped_at (nullable)
  - created_at, updated_at, deleted_at
  - unique(owner_id, room_key, slot_key)

- [ ] inventory_items current 무결성 인덱스 추가(부분 유니크)
  - UNIQUE(owner_id, type) WHERE is_current=true AND deleted_at IS NULL

#### 2. observation_groups 확장
- [ ] payload_version 컬럼 추가 (text, not null)
- [ ] idempotency_key를 nullable에서 not null로 변경, 타입 uuid로 명시
- [ ] 인덱스 추가:
  - (owner_id, log_date)
  - (owner_id, payload_version)
  - (owner_id, idempotency_key)

#### 3. inventory_items 확장
- [ ] meta 컬럼 추가 (jsonb, default '{}')

#### 4. profile_settings 정리
- [ ] inventory_visibility 컬럼 제거 (또는 deprecated 마킹)

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

## 마이그레이션 실행 원칙
1. 백업 먼저
2. 테스트 환경에서 선행 검증
3. 롤백 스크립트 준비
4. 마이그레이션 로그 기록
5. 완료 후 체크리스트 업데이트

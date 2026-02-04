# EP-HOUSE-IMPL — House 구현 실행 계획

> 3단계 EP로 House 도메인 구현. 각 EP는 독립 검증 가능.
> See: D-035, D-036, D-037, D-043, D-055, D-057~D-061

---

## 개요

| EP | 이름 | 산출물 | 선행 조건 |
|----|------|--------|----------|
| EP-1 | Foundation | 스키마 + Guard 함수 + 본인 RPC | profiles, inventory_items, catalog_items, blocks 테이블 |
| EP-2 | Public Access | 공개 조회 RPC | EP-1 완료 |
| EP-3 | Integration | CI 테스트 + QA | EP-1, EP-2 완료 |

---

## EP-1: Foundation (스키마 + Guard + 본인 RPC)

### SSOT read first
- docs/DATA-MODEL.md (house 섹션)
- docs/RPC-SPECS.md (Guard 패턴, House RPC 본인용)
- docs/DECISIONS.md (D-035, D-057, D-059, D-060)

### Goal
- House 스키마(house_profiles, house_slots) 생성
- Guard 함수 3개 구현
- 본인용 RPC 3개 구현

### Non-goals
- 공개 조회 RPC (EP-2)
- CI 테스트 (EP-3)

### Scope control
- Allowed changes:
  - supabase/migrations/015_house_foundation.sql
- Forbidden changes:
  - 기존 테이블 수정
  - 다른 도메인 RPC

### 산출물
```
├─ house_profiles 테이블
├─ house_slots 테이블
├─ guard_soft_state(timestamptz, timestamptz) → boolean
├─ guard_block(uuid, uuid) → boolean
├─ guard_visibility_published(text, timestamptz) → boolean
├─ rpc_get_my_house() → jsonb
├─ rpc_save_house_slot(text, uuid) → jsonb
└─ rpc_delete_house_slot(text) → jsonb
```

### 입력 요구사항 (선행 조건)
- profiles 테이블 존재
- inventory_items 테이블 존재 (is_current 컬럼 포함)
- catalog_items 테이블 존재
- blocks 테이블 존재

### 계약 (Contract)
- Guard 함수는 BOOLEAN 반환
- 본인 RPC는 auth.uid() IS NOT NULL 필수
- rpc_save_house_slot: inventory_items.is_current=true만 허용
- slot_key 허용 범위: slot_01 ~ slot_08 (D-059)

### DoD (검증 — 5분)

```sql
-- 1. 스키마 존재 확인
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'house_profiles';
-- 기대: user_id, visibility, published_at, hidden_at, deleted_at, created_at, updated_at

SELECT column_name FROM information_schema.columns 
WHERE table_name = 'house_slots';
-- 기대: id, owner_id, room_key, slot_key, inventory_item_id, equipped_at, created_at, updated_at, deleted_at

-- 2. CHECK 제약 검증
INSERT INTO house_profiles (user_id, visibility, published_at)
VALUES (auth.uid(), 'private', now());
-- 기대: ERROR (CHECK 위반: private + published_at NOT NULL)

-- 3. Guard 함수 테스트
SELECT guard_soft_state(NULL, NULL);  -- 기대: TRUE
SELECT guard_soft_state(now(), NULL); -- 기대: FALSE
SELECT guard_soft_state(NULL, now()); -- 기대: FALSE

SELECT guard_block(NULL, gen_random_uuid()); -- 기대: FALSE (anon 차단)
-- (차단 없는 상태에서)
SELECT guard_block(auth.uid(), auth.uid()); -- 기대: TRUE (자기 자신)

SELECT guard_visibility_published('public', now()); -- 기대: TRUE
SELECT guard_visibility_published('public', NULL); -- 기대: FALSE
SELECT guard_visibility_published('private', now()); -- 기대: FALSE

-- 4. 본인 RPC 테스트
SELECT rpc_get_my_house();
-- 기대: house_profiles 자동 생성 + 빈 slots 배열

-- 5. slot_key 검증
SELECT rpc_save_house_slot('slot_99', '<some_inventory_item_id>');
-- 기대: ERROR 400 (slot_key 범위 외)

-- 6. is_current 검증 (non-current 아이템으로 테스트)
-- (사전에 is_current=false인 inventory_item 필요)
SELECT rpc_save_house_slot('slot_01', '<non_current_item_id>');
-- 기대: ERROR 400 (is_current=false)
```

### 롤백 스크립트
```sql
DROP FUNCTION IF EXISTS rpc_delete_house_slot(text);
DROP FUNCTION IF EXISTS rpc_save_house_slot(text, uuid);
DROP FUNCTION IF EXISTS rpc_get_my_house();
DROP FUNCTION IF EXISTS guard_visibility_published(text, timestamptz);
DROP FUNCTION IF EXISTS guard_block(uuid, uuid);
DROP FUNCTION IF EXISTS guard_soft_state(timestamptz, timestamptz);
DROP TABLE IF EXISTS house_slots;
DROP TABLE IF EXISTS house_profiles;
```

---

## EP-2: Public Access (공개 조회 RPC)

### SSOT read first
- docs/RPC-SPECS.md (House RPC 공개 조회)
- docs/DECISIONS.md (D-055, D-058)
- docs/AUTHZ-MODEL.md (§0-4)

### Goal
- 공개 조회 RPC 2개 구현
- 화이트리스트 DTO 강제
- 404 조건 통일 (NULL 반환)

### Non-goals
- CI 테스트 (EP-3)
- 성능 최적화

### Scope control
- Allowed changes:
  - supabase/migrations/016_house_public_rpc.sql
- Forbidden changes:
  - EP-1 산출물 수정
  - Guard 함수 수정

### 입력 요구사항 (EP-1 완료 필수)
- EP-1 산출물 전부 (Guard 3개, 테이블 2개, 본인 RPC 3개)
- profiles 테이블 (nickname 컬럼)

### 산출물
```
├─ rpc_get_public_house_slots_summary(uuid) → jsonb
└─ rpc_get_public_house_slots_summary_by_nickname(text) → jsonb
```

### 계약 (Contract)
- 반환 DTO는 화이트리스트만 (D-055)
- 조회 불가 시 NULL 반환 (D-058)
- viewer_id는 auth.uid() (anon → NULL → guard_block에서 차단)

### DoD (검증 — 10분)

```sql
-- Setup: 테스트 유저 A, B 생성 (사전 준비 필요)
-- A의 하우스 설정: public + published

-- Case 1: 공개+발행 (로그인 B가 A 조회)
UPDATE house_profiles SET visibility='public', published_at=now() 
WHERE user_id = '<A_user_id>';

-- B로 로그인한 상태에서
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: slots 배열 반환

-- Case 2: 미발행
UPDATE house_profiles SET published_at=NULL WHERE user_id='<A_user_id>';
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: NULL

-- Case 3: private
UPDATE house_profiles SET visibility='private', published_at=NULL WHERE user_id='<A_user_id>';
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: NULL

-- Case 4: hidden
UPDATE house_profiles SET visibility='public', published_at=now(), hidden_at=now() WHERE user_id='<A_user_id>';
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: NULL

-- Case 5: 차단
UPDATE house_profiles SET hidden_at=NULL WHERE user_id='<A_user_id>';
INSERT INTO blocks (blocker_id, blocked_id) VALUES ('<B_user_id>', '<A_user_id>');
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: NULL

-- Case 6: anon (로그아웃 상태)
-- anon으로 호출
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: NULL (guard_block에서 anon 차단)

-- Case 7: 화이트리스트 검증 (차단 해제 후)
DELETE FROM blocks WHERE blocker_id='<B_user_id>';
-- B로 로그인한 상태에서
SELECT result->'slots'->0 
FROM (SELECT rpc_get_public_house_slots_summary('<A_user_id>') as result) sub;
-- 기대 키: slot_key, equipped_at, type, catalog, days_since_equipped
-- 금지 키 없음: inventory_item_id, raw_text, note, meta, avatar_url

-- Case 8: non-current 슬롯 제외 (D-043)
-- (사전에 A의 슬롯에 바인딩된 아이템을 is_current=false로 변경)
SELECT rpc_get_public_house_slots_summary('<A_user_id>');
-- 기대: 해당 슬롯이 결과에서 제외됨
```

### 롤백 스크립트
```sql
DROP FUNCTION IF EXISTS rpc_get_public_house_slots_summary_by_nickname(text);
DROP FUNCTION IF EXISTS rpc_get_public_house_slots_summary(uuid);
```

---

## EP-3: Integration (CI + QA)

### SSOT read first
- docs/QA-SCENARIOS.md (하우스 섹션)
- docs/TESTING-STRATEGY.md

### Goal
- CI 테스트 구현 (차단 스냅샷, 화이트리스트)
- QA 시나리오 전체 확인

### Non-goals
- E2E 테스트
- 성능 테스트

### Scope control
- Allowed changes:
  - tests/house/*.test.ts (또는 적절한 테스트 경로)
- Forbidden changes:
  - EP-1, EP-2 산출물

### 입력 요구사항 (EP-1 + EP-2 완료 필수)
- 모든 House RPC 동작 확인됨
- 테스트 DB 환경

### 산출물
```
├─ tests/house/guard.test.ts
├─ tests/house/my-house.test.ts
├─ tests/house/public-house.test.ts
└─ tests/house/whitelist.test.ts
```

### DoD (검증 — 10분)
```bash
# CI 테스트 실행
npm test -- house

# 또는 pnpm/yarn
pnpm test -- house

# 기대: 모든 테스트 통과
```

### QA 체크리스트 (수동 확인)
- [ ] EP-1 본인 RPC 시나리오 (QA-SCENARIOS.md 참조)
- [ ] EP-2 공개 RPC 시나리오
- [ ] 화이트리스트 검증 (허용/금지 필드)

### 롤백 스크립트
```bash
# 테스트 파일만 삭제
rm -rf tests/house/
```

---

## 전체 롤백 순서 (최악의 경우)

EP-3 → EP-2 → EP-1 역순으로 실행:

```bash
# EP-3: 테스트만 삭제 (파일 시스템)
rm -rf tests/house/
```

```sql
-- EP-2 롤백
DROP FUNCTION IF EXISTS rpc_get_public_house_slots_summary_by_nickname(text);
DROP FUNCTION IF EXISTS rpc_get_public_house_slots_summary(uuid);

-- EP-1 롤백
DROP FUNCTION IF EXISTS rpc_delete_house_slot(text);
DROP FUNCTION IF EXISTS rpc_save_house_slot(text, uuid);
DROP FUNCTION IF EXISTS rpc_get_my_house();
DROP FUNCTION IF EXISTS guard_visibility_published(text, timestamptz);
DROP FUNCTION IF EXISTS guard_block(uuid, uuid);
DROP FUNCTION IF EXISTS guard_soft_state(timestamptz, timestamptz);
DROP TABLE IF EXISTS house_slots;
DROP TABLE IF EXISTS house_profiles;
```

---

## 점진적 통합 체크포인트

### EP-1 완료 직후
```sql
SELECT rpc_get_my_house();
-- 기대: 정상 응답 (다음 단계 연결 확인)
```

### EP-2 완료 직후
```sql
SELECT rpc_get_public_house_slots_summary('<test_user_id>');
-- 기대: Guard 동작 확인 (NULL 또는 데이터)
```

### EP-3 완료
```bash
npm test -- house
# 기대: 전체 통과
```

---

## 위험 관리

| 위험 | 대응 |
|------|------|
| EP-1 Guard 함수 시그니처 오류 | DoD 테스트로 즉시 발견 → 수정 후 재배포 |
| EP-2에서 EP-1 Guard와 불일치 | EP-2 시작 전 EP-1 Guard 단위 테스트 재실행 |
| 화이트리스트 누락 | EP-3 CI에서 금지 필드 assertion으로 자동 감지 |
| anon 접근 허용 버그 | guard_block(NULL, ...) → FALSE 보장 (D-057) |

---

## 참조 결정

- D-035: 하우스 공개 상태 모델 (visibility + published_at)
- D-036: 공개 하우스 ≠ 인벤토리 공개
- D-037: 공개 하우스에서 cats.avatar_url 금지
- D-043: current 변경 후 슬롯 노출 규칙
- D-055: PublicHouseSlotSummaryDTO 화이트리스트
- D-057: Guard 함수 시그니처 표준
- D-058: House RPC 404 반환 방식 (NULL)
- D-059: v1 room_key 하드코딩 + slot_key 검증
- D-060: house_profiles 자동 생성 정책
- D-061: House 구현 실행 계획 (이 문서)

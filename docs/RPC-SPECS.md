# RPC-SPECS — RPC 시그니처 및 Guard 패턴

v1.1 기준 최소 RPC 목록과 공통 guard 패턴

## 공통 Guard 패턴

모든 외부/공개/상품성 RPC는 내부에서 다음을 강제:

### guard_soft_state(p_deleted_at timestamptz, p_hidden_at timestamptz) RETURNS boolean
```sql
CREATE OR REPLACE FUNCTION guard_soft_state(
  p_deleted_at timestamptz,
  p_hidden_at timestamptz
) RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT (p_deleted_at IS NULL AND p_hidden_at IS NULL);
$$;
```
- 둘 다 NULL이면 TRUE
- 하나라도 NOT NULL이면 FALSE
- See: D-057

### guard_block(p_viewer_id uuid, p_target_user_id uuid) RETURNS boolean
```sql
CREATE OR REPLACE FUNCTION guard_block(
  p_viewer_id uuid,
  p_target_user_id uuid
) RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT 
    CASE 
      -- auth-only 정책: anon(NULL)이면 무조건 FALSE (D-057, D-035)
      WHEN p_viewer_id IS NULL THEN FALSE
      -- 차단 관계 확인 (상호 차단)
      WHEN EXISTS (
        SELECT 1 FROM blocks 
        WHERE (blocker_id = p_viewer_id AND blocked_id = p_target_user_id)
           OR (blocker_id = p_target_user_id AND blocked_id = p_viewer_id)
      ) THEN FALSE
      ELSE TRUE
    END;
$$;
```
- p_viewer_id IS NULL → FALSE (House auth-only 정책 강제)
- 상호 차단 관계 → FALSE
- 그 외 → TRUE
- See: D-057, D-019

### guard_visibility_published(p_visibility text, p_published_at timestamptz) RETURNS boolean
```sql
CREATE OR REPLACE FUNCTION guard_visibility_published(
  p_visibility text,
  p_published_at timestamptz
) RETURNS boolean
LANGUAGE sql IMMUTABLE
AS $$
  SELECT (p_visibility = 'public' AND p_published_at IS NOT NULL);
$$;
```
- See: D-057

---

추가 규칙(SECURITY DEFINER 공개 RPC):
- viewer_id는 서버에서 auth.uid()로 도출한다(anon이면 null).
- viewer_id를 파라미터로 받지 않는 것을 원칙으로 한다.
- 부득이하게 p_viewer_id를 받는 경우, 입력을 무시하고 내부에서 viewer_id := auth.uid()로 덮어쓴다.

## 관찰 RPC (고위험)

### rpc_upsert_observation_group_with_items
- 접근: auth-only (auth.uid() required). owner_id는 auth.uid()로 고정(파라미터로 받지 않음).
```sql
-- 시그니처 (의사 코드)
FUNCTION rpc_upsert_observation_group_with_items(
  p_payload_version text,
  p_log_date date,
  p_idempotency_key uuid,
  p_common_payload jsonb,
  p_items jsonb -- [{cat_id, status, override_payload}]
) RETURNS jsonb
```
- 트랜잭션 필수
- payload_version 검증:
  - REJECT → 400 error
  - ACTIVE/DEPRECATED → 저장 허용
- idempotency_key 기반 중복 방지
- 반환: {group_id, version, items[]}

### rpc_patch_observation_items
- 접근: auth-only (auth.uid() required)
```sql
FUNCTION rpc_patch_observation_items(
  p_group_id uuid,
  p_expected_version int,
  p_idempotency_key uuid,
  p_patches jsonb
) RETURNS jsonb
```
- expected_version != current_version → 409 conflict
- 409 응답 구조:
  ```json
  {
    "error_code": "version_conflict",
    "current_version": 5,
    "current_group_snapshot": {...}
  }
  ```
- 성공 시 반환: {new_version, items[]}

## 공개 조회 RPC (대표 예시)

### rpc_get_public_posts_feed
```sql
FUNCTION rpc_get_public_posts_feed(
  p_cursor text,
  p_limit int
) RETURNS jsonb
```
- 접근: anon 가능. viewer_id는 내부에서 auth.uid()로 도출(anon이면 null).
- 내부에서 guard_soft_state() 적용
- guard_block(viewer_id, post.author_id) 적용
- guard_visibility_published() 적용
- 반환 컬럼 화이트리스트

### rpc_get_public_threads_feed
```sql
FUNCTION rpc_get_public_threads_feed(
  p_topic_id uuid,
  p_sort text, -- 'new'|'popular'|'following'
  p_cursor text,
  p_limit int
) RETURNS jsonb
```
- 접근: anon 가능. viewer_id는 내부에서 auth.uid()로 도출(anon이면 null).
- guard_soft_state() 적용
- guard_block(viewer_id, thread.author_id) 적용
- threads/replies에는 visibility/published 가드 적용하지 않는다.
- 반환 컬럼 화이트리스트

---

## House RPC (본인용)

### rpc_get_my_house
```sql
CREATE OR REPLACE FUNCTION rpc_get_my_house()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_result jsonb;
BEGIN
  -- auth 필수
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'PGRST301';
  END IF;
  
  -- house_profiles 자동 생성 (D-060)
  INSERT INTO house_profiles (user_id, visibility, published_at)
  VALUES (v_user_id, 'private', NULL)
  ON CONFLICT (user_id) DO NOTHING;
  
  -- 결과 조합
  SELECT jsonb_build_object(
    'profile', jsonb_build_object(
      'visibility', hp.visibility,
      'published_at', hp.published_at
    ),
    'room_key', 'living_room',
    'slots', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'slot_key', hs.slot_key,
        'equipped_at', hs.equipped_at,
        'inventory_item_id', hs.inventory_item_id,
        'type', ii.type,
        'catalog_standard_name', ci.standard_name,
        'is_current', ii.is_current,
        'non_current_warning', CASE WHEN ii.id IS NOT NULL AND ii.is_current = false THEN true ELSE false END
      ) ORDER BY hs.slot_key)
      FROM house_slots hs
      LEFT JOIN inventory_items ii ON ii.id = hs.inventory_item_id AND ii.deleted_at IS NULL
      LEFT JOIN catalog_items ci ON ci.id = ii.catalog_item_id
      WHERE hs.owner_id = v_user_id 
        AND hs.room_key = 'living_room'
        AND hs.deleted_at IS NULL
    ), '[]'::jsonb)
  ) INTO v_result
  FROM house_profiles hp
  WHERE hp.user_id = v_user_id;
  
  RETURN v_result;
END;
$$;
```
- 접근: auth-only (auth.uid() IS NOT NULL 필수)
- 동작:
  1. house_profiles에서 auth.uid() 조회
  2. row 없으면 자동 생성 (D-060): visibility='private', published_at=NULL
  3. house_slots에서 owner_id=auth.uid(), room_key='living_room' 조회
  4. 각 슬롯에 대해 inventory_items JOIN → is_current 체크
- 반환:
```json
{
  "profile": {
    "visibility": "private|public",
    "published_at": "timestamp|null"
  },
  "room_key": "living_room",
  "slots": [
    {
      "slot_key": "slot_01",
      "equipped_at": "timestamp|null",
      "inventory_item_id": "uuid|null",
      "type": "food|null",
      "catalog_standard_name": "string|null",
      "is_current": true|false,
      "non_current_warning": true|false
    }
  ]
}
```
- See: D-043 (non_current_warning), D-060 (자동 생성)

### rpc_save_house_slot
```sql
CREATE OR REPLACE FUNCTION rpc_save_house_slot(
  p_slot_key text,
  p_inventory_item_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_allowed_slots text[] := ARRAY['slot_01','slot_02','slot_03','slot_04','slot_05','slot_06','slot_07','slot_08'];
  v_item_valid boolean;
  v_result jsonb;
BEGIN
  -- auth 필수
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'PGRST301';
  END IF;
  
  -- slot_key 검증 (D-059)
  IF NOT (p_slot_key = ANY(v_allowed_slots)) THEN
    RAISE EXCEPTION 'Invalid slot_key: %', p_slot_key USING ERRCODE = 'PGRST400';
  END IF;
  
  -- inventory_item 검증: owner + is_current=true (D-006, D-043)
  SELECT EXISTS (
    SELECT 1 FROM inventory_items
    WHERE id = p_inventory_item_id
      AND owner_id = v_user_id
      AND is_current = true
      AND deleted_at IS NULL
  ) INTO v_item_valid;
  
  IF NOT v_item_valid THEN
    RAISE EXCEPTION 'Invalid inventory_item: must be owned and is_current=true' USING ERRCODE = 'PGRST400';
  END IF;
  
  -- UPSERT slot
  INSERT INTO house_slots (owner_id, room_key, slot_key, inventory_item_id, equipped_at)
  VALUES (v_user_id, 'living_room', p_slot_key, p_inventory_item_id, now())
  ON CONFLICT (owner_id, room_key, slot_key) WHERE deleted_at IS NULL
  DO UPDATE SET 
    inventory_item_id = EXCLUDED.inventory_item_id,
    equipped_at = now(),
    updated_at = now();
  
  -- 결과 반환
  SELECT jsonb_build_object(
    'slot_key', hs.slot_key,
    'inventory_item_id', hs.inventory_item_id,
    'equipped_at', hs.equipped_at
  ) INTO v_result
  FROM house_slots hs
  WHERE hs.owner_id = v_user_id
    AND hs.room_key = 'living_room'
    AND hs.slot_key = p_slot_key
    AND hs.deleted_at IS NULL;
  
  RETURN v_result;
END;
$$;
```
- 접근: auth-only
- 검증:
  1. p_slot_key가 허용 리스트(slot_01~slot_08)에 있는지 (D-059)
  2. p_inventory_item_id가 owner_id=auth.uid() AND is_current=true인지
  3. 실패 시 400 에러
- 동작: UPSERT house_slots (owner_id, room_key='living_room', slot_key)
- 반환: 저장된 슬롯 정보

### rpc_delete_house_slot
```sql
CREATE OR REPLACE FUNCTION rpc_delete_house_slot(
  p_slot_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_allowed_slots text[] := ARRAY['slot_01','slot_02','slot_03','slot_04','slot_05','slot_06','slot_07','slot_08'];
BEGIN
  -- auth 필수
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'PGRST301';
  END IF;
  
  -- slot_key 검증 (D-059)
  IF NOT (p_slot_key = ANY(v_allowed_slots)) THEN
    RAISE EXCEPTION 'Invalid slot_key: %', p_slot_key USING ERRCODE = 'PGRST400';
  END IF;
  
  -- 슬롯 비우기 (soft clear)
  UPDATE house_slots
  SET inventory_item_id = NULL,
      equipped_at = NULL,
      updated_at = now()
  WHERE owner_id = v_user_id
    AND room_key = 'living_room'
    AND slot_key = p_slot_key
    AND deleted_at IS NULL;
  
  RETURN jsonb_build_object('ok', true);
END;
$$;
```
- 접근: auth-only
- 동작: house_slots에서 inventory_item_id=NULL, equipped_at=NULL로 업데이트 (soft clear)
- 반환: { "ok": true }

---

## House RPC (공개 조회)

### rpc_get_public_house_slots_summary
```sql
CREATE OR REPLACE FUNCTION rpc_get_public_house_slots_summary(
  p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_id uuid := auth.uid();
  v_hp record;
  v_result jsonb;
BEGIN
  -- Guard 1: house_profiles 조회
  SELECT * INTO v_hp
  FROM house_profiles
  WHERE user_id = p_target_user_id;
  
  IF NOT FOUND THEN
    RETURN NULL;  -- 404 (D-058)
  END IF;
  
  -- Guard 2: soft state (D-057)
  IF NOT guard_soft_state(v_hp.deleted_at, v_hp.hidden_at) THEN
    RETURN NULL;
  END IF;
  
  -- Guard 3: visibility + published (D-057)
  IF NOT guard_visibility_published(v_hp.visibility, v_hp.published_at) THEN
    RETURN NULL;
  END IF;
  
  -- Guard 4: block (D-057) - anon도 여기서 차단됨
  IF NOT guard_block(v_viewer_id, p_target_user_id) THEN
    RETURN NULL;
  END IF;
  
  -- 슬롯 조회 (화이트리스트 only, D-055)
  -- is_current=false인 슬롯은 제외 (D-043)
  SELECT jsonb_build_object(
    'slots', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'slot_key', hs.slot_key,
        'equipped_at', hs.equipped_at,
        'type', ii.type,
        'catalog', CASE 
          WHEN ci.id IS NOT NULL THEN jsonb_build_object(
            'standard_name', ci.standard_name,
            'brand', ci.brand
          )
          ELSE NULL
        END,
        'days_since_equipped', CASE 
          WHEN hs.equipped_at IS NOT NULL 
          THEN EXTRACT(DAY FROM (CURRENT_TIMESTAMP - hs.equipped_at))::int
          ELSE NULL
        END
      ) ORDER BY hs.slot_key)
      FROM house_slots hs
      INNER JOIN inventory_items ii ON ii.id = hs.inventory_item_id 
        AND ii.is_current = true  -- D-043: current만 포함
        AND ii.deleted_at IS NULL
      LEFT JOIN catalog_items ci ON ci.id = ii.catalog_item_id
      WHERE hs.owner_id = p_target_user_id
        AND hs.room_key = 'living_room'
        AND hs.deleted_at IS NULL
        AND hs.inventory_item_id IS NOT NULL  -- 빈 슬롯 제외
    ), '[]'::jsonb)
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;
```
- 접근: auth-only (auth.uid() IS NOT NULL 필수)
- viewer_id: 내부에서 auth.uid()로 도출
- Guard 적용 순서:
  1. house_profiles 조회 → 없으면 NULL 반환
  2. guard_soft_state(hp.deleted_at, hp.hidden_at) → FALSE면 NULL
  3. guard_visibility_published(hp.visibility, hp.published_at) → FALSE면 NULL
  4. guard_block(auth.uid(), p_target_user_id) → FALSE면 NULL
- 슬롯 조회:
  - house_slots INNER JOIN inventory_items ON is_current=true (D-043)
  - is_current=false인 슬롯은 결과에서 제외
- 반환 화이트리스트 (D-055):
```json
{
  "slots": [
    {
      "slot_key": "slot_01",
      "equipped_at": "timestamp|null",
      "type": "food|null",
      "catalog": {
        "standard_name": "string|null",
        "brand": "string|null"
      },
      "days_since_equipped": 7
    }
  ]
}
```
- 금지 필드 (절대 포함 금지):
  - inventory_item_id, inventory_items.id
  - raw_text, note, meta
  - cats.avatar_url
  - catalog_item_id
- 조회 불가 시: NULL 반환 (D-058, 클라이언트가 404로 매핑)

### rpc_get_public_house_slots_summary_by_nickname
```sql
CREATE OR REPLACE FUNCTION rpc_get_public_house_slots_summary_by_nickname(
  p_nickname text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_user_id uuid;
BEGIN
  -- nickname → user_id 변환
  SELECT id INTO v_target_user_id
  FROM profiles
  WHERE nickname = p_nickname;
  
  IF NOT FOUND THEN
    RETURN NULL;  -- 404
  END IF;
  
  -- 위임
  RETURN rpc_get_public_house_slots_summary(v_target_user_id);
END;
$$;
```
- 내부에서 profiles 테이블로 nickname → user_id 변환
- user_id 없으면 NULL 반환
- 이후 rpc_get_public_house_slots_summary(user_id)로 위임

**House 공개 조회 상태코드 (공통)**:
- 상태코드: 미인증/비공개/숨김/삭제/차단/미발행은 모두 NULL 반환 → 클라이언트에서 404 매핑 (D-035, D-044, D-058)
- 설명: 로그인 필요 메시지는 UI 레이어에서 처리(존재 은닉 우선)

## 구현 결정 (확정)
- Guard 함수는 SQL 함수로 구현한다 (D-057)
- 플래너 최적화를 위해 IMMUTABLE/STABLE 명시
- SECURITY DEFINER 함수는 search_path = public 고정 + 입력 검증 필수

## 운영 파라미터 RPC

### rpc_get_app_config
```sql
FUNCTION rpc_get_app_config(
  p_keys text[] -- 요청 key 목록
) RETURNS jsonb -- { "rate_limits": {...}, ... }
```
- 접근: auth-only (auth.uid() IS NOT NULL)

반환 key whitelist(v1):
- rate_limits
- rate_limits_new_account
- auto_hide

동작:
- p_keys 중 whitelist에 포함된 것만 반환한다.
- unknown key는 무시한다(호환성 목적).

구현 권장:
- SECURITY DEFINER
- search_path 고정

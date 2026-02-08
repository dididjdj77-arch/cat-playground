# RPC-SPECS — RPC 시그니처 및 Guard 패턴

v1.1 기준 최소 RPC 목록과 공통 guard 패턴

## 공통 Guard 패턴

모든 외부/공개/상품성 RPC는 내부에서 다음을 강제:

### guard_soft_state()
- deleted_at IS NULL
- hidden_at IS NULL (공개 노출 기준)

### guard_block(viewer_id, target_user_id)
- viewer_id와 target_user_id 간 block 관계 확인
- 상호 차단 시 비노출 처리
- viewer_id가 null(anon)인 경우 guard_block은 no-op (차단 필터 미적용)

### guard_visibility_published()
- visibility = 'public'
- published_at IS NOT NULL

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
  p_items jsonb, -- [{cat_id, status, override_payload}]
  p_inventory_refs jsonb default null -- {food_item_id?, litter_item_id?, toy_item_id?, furniture_item_id?}
) RETURNS jsonb
```
- 트랜잭션 필수
- payload_version 검증:
  - REJECT → 400 error
  - ACTIVE/DEPRECATED → 저장 허용
- idempotency_key 기반 중복 방지
- inventory refs 규칙:
  - upsert(초기 저장)에서만 observation_inventory_refs를 생성/설정한다.
  - p_inventory_refs의 key별 inventory_item_id는 inv_type(food/litter/toy/furniture)로 매핑해 저장한다.
  - 동일 group_id + inv_type는 upsert로 1건 유지한다.
- 반환: {group_id, version, items[], inventory_refs?}

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
- inventory refs 불변 규칙:
  - patch RPC는 observation_inventory_refs를 갱신하지 않는다.
  - p_patches 안에 inventory_refs 변경 의도가 포함되면 400(inventory_refs_immutable)으로 거부한다.
- 409 응답 구조:
  ```json
  {
    "error_code": "version_conflict",
    "current_version": 5,
    "current_group_snapshot": {...}
  }
  ```
- 성공 시 반환: {new_version, items[]}

## 인벤토리 mutation RPC (switch/discontinue)

### rpc_switch_inventory_item (owner)
```sql
FUNCTION rpc_switch_inventory_item(
  p_type text, -- food|litter|toy|furniture
  p_catalog_item_id uuid,
  p_raw_text text,
  p_reason_note text default null
) RETURNS jsonb
```
- 동작:
  - 기존 current(동일 type)를 is_current=false + ended_at=now()로 종료
  - 새 row를 is_current=true + reason_code='switch'로 insert

### rpc_discontinue_inventory_item (owner)
```sql
FUNCTION rpc_discontinue_inventory_item(
  p_type text, -- food|litter|toy|furniture
  p_reason_note text default null
) RETURNS jsonb
```
- 동작:
  - 기존 current(동일 type)만 is_current=false + ended_at=now() + reason_code='discontinue'로 종료
  - 새 row는 생성하지 않음

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

### rpc_get_public_house_slots_summary
```sql
FUNCTION rpc_get_public_house_slots_summary(
  p_target_user_id uuid
) RETURNS jsonb
```
- 접근: auth-only (auth.uid() required, anon 404)
- viewer_id는 내부에서 auth.uid()로 도출(입력으로 받지 않음)
- guard_soft_state() 적용: house_profiles.deleted_at/hidden_at is null, house_slots.deleted_at is null, inventory_items.deleted_at is null
- guard_visibility_published() 적용: house_profiles.visibility='public' AND house_profiles.published_at IS NOT NULL
- guard_block(viewer_id, p_target_user_id) 적용
- 반환 컬럼 화이트리스트(D-055)만: slot_key, equipped_at, type, (옵션) catalog 표준명/브랜드 등
- cats.avatar_url 금지
- inventory_item_id / inventory_items.id / raw_text / note / meta 금지

### rpc_get_public_house_slots_summary_by_nickname (선택)
```sql
FUNCTION rpc_get_public_house_slots_summary_by_nickname(
  p_target_nickname text
) RETURNS jsonb
```
- 접근: auth-only (auth.uid() required, anon 404)
내부에서 nickname → user_id resolve 후 rpc_get_public_house_slots_summary로 위임

동일 guard/화이트리스트 적용

**House 공개 조회 상태코드 (공통)**:
- 상태코드: 미인증/비공개/숨김/삭제/차단/미발행은 모두 404로 통일 (D-035, D-044)
- 설명: 로그인 필요 메시지는 UI 레이어에서 처리(존재 은닉 우선)

## 구현 결정 (검토 필요)
- guard 함수를 SQL 함수로 구현할지, RPC 내부 로직으로 구현할지는 구현 단계에서 결정
- 플래너 최적화를 위해 SQL 함수로 단순화 권장
- SECURITY DEFINER 함수는 search_path 고정 + 입력 검증 필수

## 운영 파라미터 RPC

### rpc_get_app_config
```sql
FUNCTION rpc_get_app_config(
  p_keys text[] -- 요청 key 목록
) RETURNS jsonb -- { "rate_limits": {...}, ... }
```
- 접근: auth-only (auth.uid() IS NOT NULL)

반환 key whitelist(v1):

rate_limits

rate_limits_new_account

auto_hide

동작:

p_keys 중 whitelist에 포함된 것만 반환한다.

unknown key는 무시한다(호환성 목적).

구현 권장:

SECURITY DEFINER

search_path 고정

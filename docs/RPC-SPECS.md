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

### guard_visibility_published()
- visibility = 'public'
- published_at IS NOT NULL

추가 규칙(SECURITY DEFINER 공개 RPC):
- viewer_id는 기본적으로 auth.uid()에서 도출한다(권장).
- viewer_id를 파라미터로 받는 경우, 함수 시작에서 반드시 assert:
  - (auth.uid() is null AND p_viewer_id is null) OR (p_viewer_id = auth.uid())
  - 불일치 시 error(입력 스푸핑 방지).

## 관찰 RPC (고위험)

### rpc_upsert_observation_group_with_items
```sql
-- 시그니처 (의사 코드)
FUNCTION rpc_upsert_observation_group_with_items(
  p_owner_id uuid,
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
  p_viewer_id uuid,
  p_cursor text,
  p_limit int
) RETURNS jsonb
```
- 내부에서 guard_soft_state() 적용
- guard_block(p_viewer_id, post.author_id) 적용
- guard_visibility_published() 적용
- 반환 컬럼 화이트리스트

### rpc_get_public_threads_feed
```sql
FUNCTION rpc_get_public_threads_feed(
  p_viewer_id uuid,
  p_topic_id uuid,
  p_sort text, -- 'new'|'popular'|'following'
  p_cursor text,
  p_limit int
) RETURNS jsonb
```
- 동일한 guard 패턴 적용

### rpc_get_public_house_slots_summary
```sql
FUNCTION rpc_get_public_house_slots_summary(
  p_target_user_id uuid
) RETURNS jsonb
```
내부에서 viewer_id는 auth.uid()로 도출(입력으로 받지 않음).

guard_soft_state() 적용:
- house_profiles.deleted_at/hidden_at is null
- house_slots.deleted_at is null
- inventory_items.deleted_at is null

guard_visibility_published() 적용:
- house_profiles.visibility='public' AND house_profiles.published_at IS NOT NULL

guard_block(auth.uid(), p_target_user_id) 적용(로그인 viewer만 의미 있음)

반환 컬럼 화이트리스트(요약 DTO)만:
- slot_key, equipped_at, type, (옵션) catalog 표준명/브랜드 등
- cats.avatar_url 금지
- inventory_item_id / inventory_items.id / raw_text / note / meta 금지

### rpc_get_public_house_slots_summary_by_nickname (선택)
```sql
FUNCTION rpc_get_public_house_slots_summary_by_nickname(
  p_target_nickname text
) RETURNS jsonb
```
내부에서 nickname → user_id resolve 후 rpc_get_public_house_slots_summary로 위임

동일 guard/화이트리스트 적용

## 구현 결정 (TODO)
- guard 함수를 SQL 함수로 구현할지, RPC 내부 로직으로 구현할지는 구현 단계에서 결정
- 플래너 최적화를 위해 SQL 함수로 단순화 권장
- SECURITY DEFINER 함수는 search_path 고정 + 입력 검증 필수

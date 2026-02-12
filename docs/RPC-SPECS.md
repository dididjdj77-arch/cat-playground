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

### guard_terms_agreed() — write RPC 전용
- profiles.terms_agreed_at IS NOT NULL
- 미동의 시 `{"error_code":"terms_not_agreed"}` 반환
- 모든 write RPC에 적용. read RPC 제외.
- See: D-073

### Write RPC guard 호출 순서 (LOCK)
- 모든 write RPC는 아래 순서로 guard를 평가한다.
  1. `guard_terms_agreed()`
  2. `guard_block(viewer_id, target_user_id)`
  3. `guard_soft_state(...)`
  4. domain-specific guard (`guard_visibility_published(...)` 등)
- RPC 성격상 불필요한 guard는 `N/A`로 명시하고 건너뛴다(순서 자체는 유지).
- 순서 근거: 약관 미동의는 최우선 차단, block은 데이터 조회 전 차단, soft_state/domain guard는 데이터 의존 단계다.
- See: D-096

추가 규칙(SECURITY DEFINER 공개 RPC):
- viewer_id는 서버에서 auth.uid()로 도출한다(anon이면 null).
- viewer_id를 파라미터로 받지 않는 것을 원칙으로 한다.
- 부득이하게 p_viewer_id를 받는 경우, 입력을 무시하고 내부에서 viewer_id := auth.uid()로 덮어쓴다.

## 관찰 RPC (고위험)

### rpc_upsert_observation_group_with_items
- 접근: auth-only (auth.uid() required). owner_id는 auth.uid()로 고정(파라미터로 받지 않음).
- write guard 순서 적용: `guard_terms_agreed()` 후 진행, 나머지 가드는 owner-write 특성상 N/A.
```sql
-- 시그니처 (의사 코드)
FUNCTION rpc_upsert_observation_group_with_items(
  p_payload_version text,
  p_log_date date,
  p_idempotency_key uuid,
  p_common_payload jsonb,
  p_items jsonb, -- [{cat_id, status, override_payload}]
  p_inventory_refs jsonb default null -- optional: {"food_item_id":"...","litter_item_id":"...","toy_item_id":"...","furniture_item_id":"..."}
) RETURNS jsonb
```
- 트랜잭션 필수
- payload_version 검증:
  - REJECT → 400 error
  - ACTIVE/DEPRECATED → 저장 허용
- idempotency_key 기반 중복 방지
- p_inventory_refs는 optional이며 NULL 허용이다. NULL이면 refs를 기록하지 않는다.
- upsert 시점에 p_inventory_refs가 주어지면 observation_inventory_refs에 타입별 inventory_item_id를 기록한다.
- refs 머지 규칙 (D-064):
  - p_inventory_refs = NULL → 기존 refs 유지
  - p_inventory_refs = {} → 기존 refs 전부 삭제
  - p_inventory_refs에 특정 타입만 → 해당 타입 upsert, 나머지 유지
- Patch RPC로는 observation_inventory_refs를 변경하지 않는다.
- 반환: {group_id, version, items[]}

### rpc_patch_observation_items
- 접근: auth-only (auth.uid() required)
- write guard 순서 적용: `guard_terms_agreed()` 후 진행, 나머지 가드는 owner-write 특성상 N/A.
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
- 멱등성: observation_patch_dedup(owner_id, group_id, idempotency_key) 기반.
  - 동일 키 재요청 → 기존 result_json 반환 (재실행 없음).
  - 동일 키 + 다른 payload 감지 → v1은 기존 결과 반환 + 서버 로그 warning. 409 미발생.
  - See: D-061

## 공통 입력 검증
- log_date: posts, observation_groups 모두 log_date <= CURRENT_DATE 강제. 위반 시 400 (D-010).

## 공개 조회 RPC (대표 예시)
- Public RPC 반환 DTO에는 inventory_items.id/raw_text/note/meta/reason_*/ended_at 등 owner-only 인벤 원장 필드를 포함하지 않는다(화이트리스트 원칙).

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

### rpc_get_public_post_comments
```sql
FUNCTION rpc_get_public_post_comments(
  p_post_id uuid,
  p_cursor text,
  p_limit int
) RETURNS jsonb
```
- 접근: anon 가능. viewer_id는 내부에서 auth.uid()로 도출(anon이면 null).
- 내부에서:
  1. 먼저 부모 post에 guard_soft_state() + guard_block(viewer_id, post.author_id) + guard_visibility_published() 적용. 불만족 시 404.
  2. 통과 시 comments에 guard_soft_state() + guard_block(viewer_id, comment.author_id) 적용.
- 댓글 독립 조회 경로(post 가드 없이 comment_id만으로 조회)는 공개 표면에서 금지 (D-063).
- 반환 컬럼 화이트리스트

### rpc_get_public_house_slots_summary
```sql
FUNCTION rpc_get_public_house_slots_summary(
  p_target_user_id uuid
) RETURNS jsonb
```
- 접근: auth-only (auth.uid() required). anon에 EXECUTE를 열지 않는다.
- auth-only는 데이터 접근 요건이며, 미인증 404는 외부 표면 상태코드 정책이다.
- DB 함수는 인증 컨텍스트 호출을 전제하고, 외부 라우트/API는 미인증을 404로 매핑한다.
- viewer_id는 내부에서 auth.uid()로 도출(입력으로 받지 않음)
- 데이터모델 키 정합: house_slots.owner_id 기준으로 house_profiles.user_id와 조인
- guard_soft_state() 적용: house_profiles.deleted_at/hidden_at is null, house_slots.deleted_at is null
- inventory_items는 LEFT JOIN + i.deleted_at is null 조건으로 결합(빈 슬롯은 허용)
- guard_visibility_published() 적용: house_profiles.visibility='public' AND house_profiles.published_at IS NOT NULL
- guard_block(viewer_id, p_target_user_id) 적용
- 반환 컬럼 화이트리스트(D-055)만: slot_key, equipped_at, type, catalog.standard_name
- D-055 비허용 예시: brand, days_since_equipped
- cats.avatar_url 금지
- inventory_item_id / inventory_items.id / raw_text / note / meta 금지

### rpc_get_public_house_slots_summary_by_nickname (선택)
```sql
FUNCTION rpc_get_public_house_slots_summary_by_nickname(
  p_target_nickname text
) RETURNS jsonb
```
- 접근: auth-only (auth.uid() required). anon에 EXECUTE를 열지 않는다. 외부 라우트/API 미인증 응답은 404로 통일.
내부에서 nickname → user_id resolve 후 rpc_get_public_house_slots_summary로 위임

동일 guard/화이트리스트 적용

**House 공개 조회 상태코드 (공통)**:
- 상태코드: 미인증/비공개/숨김/삭제/차단/미발행은 모두 404로 통일 (D-035, D-050)
- 설명: 로그인 필요 메시지는 UI 레이어에서 처리(존재 은닉 우선)

### rpc_set_house_slot
```sql
FUNCTION rpc_set_house_slot(
  p_room_key text DEFAULT 'living_room',
  p_slot_key text,
  p_inventory_item_id uuid
) RETURNS jsonb
```
- auth-only. owner_id = auth.uid(). guard_terms_agreed()
- write guard 순서 적용: `guard_terms_agreed()` 후 진행, 나머지 가드는 owner-write 특성상 N/A.
- slot_key 허용 목록(slot_01..slot_08) 검증
- inventory_item_id: is_current=true + owner_id 일치 검증
- house_profiles lazy create(D-085)
- See: D-074, D-043

### rpc_clear_house_slot
```sql
FUNCTION rpc_clear_house_slot(
  p_room_key text DEFAULT 'living_room',
  p_slot_key text
) RETURNS jsonb
```
- auth-only. inventory_item_id=NULL, equipped_at=NULL
- write guard 순서 적용: `guard_terms_agreed()` 후 진행, 나머지 가드는 owner-write 특성상 N/A.
- 없는 슬롯이면 no-op

### rpc_toggle_like
```sql
FUNCTION rpc_toggle_like(
  p_target_type text,  -- 'post'|'comment'|'thread'|'reply'
  p_target_id uuid
) RETURNS jsonb  -- {"liked": bool, "like_count": int}
```
- auth-only. write guard 순서 적용:
  1. `guard_terms_agreed()`
  2. `guard_block(viewer_id, target_user_id)`
  3. `guard_soft_state(target.deleted_at, target.hidden_at)`
  4. `guard_visibility_published(...)` (posts 대상일 때 필수, 그 외 target은 N/A)
- 원자 카운트 UPDATE(D-046)
- post like 시 notification INSERT(D-093)
- See: D-090

## 구현 결정 (검토 필요)
- guard 함수는 SQL STABLE 함수로 구현한다(재사용 + 플래너 최적화). guard_terms_agreed 포함 4종.
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

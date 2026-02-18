# API — API 계약 + RPC 시그니처(SSOT)

> 이 문서는 API 계약(스펙/가드/에러/리턴 타입)을 담은 단일 SSOT이다.
> REST 경로(GET/POST/...)는 **논리적 계약**이며, 실제 구현은 Supabase RPC 함수로 제공될 수 있다.

---

## 0) 핵심 원칙(LOCK 요약)
- 외부/공개/상품성 읽기 경로는 `SECURITY DEFINER` RPC 단일 경로를 기본으로 한다. (See `DECISIONS.md` D-029)
- DB RPC는 비즈니스 에러를 JSON return으로 전달한다. HTTP 상태코드 매핑은 외부 표면이 담당한다. (See D-065, D-071)
- 공개 표면의 “조회 불가”(비공개/숨김/삭제/차단/미인증/미발행/리소스 없음)는 404로 통일한다. (See D-050)
- 사용자 식별자 FK/조인은 `auth.users.id`(= `profiles.user_id`)로 통일한다. `profiles.id`는 내부 PK이며 도메인 FK 조인에 사용하지 않는다. (See D-094)

---

## 1) Transport Adapter 규약 (D-071)

DB RPC는 항상 JSON return(D-065). 외부 표면(웹 SSR/SDK wrapper)이 `body.error_code`를 보고 HTTP/예외로 변환한다.

| error_code | HTTP (웹 SSR) | 앱/SDK wrapper |
|------------|--------------|----------------|
| (정상) | 200 | 정상 처리 |
| not_found | 404 | NotFoundError throw |
| version_conflict | 409 | ConflictError throw |
| invalid_request | 400 | ValidationError throw |
| invalid_payload_version | 400 | ValidationError throw |
| rejected_version | 400 | ValidationError throw |
| terms_not_agreed | 403 | TermsError throw |
| forbidden | 403 | ForbiddenError throw |
| duplicate_report | 409 | ConflictError throw |
| invalid_target_type | 400 | ValidationError throw |
| invalid_inventory_item | 400 | ValidationError throw |

메모:
- D-050: guard 불만족은 모두 `not_found`로 귀결(존재 은닉).
- PostgREST 경유 시 DB 함수가 예외 없이 정상 return하면 HTTP 200이 기본이며, 클라이언트는 `body.error_code`로 비즈니스 에러를 판별한다.
- 권한/EXECUTE 거부나 hard fail 예외는 4xx/5xx가 될 수 있으며, 이는 비즈니스 에러(JSON return) 범주가 아니다.

---

## 2) 공통 Guard 패턴 (SSOT)

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

### guard_terms_agreed() — write RPC 전용 (D-073)
- profiles.terms_agreed_at IS NOT NULL
- 미동의 시 `{"error_code":"terms_not_agreed"}` 반환
- pre-terms 예외(부트스트랩 전용, v1 LOCK): `agree_terms`, `set_initial_nickname`
- 위 2개를 제외한 모든 write RPC는 `guard_terms_agreed()`를 적용한다.
- read RPC 제외

### Write RPC guard 호출 순서 (LOCK, D-096)
1. `guard_terms_agreed()`
2. `guard_block(viewer_id, target_user_id)` — 해당 시
3. `guard_soft_state(deleted_at, hidden_at)` — 해당 시
4. domain-specific guard (`guard_visibility_published` 등) — 해당 시

---

## 3) User 식별자 조인 규칙 (P0)
- 도메인 FK(예: posts.author_id, reports.reporter_id)는 `auth.users.id`를 저장한다.
- 닉네임/프로필 정보를 결합할 때는 항상 `profiles.user_id = <fk>`로 조인한다.
- 금지: `profiles.id = <fk>` 조인(드리프트/버그 유발).

---

## 4) 관찰(고위험) RPC

### rpc_upsert_observation_group_with_items
- 목적: 생성/전체 저장(일괄작성/초기 저장)
- 접근: auth-only (owner_id는 `auth.uid()`로 고정)
- 입력:
  - payload_version: text (필수, semver 형태)
  - log_date: date (오늘 이하)
  - idempotency_key: uuid (필수)
  - common_payload: jsonb
  - items: jsonb  (예: `[{cat_id, status, override_payload}]`)
  - inventory_refs?: jsonb (optional)
- 출력: `{group_id, version, items[]}`
- 에러:
  - 400 invalid_payload_version (버전 포맷)
  - 400 rejected_version (REJECT 상태)
  - 400 invalid_request (D-084: 같은 idempotency_key + 다른 log_date)

멱등/충돌:
- 동일 (owner_id, idempotency_key) 재요청은 최초 성공과 동일 응답 shape 반환.
- 같은 log_date + 다른 idempotency_key는 overwrite (D-084).

### rpc_patch_observation_items
- 목적: 부분 수정(excluded/override)
- 접근: auth-only
- 입력: group_id, expected_version, idempotency_key, patches[]
- 에러: 409 version_conflict(+ current_version, optional current_group_snapshot)
- 멱등성 저장소: observation_patch_dedup (D-061)

---

## 5) 공개 조회 RPC (대표)

### rpc_get_public_posts_feed
- 접근: anon 가능( viewer_id = auth.uid(), anon이면 null )
- 필터: guard_soft_state + guard_block + guard_visibility_published
- 반환: jsonb(배열 또는 고정 object) — 화이트리스트 필드만

### rpc_get_public_threads_feed
- 접근: anon 가능
- 필터: guard_soft_state + guard_block (threads/replies는 visibility/published 가드 적용 안 함)
- 반환: jsonb

### rpc_get_public_post_comments
- 접근: anon 가능
- 규칙: 부모 post 공개 가드 실패 시 0건이 아니라 `{"error_code":"not_found"}` (D-063)
- 반환: jsonb

### rpc_get_public_house_slots_summary
`rpc_get_public_house_slots_summary(p_target_user_id uuid) returns jsonb`

- 접근: **auth-only** (anon EXECUTE 비허용). 외부 표면 미인증 응답은 404로 매핑(존재 은닉).
- 입력: p_target_user_id uuid (route가 `/u/{nickname}/house`인 경우, adapter/route layer에서 nickname -> user_id 해석 후 전달)
- 반환: jsonb, **고정 shape** 권장:
  - 성공: `{ "slots": [ {slot_key, equipped_at, type, standard_name}, ... ] }`
  - 실패: `{ "error_code": "not_found" }`
- DTO whitelist(LOCK): slot_key, equipped_at, type, catalog.standard_name
- 금지(LOCK): cats.avatar_key/cats.avatar_url, inventory_item_id, inventory_items.id, raw_text, note, meta, catalog_item_id

---

## 6) 운영 파라미터 RPC

### rpc_get_app_config
- 목적: 운영 파라미터 조회
- 접근: auth-only
- 입력: p_keys text[]
- 동작:
  - 요청 key 중 whitelist에 포함된 것만 반환
  - unknown key는 무시(호환성)

키 목록 SSOT:
- `CONFIG-BASELINES.md` §3 (app_config key 매핑)

---

## 7) 도메인 Write RPC(SSOT)

공통 규약:
- 모든 write RPC는 `guard_terms_agreed()`를 적용하고, 호출 순서는 D-096(`terms -> block -> soft_state -> domain`)을 준수한다.
- 에러 전달은 JSON return(D-065)이며, 외부 표면의 HTTP 매핑은 D-071을 따른다.

### 7-1) 냥스타그램 Write RPC

`rpc_create_post(p_body text, p_log_date date, p_visibility text, p_hide_from_profile bool default false, p_meta jsonb default '{}'::jsonb) returns jsonb`

`rpc_update_post(p_post_id uuid, p_body text default null, p_visibility text default null, p_hide_from_profile bool default null, p_meta jsonb default null) returns jsonb`

`rpc_delete_post(p_post_id uuid) returns jsonb` (soft delete)

`rpc_publish_post(p_post_id uuid) returns jsonb`

`rpc_unpublish_post(p_post_id uuid) returns jsonb`

`rpc_create_comment(p_post_id uuid, p_body text) returns jsonb`

`rpc_update_comment(p_comment_id uuid, p_body text) returns jsonb`

`rpc_delete_comment(p_comment_id uuid) returns jsonb`

`rpc_toggle_like(p_target_type text, p_target_id uuid) returns jsonb`

최소 계약:
- publish/unpublish 전이는 D-007 패턴을 준수한다: `private + published_at` 금지, visibility를 private로 전환 시 `published_at=NULL` 강제.

### 7-2) 채널 Write RPC

`rpc_list_topics() returns jsonb`

`rpc_follow_topic(p_topic_id uuid) returns jsonb`

`rpc_unfollow_topic(p_topic_id uuid) returns jsonb`

`rpc_create_thread(p_topic_id uuid, p_title text, p_body text) returns jsonb`

`rpc_update_thread(p_thread_id uuid, p_title text default null, p_body text default null) returns jsonb`

`rpc_delete_thread(p_thread_id uuid) returns jsonb`

`rpc_create_reply(p_thread_id uuid, p_body text) returns jsonb`

`rpc_update_reply(p_reply_id uuid, p_body text) returns jsonb`

`rpc_delete_reply(p_reply_id uuid) returns jsonb`

`rpc_search_threads(p_q text, p_topic_id uuid default null, p_cursor text default null, p_limit int default 20) returns jsonb`

피드 3종 표면 고정(v1):
- `rpc_get_public_threads_feed(p_sort text default 'new', p_cursor text default null, p_limit int default 20) returns jsonb`
- `p_sort`는 `new|popular|following`을 사용하며, cursor/limit 규칙은 D-077(키셋 커서 통일)을 따른다.

### 7-3) 운영 Write RPC

`rpc_report_content(p_target_type text, p_target_id uuid, p_reason_code text, p_note text default null) returns jsonb`

`rpc_block_user(p_blocked_user_id uuid) returns jsonb`

`rpc_unblock_user(p_blocked_user_id uuid) returns jsonb`

최소 계약:
- 차단은 D-019를 따른다(상호 비노출 + 상호작용 불가). anon viewer에는 block 필터를 적용하지 않는다(AUTHZ-MODEL §0-2).
- report는 신고 시점 snapshot 저장(D-052)을 보장하고, 중복 신고는 `duplicate_report`(409)로 처리한다(D-056/`docs/playbooks/moderation.md` 정합).

### 7-4) 하우스 Write RPC

`rpc_set_house_slot(p_room_key text, p_slot_key text, p_inventory_item_id uuid) returns jsonb`

`rpc_clear_house_slot(p_room_key text, p_slot_key text) returns jsonb`

`rpc_publish_house() returns jsonb`

`rpc_unpublish_house() returns jsonb`

최소 계약:
- 슬롯 API는 slot_key 기반 통일(D-074). house_slots.id(PK)는 API 표면 미노출.
- 슬롯 저장 시 is_current=true만 장착 가능(D-043).
- house_profiles는 lazy create(D-085): 하우스 탭 최초 접근 또는 슬롯 바인딩 시 upsert.
- publish: visibility='public' + published_at=now() 원샷. unpublish: published_at=NULL(visibility 유지). See D-062.
- private + published_at 금지 불변식(AUTHZ-MODEL §0-3) 준수.

### 7-5) 인벤토리 Write RPC

`rpc_inventory_switch(p_type text, p_raw_text text, p_catalog_item_id uuid default null, p_changed_at timestamptz default now(), p_reason_note text default null) returns jsonb`

`rpc_inventory_discontinue(p_type text, p_reason_note text default null) returns jsonb`

최소 계약:
- 이벤트 모델 D-057 준수: switch는 기존 current 종료 + 신규 row(reason_code='switch'). discontinue는 기존 current 종료만.
- reason_code는 row 생성 원인(불변, D-075). 종료 시 기존 row의 reason_code 변경 안 함.
- 불변식: (ended_at IS NULL) == (is_current = true).
- correction은 v1 UX 미확정이므로 RPC 예비 등록만(D-095).

### 7-6) 프로필/온보딩 Write RPC

`rpc_agree_terms() returns jsonb`

`rpc_set_initial_nickname(p_nickname text) returns jsonb`

`rpc_update_profile(p_nickname text default null, p_bio text default null, p_avatar_key text default null) returns jsonb`

최소 계약:
- agree_terms, set_initial_nickname은 pre-terms 예외(D-097). guard_terms_agreed 적용하지 않는다.
- set_initial_nickname은 온보딩 최초 설정 전용. 이미 설정된 계정에는 사용 불가.
- rpc_update_profile은 guard_terms_agreed 필수. 닉네임 변경은 v1 미구현(D-051).
- 닉네임 길이: 2~20자(D-087). bio 길이: 0~200자(D-087).

### 7-7) 알림 RPC

`rpc_get_notifications(p_cursor text default null, p_limit int default 20) returns jsonb`

`rpc_mark_notification_read(p_notification_id uuid) returns jsonb`

`rpc_mark_all_notifications_read() returns jsonb`

최소 계약:
- v1 범위: in-app inbox 조회/읽음 처리만(D-070). 푸시 제외.
- 이벤트 타입: comment / reply / like. type-target 매핑은 D-070 LOCK을 따른다.
- read RPC이므로 guard_terms_agreed 미적용.
- mark_notification_read, mark_all_notifications_read는 write RPC이므로 guard_terms_agreed 필수.

---

## 8) 개별 상세 조회 RPC

### rpc_get_public_post_detail
- 접근: anon 가능
- 입력: p_post_id uuid
- 필터: guard_soft_state + guard_block + guard_visibility_published
- 반환: jsonb (post 본문 + author_nickname + like_count + comment_count + meta)
- 실패: `{"error_code":"not_found"}` (D-050)

### rpc_get_public_thread_detail
- 접근: anon 가능
- 입력: p_thread_id uuid
- 필터: guard_soft_state + guard_block
- 반환: jsonb (thread 본문 + author_nickname + like_count + reply_count + topic info)
- 실패: `{"error_code":"not_found"}` (D-050)

### rpc_get_my_profile
- 접근: auth-only (owner)
- 반환: jsonb (nickname, bio, avatar_key, terms_agreed_at, created_at)
- read RPC이므로 guard_terms_agreed 미적용.

### rpc_get_my_house
- 접근: auth-only (owner)
- 반환: jsonb (house_profile 상태 + 슬롯 목록 + 바인딩된 인벤 정보)
- house_profiles가 없으면 lazy create(D-085)하지 않고 기본 상태 반환.

### rpc_get_my_observation_group
- 접근: auth-only (owner)
- 입력: p_log_date date
- 반환: jsonb (group + items + inventory_refs). 없으면 null/빈 객체.
- owner_id = auth.uid()로 고정.

---

## 9) 논리적 REST 계약(참고)
> 실제 구현은 RPC로 대체될 수 있다. 실제 RPC 시그니처는 §4~§8 참조.

### 냥스타그램
- POST /posts
- PATCH /posts/{id}
- POST /posts/{id}/publish
- POST /posts/{id}/unpublish
- POST /likes/toggle (target_type, target_id)
- POST /posts/{id}/comments
- PATCH /comments/{id}
- DELETE /comments/{id} (soft delete)

### 채널
- GET /topics
- POST/DELETE /topics/{id}/follow
- GET /topics/{id}/threads?sort=new|popular|following&cursor=...
- POST /topics/{id}/threads
- GET/PATCH/DELETE /threads/{id}
- GET /threads/{id}/replies?cursor=...
- POST /threads/{id}/replies
- PATCH/DELETE /replies/{id}
- GET /search?scope=threads&q=...&topic=...&cursor=... (noindex)

### 운영
- POST /reports
- POST /blocks
- DELETE /blocks/{blocked_id}

### 하우스
- GET /house/me
- POST /house/publish
- POST /house/unpublish
- GET /profiles/{nickname}/house (auth-only, 404 통일)

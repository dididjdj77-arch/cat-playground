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
| target_not_found (deprecated) | 404 | NotFoundError throw |
| version_conflict | 409 | ConflictError throw |
| invalid_request | 400 | ValidationError throw |
| invalid_payload_version | 400 | ValidationError throw |
| rejected_version | 400 | ValidationError throw |
| terms_not_agreed | 403 | TermsError throw |
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
- 접근: **auth-only** (anon EXECUTE 비허용). 외부 표면 미인증 응답은 404로 매핑(존재 은닉).
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

## 7) 논리적 REST 계약(참고)
> 실제 구현은 RPC로 대체될 수 있다.

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

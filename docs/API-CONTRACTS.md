# API-CONTRACTS — API 계약

> **참고**: 이 문서의 REST 경로(GET/POST/PUT 등)는 **논리적 API 계약**입니다.
> 실제 구현은 Supabase RPC 함수로 대체될 수 있습니다. RPC 시그니처는 RPC-SPECS.md 참조.
> Public DTO에는 inventory 관련 필드를 어떤 형태로도 포함하지 않는다(IDs 포함). Owner-only DTO에서만 허용한다. (D-018, D-036, D-037 준수; 화이트리스트만 허용)

## Transport Adapter 규약 (D-071)

DB RPC는 항상 JSON return(D-065). HTTP 매핑은 호출 계층이 담당.

| error_code | HTTP (웹 SSR) | 앱(SDK wrapper) |
|------------|--------------|-----------------|
| (정상) | 200 | 정상 처리 |
| not_found | 404 | NotFoundError throw |
| version_conflict | 409 | ConflictError throw |
| invalid_payload_version | 400 | ValidationError throw |
| rejected_version | 400 | ValidationError throw |
| terms_not_agreed | 403 | TermsError throw |
| duplicate_report | 409 | ConflictError throw |
| target_not_found | 404 | NotFoundError throw |
| invalid_target_type | 400 | ValidationError throw |
| invalid_inventory_item | 400 | ValidationError throw |

- D-050: guard 불만족은 모두 not_found → 404
- 앱은 body.error_code 기반 분기(HTTP 상태코드 미의존)
- 웹 SSR은 route handler에서 위 테이블 기준 HTTP 응답 생성

## 관찰(고위험)
RPC upsert_observation_group_with_items
- 목적: 생성/전체 저장(일괄작성/초기 저장)
- req: 
  - payload_version: text (필수, semver 형태)
  - log_date: date
  - idempotency_key: uuid (필수)
  - common_payload: jsonb
  - items[{cat_id, status, override_payload}]
  - inventory_refs?: jsonb  (optional) — 타입별 inventory_item_id 맵
- res: 
  - group_id: uuid
  - version: int
  - items[]
- err:
  - 400 invalid_payload_version: 버전 포맷 오류
  - 400 rejected_version: REJECT 상태 버전
- 비고: 트랜잭션 + 멱등성 필수, DEPRECATED/ACTIVE는 저장 허용
- 멱등성: 동일 (owner_id, idempotency_key) 재요청은 기존 결과(group_id/version/items)를 반환
- upsert 시 inventory_refs를 기록하면 observation_inventory_refs로 저장된다.
- patch_observation_items는 observation_inventory_refs를 변경하지 않는다.

RPC patch_observation_items
- 목적: 부분 수정(excluded/override)
- req: 
  - group_id: uuid
  - expected_version: int (필수)
  - idempotency_key: uuid (필수)
  - patches[]
- res: 
  - new_version: int
  - items[]
- err:
  - 409 version_conflict:
    - error_code: "version_conflict"
    - current_version: int
    - current_group_snapshot (권장)

## 냥스타그램
POST /posts
PATCH /posts/{id}
POST /posts/{id}/publish
POST /posts/{id}/unpublish
POST /likes/toggle (target_type, target_id)
POST /posts/{id}/comments
PATCH /comments/{id} (edited_at set)
DELETE /comments/{id} (soft delete)

## 채널
GET /topics
POST/DELETE /topics/{id}/follow
GET /topics/{id}/threads?sort=new|popular|following&cursor=...
POST /topics/{id}/threads
GET/PATCH/DELETE /threads/{id}
GET /threads/{id}/replies?cursor=...
POST /threads/{id}/replies
PATCH/DELETE /replies/{id}
GET /search?scope=threads&q=...&topic=...&cursor=... (noindex)

## 운영
POST /reports
POST /blocks / DELETE /blocks/{blocked_id}
Admin:
GET /admin/reports
POST /admin/hide / POST /admin/unhide
GET /admin/catalog_suggestions
POST /admin/catalog/approve / reject / alias / merge

## 하우스

GET /house/me
- 목적: 내 하우스(거실 씬 + 슬롯/바인딩 데이터) 조회
- res: { room_key, slots[{slot_key, inventory_item_id, equipped_at, ...}], cats[...] }

RPC rpc_set_house_slot(p_room_key, p_slot_key, p_inventory_item_id)
- 목적: 슬롯 바인딩 저장(upsert). v1: 저장 시점에 is_current=true 검증 (D-043, D-074)
- res: { slot_key, equipped_at }

RPC rpc_clear_house_slot(p_room_key, p_slot_key)
- 목적: 슬롯 비우기 (D-074)
- res: { ok: true }

POST /house/publish
- 목적: 하우스 발행(노출 허용)
- 효과: house_profiles.visibility='public', house_profiles.published_at=now()
- res: { visibility, published_at }

POST /house/unpublish
- 목적: 하우스 발행 취소(노출 금지)
- 효과: house_profiles.published_at=null. visibility는 변경하지 않는다(기존 값 유지). (D-062)
- res: { visibility, published_at }

GET /profiles/{nickname}/house
- 목적: 공개 하우스 조회(화이트리스트 DTO)
- 접근: **auth-only** (See AUTHZ-MODEL §0-4)
- 해석: auth-only는 데이터 접근 요건이며, 외부 표면의 미인증 응답은 404로 매핑한다.
- 내부: rpc_get_public_house_slots_summary_by_nickname(또는 동등 RPC) 호출
- res: 공개 DTO(화이트리스트). cats.avatar_url / inventory ids / raw_text / note / meta 금지
- 상태코드: 미인증/비공개/숨김/삭제/차단/미발행은 모두 404로 통일 (D-035, D-050)
- 설명: 로그인 필요 메시지는 UI 레이어에서 처리(존재 은닉 우선)

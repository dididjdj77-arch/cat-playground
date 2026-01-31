# API-CONTRACTS — API 계약(초안)

## 관찰(고위험)
RPC upsert_observation_group_with_items
- 목적: 생성/전체 저장(일괄작성/초기 저장)
- req: 
  - payload_version: text (필수, semver 형태)
  - log_date: date
  - idempotency_key: uuid (필수)
  - common_payload: jsonb
  - items[{cat_id, status, override_payload}]
- res: 
  - group_id: uuid
  - version: int
  - items[]
- err:
  - 400 invalid_payload_version: 버전 포맷 오류
  - 400 rejected_version: REJECT 상태 버전
- 비고: 트랜잭션 + 멱등성 필수, DEPRECATED/ACTIVE는 저장 허용
- 멱등성: 동일 (owner_id, idempotency_key) 재요청은 기존 결과(group_id/version/items)를 반환

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

PUT /house/slots/{slotId}
- 목적: 슬롯 바인딩 저장(배치)
- req: { inventory_item_id: uuid }  // v1: 저장 시점에 is_current=true 검증
- res: { slot }

DELETE /house/slots/{slotId}
- 목적: 슬롯 비우기
- res: { ok: true }

POST /house/publish
- 목적: 하우스 발행(노출 허용)
- 효과: house_profiles.visibility='public', house_profiles.published_at=now()
- res: { visibility, published_at }

POST /house/unpublish
- 목적: 하우스 발행 취소(노출 금지)
- 효과: house_profiles.published_at=null (visibility 유지 여부는 정책으로 명시)
- res: { visibility, published_at }

GET /profiles/{nickname}/house
- 목적: 공개 하우스 조회(화이트리스트 DTO)
- 내부: rpc_get_public_house_slots_summary_by_nickname(또는 동등 RPC) 호출
- res: 공개 DTO(화이트리스트). cats.avatar_url / inventory ids / raw_text / note / meta 금지

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

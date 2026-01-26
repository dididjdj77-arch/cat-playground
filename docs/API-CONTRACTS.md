# API-CONTRACTS — API 계약(초안)

## 관찰(고위험)
RPC upsert_observation_group_with_items
- 목적: 생성/전체 저장(일괄작성/초기 저장)
- req: log_date, idempotency_key, common_payload, items[{cat_id,status,override_payload}]
- res: group_id, version, items[]
- 비고: 트랜잭션 + 멱등성 필수

RPC patch_observation_items
- 목적: 부분 수정(excluded/override)
- req: group_id, expected_version, idempotency_key, patches[]
- res: new_version, items[]
- err: 409(버전 충돌)

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

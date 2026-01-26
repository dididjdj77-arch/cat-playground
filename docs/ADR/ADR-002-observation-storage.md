# ADR-002 Observation 저장(다묘) — Upsert/Patch + 멱등성 + 버전충돌

- 상태: Accepted
- 관련 결정: D-005, D-022

결정:
- 그룹/아이템 분리
- Upsert(전체 저장)와 Patch(부분 수정) 분리
- 트랜잭션 + idempotency key
- version 기반 409 충돌 처리

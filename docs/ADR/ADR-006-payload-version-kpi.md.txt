# ADR-006 Payload version KPI + cache TTL + format validation

- 상태: Accepted
- 날짜: 2026-01-30
- 관련 결정: D-028

문제:
- payload_version 상태 머신과 KPI가 있어도, 런타임에서 “버전 조회/검증”이 느리거나 부정확하면 운영이 깨진다.
- 고QPS에서 payload_versions 단일 row 카운터 업데이트는 경합을 유발할 수 있다.
- “PK id 포맷 변경” 같은 큰 마이그레이션 없이도, 입력 포맷 검증과 캐싱은 필요하다.

배경:
- v1.1은 Contract+검증 레이어를 운영 가능한 시스템으로 만드는 것이 목적이다.
- 관찰 저장은 멱등성/409 처리 전제가 있으며, 이는 쓰기 경로에서 검증/정규화가 일관되게 적용되어야 한다.

선택지:
- A) 매 요청마다 payload_versions를 DB에서 조회(단순, 하지만 비용↑)
- B) 인프로세스 TTL 캐시 + DB 폴백(구현 부담↓, 효과↑)  ← 채택
- C) Redis 분산 캐시(멀티 인스턴스에서 일관성↑, 운영 부담↑)

결정:
- 기본은 인프로세스 TTL 캐시로 시작한다(TTL <= 5분 권장).
- 멀티 인스턴스/트래픽 증가로 필요해지면 Redis 캐시를 추가한다(도입 시점은 TODO에서 계측 후).
- 입력 포맷 검증:
  - payload_version은 semver 형태(예: 1.1, 1.2, 2.0)로 검증한다.
  - idempotency_key는 고정 포맷(예: UUID)으로 검증한다.
  - 엔티티 PK(id)의 포맷 변경은 v1.1 범위에서 하지 않는다.
- KPI 수집은 “핫패스 단일 row 카운터 UPDATE”를 강제하지 않는다:
  - 이벤트 로그(append-only)로 기록 후 롤업(집계)하는 구현을 허용/권장한다.

후속 작업:
- 샘플 페이로드 → RPC 통과 여부뿐 아니라 normalize 결과 스냅샷까지 CI에 포함한다.
- payload_version 이벤트/롤업(또는 동등한 저경합 KPI 수집) 경로를 구현한다.

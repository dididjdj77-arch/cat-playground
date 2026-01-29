# ADR-005 Guard filters performance — 뷰 중첩 vs RPC 전략

- 상태: Accepted
- 날짜: 2026-01-30
- 관련 결정: D-029

문제:
- deleted/hidden/blocked 공통 필터를 모든 외부/공개/상품 API에 강제해야 한다.
- 단순 “뷰 중첩 + 함수 호출”은 플래너/인덱스 사용이 깨지거나, per-row 함수 호출로 성능이 급락할 수 있다.

배경:
- D-029에 의해 외부/공개/상품 API는 집계 RPC 단일 경로이며, 내부에서 guard_soft_state()+guard_block() 적용이 필수다.
- v1.1은 트래픽이 크지 않지만, 구조적으로 누락/복붙 실수를 제거하는 게 최우선이다.

선택지:
- A) 뷰 중첩(보일러플레이트 적음) + 함수 호출
- B) SECURITY DEFINER RPC(단일 경로) + guard 함수(또는 동등 로직) 명시적 적용  ← 채택
- C) blocks 관계를 MV/캐시로 분리하여 조인 비용을 낮춤(성능 최적화)

결정:
- v1.1에서는 “SECURITY DEFINER RPC + 명시적 guard 적용”을 기본으로 한다.
- guard_soft_state(), guard_block()은 가능하면 SQL 함수로 단순화하여 플래너 최적화를 방해하지 않도록 한다.
- 성능 문제(뷰 중첩/함수 호출 비용)는 계측 기반으로 개선한다:
  - 월/주 단위 slow-query 리포트(상위 N개)로 병목을 확인
  - 필요 시 O-013에서 block 캐시(MV/Redis) 도입 여부를 결정

보안 하드닝(권장):
- SECURITY DEFINER 함수는 search_path를 고정(예: public)하고, 입력 viewer_id를 첫 단계에서 검증(assert)하는 패턴을 사용한다.
- 외부 공개 RPC는 원본 테이블 직접 노출을 금지한다(D-029와 정합).

후속 작업:
- 차단 스냅샷 CI(차단 A↔B 시 공개/집계 RPC 0 rows)를 추가한다.
- 필요 시 block 캐시 전략은 OPEN에서 계측 후 결정한다.

# ADR-001 Channel v1 (Blind 벤치마킹, 익명성 제외)

- 상태: Accepted
- 관련 결정: D-013, D-016, D-023

결정:
- v1부터 글/답글(1-depth)/좋아요/검색 + 피드3종 + 토픽팔로우 포함
- 검색은 DB FTS로 시작, 검색결과는 noindex
- 성능/정합성 위해 cursor pagination, 집계 보정 잡을 둔다

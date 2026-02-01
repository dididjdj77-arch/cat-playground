# TODO — Active 작업 (최대 3개)

규칙: Active 최대 3개. 완료시 삭제. 백로그는 GitHub Issue로 관리.

---

## T-02 스키마 마이그레이션 (payload_version 포함)
- Done when:
  - DATA-MODEL 테이블/인덱스/제약이 migrations에 반영
  - payload_versions 테이블 + 상태 머신 동작
  - 최소 RLS(또는 RPC 기반 정책) 동작
- How to verify:
  - RPC로 공개 토픽/스레드/글 읽기 가능 (anon: 채널만, house: auth-only)
  - private/hidden/blocked는 비노출
  - likes unique, 관찰 (group,cat) unique 동작

## T-06 guard 함수 + 차단 스냅샷 CI
- Done when:
  - guard_soft_state(), guard_block() 함수 구현
  - 외부/공개 RPC에서 공통 필터 적용
  - CI에 "차단 시 0 rows" 테스트 포함
- How to verify:
  - A↔B 차단 시 상호 비노출
  - hidden/deleted도 비노출

## T-08 observation RPC (idempotency + tx)
- Done when:
  - rpc_upsert_observation_group_with_items 구현
  - 동일 idempotency_key 재호출 시 동일 결과 반환
  - 트랜잭션 내 원자성 보장
- How to verify:
  - supabase db reset 후 동일 key 2회 호출 → 동일 group_id/version
  - payload 검증 실패 시 400
  - 부분 실패 시 전체 롤백

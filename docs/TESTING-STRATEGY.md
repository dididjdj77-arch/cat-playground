# TESTING-STRATEGY — CI 필수 테스트 전략

v1.1 기준 CI에 반드시 포함되어야 할 테스트

## CI 필수 테스트 3종

### 1. 차단 스냅샷 테스트 (0 rows)

**목적**: block 관계 시 공개/집계 RPC가 0 rows를 반환하는지 검증

**대상 RPC** (최소 2개):
- rpc_get_public_posts_feed
- rpc_get_public_threads_feed

**시나리오**:
```
Given:
  - User A, User B 존재
  - A가 공개 post/thread 작성
  
When:
  - A가 B를 차단
  
Then:
  - B가 rpc_get_public_posts_feed 호출 → A의 post 0건 (blocked)
  - B가 rpc_get_public_threads_feed 호출 → A의 thread 0건 (blocked)
  
When:
  - B가 A를 차단 (상호 차단)
  
Then:
  - A가 rpc_get_public_posts_feed 호출 → B의 post 0건 (blocked)
  - A가 rpc_get_public_threads_feed 호출 → B의 thread 0건 (blocked)
```

**추가 확인**:
- hidden_at이 설정된 콘텐츠도 0 rows
- deleted_at이 설정된 콘텐츠도 0 rows

### 2. payload_version normalize 스냅샷 테스트

**목적**: 각 payload_version의 normalize 결과가 기대값과 일치하는지 검증

**샘플 데이터**:
```json
// v1.0 (ACTIVE)
{
  "payload_version": "1.0",
  "common_payload": {"food": "습식", "water": "충분"},
  "items": [{"cat_id": "...", "status": "active"}]
}

// v1.1 (ACTIVE) - 신규 필드 추가
{
  "payload_version": "1.1",
  "common_payload": {"food": "습식", "water": "충분", "new_field": "값"},
  "items": [{"cat_id": "...", "status": "active"}]
}

// v0.9 (DEPRECATED) - 구버전
{
  "payload_version": "0.9",
  "common_payload": {"food_type": "wet", "water_level": "enough"},
  "items": [{"cat_id": "...", "status": "active"}]
}

// v0.5 (REJECT) - 거부됨
{
  "payload_version": "0.5",
  ...
}
```

**테스트**:
```
Given:
  - payload_versions 테이블에 각 버전 상태 설정
  - normalize_to_active() 함수 구현됨
  
When:
  - 각 샘플 페이로드로 RPC 호출
  
Then:
  - v1.0, v1.1: 저장 성공, normalize 후 집계 반영
  - v0.9: 저장 성공, normalize 성공 시 집계 반영, 실패 시 normalize_fail_count++
  - v0.5: 400 rejected_version 오류
```

**스냅샷 검증**:
- normalize_to_active("1.0") → 기대 결과 스냅샷과 비교
- normalize_to_active("1.1") → 기대 결과 스냅샷과 비교
- normalize_to_active("0.9") → 기대 결과 스냅샷과 비교 (또는 실패)

### 3. 409 version_conflict 시나리오

**목적**: expected_version 불일치 시 409 응답 검증

**시나리오**:
```
Given:
  - User A가 observation_group 생성 (version = 1)
  
When:
  - Client 1이 patch 요청 (expected_version = 1)
  - Client 2가 patch 요청 (expected_version = 1, 동시 요청)
  
Then:
  - 하나는 성공 (version = 2)
  - 다른 하나는 409 conflict
    - error_code: "version_conflict"
    - current_version: 2
    - current_group_snapshot 포함 (권장)
```

**검증 항목**:
- 409 응답 구조가 명세와 일치
- 데이터 찢김 없음 (트랜잭션 보장)
- 재시도 시 idempotency_key 기반 중복 방지

## CI 실행 원칙
1. 테스트는 격리된 환경(테스트 DB)에서 실행
2. 각 테스트는 독립적으로 실행 가능 (setup/teardown)
3. 실패 시 명확한 에러 메시지 출력
4. 모든 필수 테스트 통과 후에만 머지 가능

## 향후 확장 (TODO)
- E2E 테스트 (앱/웹 UI 통합)
- 성능 테스트 (부하, 동시성)
- 보안 테스트 (SQL injection, XSS)

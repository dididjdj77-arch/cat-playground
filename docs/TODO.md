# TODO — Next 2~3단계만

규칙: 다음 2~3단계만 유지. 각 항목 Done when / How to verify 필수.

## T-01 문서 SSOT 고정(이번 패키지 기반)
- Done when:
  - DECISIONS가 D-001~D-039을 완전히 반영
  - ARCHITECTURE/DATA/AUTHZ/ROUTES가 서로 모순 없음
- How to verify:
  - 공개 노출 조건(visibility/published/hidden/blocked)이 모든 문서에서 동일
  - 관찰 Upsert/Patch(멱등성/버전충돌)가 스키마/API/QA에 일관
  - 하우스 공개 조건(visibility/published/hidden/deleted/blocked)이 ARCHITECTURE/AUTHZ/RLS/RPC/QA에서 동일
  - 공개 하우스 응답에 cats.avatar_url 및 인벤 원장 id/자유입력 필드가 포함되지 않음(화이트리스트 준수)

## T-02 Supabase 스키마를 마이그레이션으로 코드화
- Done when:
  - DATA-MODEL의 테이블/인덱스/제약이 실제 migrations에 반영
  - 최소 RLS(또는 서버 함수 기반 정책)가 동작
- How to verify:
  - RPC로 공개 토픽/스레드/공개 글 읽기 가능(anon 포함)
  - private/hidden/blocked는 읽기 불가
  - likes unique, 관찰 (group,cat) unique가 깨지지 않음

## T-03 구현 티켓 분해 후 착수(omoc 전달)
- Done when:
  - 아래 티켓이 생성되고 각 티켓에 Done when/How to verify 포함
- How to verify:
  - 티켓 순서대로 수행하면 앱/웹 핵심 플로우가 동작

## T-04 payload_versions 메타 + 버전 상태 캐시 + KPI 수집(저경합)
- Done when:
  - payload_versions(버전, 상태, 메타)를 기준으로 ACTIVE/DEPRECATED/REJECT 판정이 서버에서 일관되게 동작
  - 캐시(TTL <= 5m)가 적용되어 "버전 조회"가 hot-path 병목이 아님(인프로세스 TTL 캐시로 시작, 필요 시 Redis는 옵션)
  - KPI 수집이 단일 row 카운터 경합을 유발하지 않음(이벤트 로그 → 롤업 또는 동등한 저경합 방식)
  - 샘플 페이로드 → RPC → normalize 결과 스냅샷 테스트가 CI에 포함
- How to verify:
  - DEPRECATED 버전 저장은 허용되나, 집계는 normalize_to_active 통과 후만 반영됨
  - REJECT 버전 저장은 400으로 거부됨
  - normalize 실패 시 집계에서 제외되고 실패 지표가 누적됨(롤업 결과 확인)
  - CI에서 버전별 샘플이 모두 기대 결과 스냅샷과 일치

## T-05 migrate_meta_key 템플릿 + 첫 승격 리허설(package_size_bucket)
- Done when:
  - migrate_meta_key(key → column) 템플릿이 문서/스크립트로 존재
  - 첫 실험키(package_size_bucket)를 대상으로 one-shot backfill이 성공
  - 승격 키 입력 정책이 동작:
    - 호환 기간: 입력 수용 → 컬럼 canonicalize + meta에서 제거(선택)
    - 이후: 승격 키 meta 입력은 readonly로 거부
- How to verify:
  - backfill 전/후 row count 및 값이 일치(샘플 검증)
  - 승격 이후 동일 요청이 들어와도 컬럼 값이 SSOT로 유지(dual-write 없음)

## T-06 guard_soft_state / guard_block + 차단 스냅샷 CI
- Done when:
  - 외부·공개·상품성 RPC 경로에서 공통 필터 로직이 반드시 적용됨
  - CI에 "차단 관계 스냅샷 테스트(0 rows)"가 포함됨
- How to verify:
  - A가 B 차단 시: A가 B의 공개/집계 결과를 조회하면 0 rows
  - B가 A 차단 시: B가 A의 공개/집계 결과를 조회하면 0 rows
  - 상호 차단 시: 양방향 모두 0 rows
  - hidden/deleted도 동일하게 노출이 차단됨(대표 케이스 1개 이상)

## T-07 ops_metrics 로그 스키마(backlog size, manual hrs 등) 시작
- Done when:
  - ops_metrics(백로그, 처리시간, 자동매칭률 등) 로깅이 시작됨(최소한 DB 적재)
  - 월/주 단위로 CSV/쿼리로 지표 확인 가능
- How to verify:
  - 운영 이벤트(카탈로그 제안/승인/병합 등) 발생 시 ops_metrics가 누적됨
  - 최소 1주치 데이터로 backlog/처리시간 추이가 확인됨

권장 티켓:
A 앱 뼈대(탭/세그먼트)
B 다이어리(인라인2패널/드래프트/log_date그룹/점프캘린더)
C 관찰(Upsert/Patch/excluded/override/409 UX)
D 냥스타그램(발행/취소/피드/댓글/좋아요)
E 채널(토픽/피드3종/스레드/답글/좋아요/검색/팔로우)
F 운영도구(신고/자동숨김/차단 + 카탈로그 승인큐)
G 웹 SEO(SSR/ISR, 토픽/상세, sitemap, noindex 검색)
H 하우스(2D 씬/슬롯/공개: visibility+published + 공개 DTO 화이트리스트)


참조 문서:
- docs/SCHEMA-MIGRATIONS.md: 스키마 마이그레이션 체크리스트
- docs/RPC-SPECS.md: RPC 시그니처 및 guard 패턴
- docs/TESTING-STRATEGY.md: CI 필수 테스트 전략

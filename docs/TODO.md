# TODO — Next 2~3단계만

규칙: 다음 2~3단계만 유지. 각 항목 Done when / How to verify 필수.

## T-01 문서 SSOT 고정(이번 패키지 기반)
- Done when:
  - DECISIONS가 D-001~D-026을 완전히 반영
  - ARCHITECTURE/DATA/AUTHZ/ROUTES가 서로 모순 없음
- How to verify:
  - 공개 노출 조건(visibility/published/hidden/blocked)이 모든 문서에서 동일
  - 관찰 Upsert/Patch(멱등성/버전충돌)가 스키마/API/QA에 일관

## T-02 Supabase 스키마를 마이그레이션으로 코드화
- Done when:
  - DATA-MODEL의 테이블/인덱스/제약이 실제 migrations에 반영
  - 최소 RLS(또는 서버 함수 기반 정책)가 동작
- How to verify:
  - anon으로 공개 토픽/스레드/공개 글 읽기 가능
  - private/hidden/blocked는 읽기 불가
  - likes unique, 관찰 (group,cat) unique가 깨지지 않음

## T-03 구현 티켓 분해 후 착수(omoc 전달)
- Done when:
  - 아래 티켓이 생성되고 각 티켓에 Done when/How to verify 포함
- How to verify:
  - 티켓 순서대로 수행하면 앱/웹 핵심 플로우가 동작

권장 티켓:
A 앱 뼈대(탭/세그먼트)
B 다이어리(인라인2패널/드래프트/log_date그룹/점프캘린더)
C 관찰(Upsert/Patch/excluded/override/409 UX)
D 냥스타그램(발행/취소/피드/댓글/좋아요)
E 채널(토픽/피드3종/스레드/답글/좋아요/검색/팔로우)
F 운영도구(신고/자동숨김/차단 + 카탈로그 승인큐)
G 웹 SEO(SSR/ISR, 토픽/상세, sitemap, noindex 검색)

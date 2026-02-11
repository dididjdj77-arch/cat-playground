# QA-SCENARIOS — 검증 시나리오

## 다이어리/관찰
- 공통만 저장 → 선택한 모든 고양이에 동일 적용
- 공통+오버라이드 → 특정 고양이만 덮어쓰기
- excluded 숨김/복구 → 삭제 없이 상태로 처리
- 드래프트 복원 → 저장 없이 닫아도 복구
- 과거 log_date 작성 → 과거 섹션에 들어감
- 미래 log_date 금지 → 선택/저장 불가
- 멱등성 재시도 → 중복 생성 없음
- 동시편집 충돌 → 409 발생, 데이터 찢김 없음
- Patch 멱등성 재시도 → 동일 (group_id, idempotency_key) 재요청 시 기존 결과 반환, 중복 적용 없음 (D-061)

## 관찰 refs (D-058)
- Observation upsert with inventory_refs:
  - given: owner has current inventory items for some types
  - when: rpc_upsert_observation_group_with_items with p_inventory_refs
  - then: observation_inventory_refs rows created/updated for provided types

- Patch does not mutate refs:
  - given: observation_group has refs stored
  - when: rpc_patch_observation_items modifies status/override_payload
  - then: observation_inventory_refs unchanged

## 냥스타그램
- private 저장 → 다이어리엔 보임, 피드/웹엔 안 보임
- public+미발행 → 피드/웹 노출 X
- 발행 → 노출 O
- 발행취소 → 노출 X
- 댓글 수정 → "수정됨" 표시 + 내부 감사로그 1개
- hide_from_profile → 프로필 목록 제외(링크/피드 공개 유지)
- 비공개 post의 댓글을 공개 경로로 조회 → 404 (D-063)
- 삭제된 post의 댓글을 공개 경로로 조회 → 404
- 차단 관계에서 post가 보이지 않는 경우 → 해당 post의 댓글 조회도 404

## 채널
- 토픽 랜딩/스레드 상세 SSR 확인(SEO)
- 피드3종 + cursor pagination
- 답글 1-depth + pagination
- 검색 FTS + noindex
- 닉네임 액션 메뉴 동작
- 차단 후 상호 비노출(피드/검색/프로필/상세)

## 하우스
- 슬롯 바인딩은 inventory_items 히스토리를 변경하지 않는다(배치만 변경).
- 슬롯 선택 리스트는 is_current=true만 노출된다.
- current 0개면 "먼저 냥벤토리에서 등록/현재 설정" 안내가 동작한다.
- public + 미발행(published_at null) → 타인 접근 404.
- public + 발행(published_at not null) → 타인 접근 가능(guard 통과 시).
- 미인증(anon) 공개 house 접근 → 404.
- block 관계(로그인 viewer 기준)에서 공개 house 링크 접근 시 404/비노출.
- 공개 응답 누출 방지:
  - cats.avatar_url 포함 안 됨(D-037)
  - inventory_item_id / inventory_items.id 포함 안 됨
  - raw_text, note, meta 포함 안 됨

## 운영
- 신고 누적 → D-054 기준으로 hidden_at 설정(삭제 X)
- 신고 악용 방지(중복/신뢰조건, D-054)
- 공개 표면의 조회 불가 상태는 404로 통일(D-050)
- anon viewer는 block 관계에 영향받지 않음(정상 동작 확인, AUTHZ-MODEL §0-2)
- 404 통일 검증 (D-050): 아래 모든 조건에서 공개 RPC/라우트는 404 반환:
  - 비공개(visibility=private)
  - 미발행(published_at IS NULL)
  - 삭제됨(deleted_at IS NOT NULL)
  - 숨김(hidden_at IS NOT NULL)
  - 차단(block 관계)
  - 미인증(anon → auth-only 경로)
  - 존재하지 않는 리소스

## 썸네일 라이프사이클 (D-072)
- post publish → assets-public에 썸네일 존재
- post unpublish → 썸네일 삭제(직링크 404)
- post hide → 썸네일 삭제
- 재발행 → 썸네일 재생성

## terms_agreed_at 가드 (D-073)
- terms NULL + write RPC → terms_not_agreed
- terms 설정 후 → 정상
- read RPC → terms 무관

## Popular 피드 (D-076)
- 7일 이내만 popular 노출
- score 순서(like + reply×2) 검증

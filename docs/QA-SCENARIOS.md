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

## 냥스타그램
- private 저장 → 다이어리엔 보임, 피드/웹엔 안 보임
- public+미발행 → 피드/웹 노출 X
- 발행 → 노출 O
- 발행취소 → 노출 X
- 댓글 수정 → "수정됨" 표시 + 내부 감사로그 1개
- hide_from_profile → 프로필 목록 제외(링크/피드 공개 유지)

## 채널
- 토픽 랜딩/스레드 상세 SSR 확인(SEO)
- 피드3종 + cursor pagination
- 답글 1-depth + pagination
- 검색 FTS + noindex
- 닉네임 액션 메뉴 동작
- 차단 후 상호 비노출(피드/검색/프로필/상세)

## 하우스

> See: D-035, D-043, D-055, D-057~D-060, EP-HOUSE-IMPL.md

### EP-1: 스키마 + Guard + 본인 RPC

#### 스키마 검증
- [ ] house_profiles 테이블 존재 (user_id, visibility, published_at, hidden_at, deleted_at, created_at, updated_at)
- [ ] house_slots 테이블 존재 (id, owner_id, room_key, slot_key, inventory_item_id, equipped_at, created_at, updated_at, deleted_at)
- [ ] house_profiles CHECK 제약 동작: visibility='private' AND published_at NOT NULL → 에러
- [ ] house_slots UNIQUE 제약 동작: (owner_id, room_key, slot_key) 중복 시 에러

#### Guard 함수 검증
- [ ] guard_soft_state(NULL, NULL) → TRUE
- [ ] guard_soft_state(now(), NULL) → FALSE
- [ ] guard_soft_state(NULL, now()) → FALSE
- [ ] guard_soft_state(now(), now()) → FALSE
- [ ] guard_block(NULL, any_uuid) → FALSE (anon 차단, D-057)
- [ ] guard_block(user_a, user_a) → TRUE (자기 자신)
- [ ] guard_block(user_a, user_b) → TRUE (차단 없음)
- [ ] guard_block(user_a, user_b) after A blocks B → FALSE
- [ ] guard_block(user_a, user_b) after B blocks A → FALSE (상호 차단)
- [ ] guard_visibility_published('public', now()) → TRUE
- [ ] guard_visibility_published('public', NULL) → FALSE
- [ ] guard_visibility_published('private', now()) → FALSE
- [ ] guard_visibility_published('private', NULL) → FALSE

#### 본인 RPC 검증 (rpc_get_my_house)
- [ ] 첫 호출 시 house_profiles 자동 생성 (D-060)
- [ ] 자동 생성 기본값: visibility='private', published_at=NULL
- [ ] 빈 상태에서 slots=[] 반환
- [ ] 슬롯 바인딩 후 slots 배열에 포함
- [ ] 바인딩된 아이템이 non-current가 되면 non_current_warning=true (D-043)
- [ ] anon 호출 시 에러 (Unauthorized)

#### 본인 RPC 검증 (rpc_save_house_slot)
- [ ] slot_key 범위 내(slot_01~slot_08) → 성공
- [ ] slot_key 범위 외(slot_09 등) → 400 에러 (D-059)
- [ ] is_current=true 아이템 → 성공
- [ ] is_current=false 아이템 → 400 에러
- [ ] 타인 소유 아이템 → 400 에러
- [ ] deleted_at NOT NULL 아이템 → 400 에러
- [ ] 기존 슬롯 덮어쓰기(UPSERT) → 성공
- [ ] anon 호출 시 에러 (Unauthorized)

#### 본인 RPC 검증 (rpc_delete_house_slot)
- [ ] 바인딩된 슬롯 비우기 → inventory_item_id=NULL, equipped_at=NULL
- [ ] 빈 슬롯 비우기 → 에러 없이 성공
- [ ] slot_key 범위 외 → 400 에러 (D-059)
- [ ] anon 호출 시 에러 (Unauthorized)

---

### EP-2: 공개 조회 RPC

#### 조회 가능 조건 검증
- [ ] public + published_at NOT NULL + hidden=null + deleted=null + no block → 슬롯 배열 반환
- [ ] private → NULL 반환 (404)
- [ ] public + published_at=NULL (미발행) → NULL 반환 (404)
- [ ] public + published + hidden_at NOT NULL → NULL 반환 (404)
- [ ] public + published + deleted_at NOT NULL → NULL 반환 (404)
- [ ] public + published + block 관계(A→B 또는 B→A) → NULL 반환 (404)
- [ ] anon(미인증) 접근 → NULL 반환 (404, guard_block에서 차단)
- [ ] house_profiles row 없음 → NULL 반환 (404)

#### is_current 검증 (D-043)
- [ ] is_current=true 슬롯 → 결과에 포함
- [ ] is_current=false 슬롯 → 결과에서 제외
- [ ] inventory_item_id=NULL 슬롯(빈 슬롯) → 결과에서 제외

#### 화이트리스트 검증 (D-055)
허용 필드 (반드시 포함 가능):
- [ ] slot_key ✓
- [ ] equipped_at ✓
- [ ] type ✓
- [ ] catalog.standard_name ✓
- [ ] catalog.brand ✓
- [ ] days_since_equipped ✓ (서버 계산 파생 필드)

금지 필드 (절대 미포함):
- [ ] inventory_item_id 미포함
- [ ] inventory_items.id 미포함
- [ ] raw_text 미포함
- [ ] note 미포함
- [ ] meta 미포함
- [ ] cats.avatar_url 미포함 (D-037)
- [ ] catalog_item_id 미포함

#### nickname 변환 검증
- [ ] 존재하는 nickname → user_id 변환 후 조회
- [ ] 존재하지 않는 nickname → NULL 반환 (404)

---

### EP-3: 통합 테스트 + CI

#### 통합 시나리오
- [ ] 본인 슬롯 저장 → 발행 → 타인 공개 조회 → 화이트리스트만 노출
- [ ] 본인 슬롯 저장 → 미발행 상태 → 타인 조회 → NULL
- [ ] 본인 발행 → 차단 → 타인 조회 → NULL
- [ ] 본인 발행 → 발행취소 → 타인 조회 → NULL
- [ ] 본인 슬롯 바인딩 → 아이템 current 변경 → 타인 조회 → 해당 슬롯 제외
- [ ] 슬롯 바인딩은 inventory_items 히스토리를 변경하지 않는다(배치만 변경)

#### CI 테스트 (자동화)
- [ ] 차단 스냅샷 테스트: block 후 공개 RPC → 0 rows
- [ ] 화이트리스트 테스트: 금지 필드 미포함 assertion
- [ ] Guard 함수 단위 테스트
- [ ] 본인 RPC 단위 테스트
- [ ] 공개 RPC 단위 테스트

---

## 운영
- 신고 누적 → D-054 기준으로 hidden_at 설정(삭제 X)
- 신고 악용 방지(중복/신뢰조건, D-054)
- 공개 표면의 조회 불가 상태는 404로 통일(D-050)

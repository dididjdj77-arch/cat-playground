# ADR-007 — House v1: 2D 거실 + 슬롯 배치 + 공개 모델(visibility + published_at)

- 상태: Accepted
- 날짜: 2026-02-01
- 관련 결정: D-006, D-035~D-039, D-018, D-037

## 문제
- 하우스 탭의 표현 방식과 공개 정책이 명확하지 않았음.
- 인벤토리 원장(inventory_items)의 프라이버시 경계를 어디까지 유지할지 불명확했음.
- 공개 시 어떤 정보를 노출하고, 어떤 정보를 차단해야 하는지 규칙이 없었음.

## 배경
- 하우스는 "등록된 고양이 + 인벤토리 장착 현황"을 시각화하는 전시 공간이다.
- 인벤토리 원장은 프라이버시 자산이며, owner-only 유지가 설계 원칙이다(D-018).
- 공개/발행 모델은 냥스타그램과 동일한 패턴(visibility + published_at)을 사용해 일관성을 유지한다.

## 선택지

### A) 카드/리스트 중심 UI + 인벤 전체 공개 옵션
- 장점: 구현 단순, 정보 제공 폭이 넓음
- 단점: 프라이버시 경계 확대, 노출 사고 표면 증가, 인벤 원장 owner-only 원칙 위반

### B) 2D 거실 씬 + 슬롯 배치 + 공개는 슬롯 요약만 (채택)
- 장점: 
  - 시각적 표현력 강화(2D 씬)
  - 프라이버시 경계 단순 유지(인벤 원장 owner-only)
  - 공개 범위를 화이트리스트로 제어 가능
  - 슬롯=배치(히스토리 아님) 개념 명확
- 단점: 
  - 2D 씬 구현 비용
  - 공개 정보가 제한적(요약만)

### C) MV/스냅샷 기반 공개
- 장점: 발행 시점 고정으로 일관성 보장
- 단점: 동기화/백필/정합성 비용 증가, v1 범위에서 과투자
- 결론: v1에서는 제외, 성능 이슈 발생 시 v1.1+에서 재검토

## 결정

### 1) 하우스 탭(내부)
- 하우스 탭 = 2D 거실(방 1개, room_key='living_room') 씬 + 슬롯 기반 배치 UI
- 슬롯은 **배치(연결)**이며, 인벤토리 히스토리 이벤트가 아니다.
- 슬롯 저장 시점에 **is_current=true만** 허용한다.

### 2) 하우스 공개/발행 모델
- house_profiles.visibility(private|public) + published_at(null|ts) 패턴 사용
- 타인 노출 조건:
  ```sql
  house_profiles.visibility = 'public'
  AND house_profiles.published_at IS NOT NULL
  AND house_profiles.deleted_at IS NULL
  AND house_profiles.hidden_at IS NULL
  AND (로그인 viewer 기준) block 관계 아님
  ```

### 3) 공개 DTO redaction
- 공개 하우스 응답/DTO에는 **cats.avatar_url을 절대 포함하지 않는다**.
- 공개 DTO는 **화이트리스트만** 반환한다:
  - 허용: slot_key, equipped_at, type, catalog 표준명/브랜드 등
  - 금지: inventory_item_id, inventory_items.id, raw_text, note, meta

### 4) 스냅샷 미채택
- 공개 하우스는 발행 시점 고정 스냅샷이 아니라 **현재 상태 기반**으로 노출한다.
- publish는 "노출 허용 상태 전환"이며 데이터는 실시간(현재) 기준이다.
- 성능 이슈는 OPEN(O-017)으로 관리하고 v1.1+에서 MV/캐시 도입 여부를 결정한다.

## 결과/영향

### 장점
- 프라이버시 경계가 명확하고 단순(인벤 원장 owner-only 유지)
- 공개 조건이 문서/코드에서 단일 불리언 식으로 강제 가능
- 노출 사고 표면 최소화(화이트리스트 강제)
- 2D 씬으로 시각적 표현력 향상

### 단점
- 2D 씬 구현 비용
- 공개 정보가 제한적(슬롯 요약만)
- 성능 이슈 가능성(v1.1+에서 대응)

### 리스크
- join/컬럼 확장 실수로 cats.avatar_url 누출 가능성 → RPC/뷰에서 화이트리스트 강제("select *" 금지)
- 슬롯 선택 시 non-current 아이템 선택 가능성 → 저장 시점 is_current=true 검증
- 이후 current 변경 시 처리 정책 → O-019로 관리

## 후속 작업
- SCHEMA-MIGRATIONS.md에 house_profiles/house_slots 마이그레이션 추가
- RPC-SPECS.md에 rpc_get_public_house_slots_summary 명세 추가
- TESTING-STRATEGY.md에 공개 하우스 화이트리스트 검증 테스트 추가
- QA-SCENARIOS.md에 하우스 공개 조건/누출 방지 시나리오 추가

# RLS-POLICY — Supabase RLS 정책(v1.1 RPC 중심)

## 원칙
v1.1에서는 "공개/외부/상품성 읽기 경로는 SECURITY DEFINER RPC only"를 기본으로 한다.
- 원본 테이블 direct select 금지(특히 anon)
- owner 전용 읽기/쓰기만 RLS로 허용 가능(개발 편의)
- SECURITY DEFINER 함수는 RLS를 우회할 수 있으므로, 함수 내부에서 soft-state + block + visibility/published를 강제해야 함
- 함수는 반환 컬럼을 화이트리스트로 제한(특히 하우스 슬롯 요약)

## Owner 테이블 (기본 RLS 허용)
### cats, inventory_items, observation_groups, observations
- SELECT: owner_id = auth.uid()
- INSERT/UPDATE/DELETE: owner_id = auth.uid()

## 공개 컨텐츠 (RPC 경유 필수)
### posts, threads, replies, topics
- 직접 SELECT 원칙적으로 금지
- 공개 피드/검색/상세는 RPC로 제공
- RPC 내부에서:
  - guard_soft_state(): deleted_at/hidden_at 필터
  - guard_block(): block 관계 필터
  - visibility/published_at 조건 강제

### 하우스 (house_profiles, house_slots)
- 직접 SELECT 제한(권장: REVOKE + RLS). 공개/타인 조회는 RPC만 허용.
- 공개 하우스 RPC 내부에서 반드시 강제:
  - guard_soft_state(): house_profiles.deleted_at/hidden_at + house_slots.deleted_at 필터
  - guard_visibility_published(): visibility='public' AND published_at IS NOT NULL
  - guard_block(): 로그인 viewer(auth.uid()) 기준 block 필터
- 반환 컬럼 화이트리스트(요약 DTO)만:
  - 슬롯 요약: slot_key, equipped_at, type, (옵션) catalog 표준명/브랜드 등
  - cats.avatar_url 포함 금지(D-037)
  - inventory_item_id / inventory_items.id / raw_text / note / meta 등 금지(O-014)

보안 하드닝(SECURITY DEFINER):
- search_path 고정(예: public)
- viewer_id는 auth.uid()로 도출(권장). 만약 입력으로 받는다면 p_viewer_id=auth.uid()를 assert.

## Moderation (blocks, reports)
- 직접 SELECT 제한
- RPC 경유 또는 owner 필터만

## 보안 하드닝 (SECURITY DEFINER 함수)
- search_path를 고정(예: public)
- 입력 viewer_id를 첫 단계에서 검증(assert)
- 외부 공개 RPC는 원본 테이블 직접 노출 금지

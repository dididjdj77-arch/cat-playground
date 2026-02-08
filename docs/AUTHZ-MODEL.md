# AUTHZ-MODEL — 권한/노출 정책

## §0. 공통 정책식 (SSOT)

> 이 섹션은 정책식의 **단일 원문**입니다. 다른 문서는 복붙 금지, 링크만 사용.

### 0-1. 공개 노출 필터
**posts, house_profiles**
```sql
WHERE deleted_at IS NULL
  AND hidden_at IS NULL
  AND NOT is_blocked(viewer_id, target_user_id)
  AND visibility = 'public'
  AND published_at IS NOT NULL
```
**threads, replies (및 descendants)**
```sql
WHERE deleted_at IS NULL
  AND hidden_at IS NULL
  AND NOT is_blocked(viewer_id, target_user_id)
```
- threads/replies는 visibility/published 모델이 없으므로 해당 필터를 적용하지 않는다.
- See: D-029 (guard), D-007 (발행 모델), D-016 (토픽 전부 공개), D-035 (하우스)

### 0-2. 차단 정책
- **상호 비노출**: A→B 또는 B→A 차단 시 양방향 비노출 + 상호작용 불가
- **anon viewer**: block 미적용 (viewer_id 없음)
- See: D-019

### 0-3. private + published_at 금지 (불변식)
```sql
CHECK (NOT (visibility = 'private' AND published_at IS NOT NULL))
```
- 전이 규칙: visibility를 private로 변경 시 published_at=NULL 강제
- See: D-007, D-035

### 0-4. 공개 하우스 접근 정책
- **auth-only**: 로그인 사용자만 접근 가능
- **anon 접근**: 404 (존재 은닉)
- See: D-035, D-044

---

## 역할
- anon(비로그인), auth(로그인), admin(운영자)

## 공통 노출 필터(필수)
See §0-1.

## 냥스타그램
- 소유자: private/미발행 포함 전부 읽기(다이어리)
- 타인/웹: See §0-1 (공개 노출 필터)
- 작성/수정/삭제/발행/취소: author만
- 프로필 목록: hide_from_profile=false만 노출(단 링크/피드는 공개 유지)

## 댓글
- 읽기: 부모 post가 공개 조건 만족할 때만
- 쓰기: 로그인 사용자(단 block 필터 통과)
- 수정/삭제: author만
- 수정 표기: "수정됨" + 내부 감사로그 1개

## 채널
- 토픽/스레드/답글 읽기: anon 포함(단 hidden/deleted/blocked 제외)
- 쓰기: 로그인 사용자
- 수정/삭제: author만
- 검색: anon 포함 가능(SEO는 noindex)

## 하우스/인벤토리
- inventory_items(인벤토리 원장): 항상 본인만(owner-only, D-018).
- observation_inventory_refs는 owner-only이며, 관찰 저장 시점 인벤 참조 고정을 위한 내부 데이터다.
- 하우스(본인): visibility/private 및 미발행 포함 항상 조회 가능.
- 하우스(타인): See §0-1 + §0-4 (auth-only, D-035)
- 타인에게 공개 가능한 인벤토리 정보: "하우스 슬롯 장착 요약(화이트리스트)"만(D-036).
- 공개 하우스 응답에는 cats.avatar_url 포함 금지(D-037).
- Public surface(공개 피드/SEO)에서는 inventory 관련 필드를 노출하지 않는다(API-CONTRACTS/RPC-SPECS 준수).

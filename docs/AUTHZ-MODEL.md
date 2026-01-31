# AUTHZ-MODEL — 권한/노출 정책

## 역할
- anon(비로그인), auth(로그인), admin(운영자)

## 공통 노출 필터(필수)
- deleted_at is null
- hidden_at is null (공개 노출 기준)
- block 관계면 비노출 + 상호작용 불가

## 냥스타그램
- 소유자: private/미발행 포함 전부 읽기(다이어리)
- 타인/웹: public AND published_at not null AND not hidden AND not blocked
- 작성/수정/삭제/발행/취소: author만
- 프로필 목록: hide_from_profile=false만 노출(단 링크/피드는 공개 유지)

## 댓글
- 읽기: 부모 post가 공개 조건 만족할 때만
- 쓰기: 로그인 사용자(단 block 필터 통과)
- 수정/삭제: author만
- 수정 표기: “수정됨” + 내부 감사로그 1개

## 채널
- 토픽/스레드/답글 읽기: anon 포함(단 hidden/deleted/blocked 제외)
- 쓰기: 로그인 사용자
- 수정/삭제: author만
- 검색: anon 포함 가능(SEO는 noindex)

## 하우스/인벤토리
- inventory_items(인벤토리 원장): 항상 본인만(owner-only, D-018).
- 하우스(본인): visibility/private 및 미발행 포함 항상 조회 가능.
- 하우스(타인): 아래 조건을 **모두** 만족 시에만 조회 가능(D-035):
  - house_profiles.visibility = 'public'
  - house_profiles.published_at IS NOT NULL
  - deleted_at IS NULL AND hidden_at IS NULL
  - (로그인 viewer 기준) block 관계 아님
- 타인에게 공개 가능한 인벤토리 정보: "하우스 슬롯 장착 요약(화이트리스트)"만(D-036).
- 공개 하우스 응답에는 cats.avatar_url 포함 금지(D-037).

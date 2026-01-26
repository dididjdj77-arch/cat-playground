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
- inventory_visibility=private: 본인만
- public: 타인도 조회 가능(요약 우선)
- block 관계면 비노출

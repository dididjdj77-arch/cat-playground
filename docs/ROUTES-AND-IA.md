# ROUTES-AND-IA — 앱/웹 라우팅 및 IA

## 앱 IA
- Tabs: 하우스 / 다이어리 / 소셜 / 설정
- 소셜 세그먼트: 냥스타그램 / 채널 (+추후 알림/내 활동)

## 다이어리 화면
- 상단 인라인 패널 2개(관찰/내 글): 기본 접힘, 저장 시 자동 접힘
- 하단 log_date 그룹 리스트(B1)
- 달력: 다이어리 탭 한 페이지(점프용)

## 하우스 화면(/house)
- 2D 거실 씬 + 슬롯 표시
- 빈 슬롯 탭 → 아이템 선택 모달(is_current=true 목록) → 바인딩 저장
- current 없으면 → "먼저 냥벤토리에서 등록/현재 설정" 안내
- "냥벤토리 관리"로 이동(추가/교체/중단/히스토리)
- "공개/발행 설정"으로 이동

## 냥벤토리 관리 화면(/inventory)
- 타입별 현재 카드(food/litter/toy/furniture)와 사용 시작일을 표기한다.
- 액션 버튼 라벨:
  - "교체"(switch): 새 항목 등록 + 기존 current 종료
  - "중단"(discontinue): current 종료만 수행
- 입력:
  - 선택 메모를 남길 수 있다.
  - 이벤트 코드는 사용자 입력이 아니라, "교체/중단/최초 등록" 액션 의미에 따라 기록된다(정의는 D-057, DATA-MODEL).
  - 정정(correction)의 사용자 노출 UX는 v1에서 별도 확정하지 않는다.
- 인벤 이벤트 모델은 D-057을 따른다.

## 관찰 작성 화면의 현재 인벤 참조
- 관찰 저장 시점에 타입별 current를 inventory_refs로 전달해 observation_inventory_refs를 고정 기록한다.
- 관찰 수정(Patch)은 refs를 바꾸지 않는다(변경 필요 시 D-058의 재작성 루트 준수).
- 관찰 refs 고정은 D-058을 따른다.

## 채널 화면(Blind 벤치마킹)
- 검색 + 피드(인기/최신/팔로잉)
- 토픽 탐색/팔로우
- 스레드 상세: 본문 + 답글(1-depth) + 좋아요/신고/차단
- 닉네임 탭: 액션 메뉴(고양이/하우스/냥스타)

## 공개 하우스 보기
- /u/{nickname}/house : 공개 하우스 보기
- **접근**: auth-only (로그인 필수). See AUTHZ-MODEL §0-4.
- **조건 미충족 시**: 404 (존재 은닉)

## 웹 SEO 라우트
- 채널:
  - /c
  - /c/{topicSlug} (index)
  - /c/{topicSlug}/{threadId} (index)
- 공개 냥스타:
  - /p
  - /p/{postId} (index)
- 내부 검색:
  - /search?q=... (noindex)

SEO 정책:
- index: 토픽 랜딩/스레드 상세/공개 글 상세
- noindex: 내부 검색 결과
- 공개 하우스: auth-only이므로 SEO 제외 (v1)

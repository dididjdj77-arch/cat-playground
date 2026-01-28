# CONTEXT — 고양이놀이터(가제) (SSOT 진입점)

## Agent Operating Rules (for any chat/agent)

- Start packet: 항상 docs/INDEX.md + docs/CONTEXT.md 를 함께 제공한다.
- SSOT: docs/DECISIONS.md 는 append-only 원장이다. 기존 D-###는 수정/삭제하지 않고, 변경은 항상 “맨 끝에 새 D-### 추가(supersede)”로만 한다.
- D-번호는 문서의 마지막 D-번호 + 1로 계산한다(문서 텍스트에 적힌 특정 번호 예시는 무시).
- docs/OPEN.md / docs/TODO.md 는 작업 문서이며 O-### / T-### 식별자를 유지한다.
- docs 문서는 전체 덮어쓰기 금지(부분 교체/추가만).
- 임시 스냅샷 파일(DECISIONS_BRANCH.md, DECISIONS_MAIN.md)은 repo에 포함하지 않는다(.gitignore로 차단).

이 문서는 새 채팅에서 컨텍스트 복구용 1장이다.
기본 진입점은 docs/INDEX.md 이다.
확정(LOCK)은 docs/DECISIONS.md가 최종이다.


목적: 대화/세션이 여러 개로 나뉘어도 “현재 상태”를 즉시 복구하기 위한 컨텍스트 패킷.

## 1) 한 줄 정의
집사들이 다묘 관찰(다이어리)과 커뮤니티(채널 + 냥스타그램)를 통해 정보를 축적/탐색하는 서비스.

## 2) 목표 / 비목표
### 목표
- 기록(관찰/다이어리) UX는 라이트하게, 데이터는 정합하게(다묘)
- 공개/비공개 혼란을 구조적으로 제거(표면 분리 + 발행 개념)
- 채널은 Blind 벤치마킹 UX(익명성 제외): 인기/최신/팔로잉, 토픽 팔로우, 답글, 좋아요, 검색
- 웹은 SEO 검색 유입 목적(공개 토픽/스레드/공개 글 색인)

### 비목표(v1)
- 익명성(Blind의 핵심)은 구현하지 않음
- 대댓글 무한 스레드(답글의 답글): v1은 1-depth 고정
- 대규모 개인화 추천/알림: v1.1~v2

## 3) 확정(LOCK) 핵심 요약
- 앱 IA: 하단 탭 4개(하우스/다이어리/소셜/설정)
- 소셜 세그먼트: 냥스타그램, 채널 (+추후 알림/내 활동)
- 표면 분리:
  - 다이어리 = “내 것”(관찰 + 내 냥스타그램), log_date 기준 누적
  - 소셜/웹 = “공개 + 발행된 것만” 탐색/상호작용
- 다이어리 UX:
  - 상단 인라인 작성 패널 2개(관찰/내 냥스타) 기본 접힘, 저장 시 자동 접힘
  - 하단 날짜 그룹 리스트(B1), log_date 기준
  - 달력은 다이어리 탭 안에서만(한 페이지), 점프용
- log_date 정책: 오늘 이하만 허용(미래 금지)
- 드래프트: 로컬-only, 서버 반영은 저장 버튼 시점
- 관찰(다묘): UI 1카드처럼, 저장은 고양이별 N 레코드 + override + excluded(삭제 아님)
- 냥스타그램: visibility(private/public) + published_at(null/ts) + log_date
  - 공개 노출: public AND published_at not null AND not hidden
  - 발행/발행취소: published_at set/unset
  - 상호작용: 좋아요 + 댓글 CRUD(수정 포함)
  - 댓글 수정 정책: 시간 제한 없음 + “수정됨” 표시 + 내부 감사로그(이전 본문 1개 보관)
- 채널 v1(Blind 벤치마킹, 익명성 제외): 글/답글(1-depth)/좋아요/검색 + 인기/최신/팔로잉 + 토픽 팔로우
- 토픽 전부 공개(SEO 대상)
- 운영 최소장치 v1: 액션별 레이트리밋 + 신고 + 차단(상호 비노출) + 조건부 자동숨김 + 감사로그
- 닉네임 탭 UX: 즉시 이동이 아니라 액션 메뉴(텍스트 버튼)로 “고양이정보/하우스보기/냥스타그램” 이동
- 인벤토리 공개/비공개: 사용자 설정(기본값 비공개 권장)
- AC-3 정규화: 자동완성 + 자유입력 + 제안 큐(pending) + 관리자 승인/별칭/병합 UI

## 4) 기술 스택(가정, 변경 가능)
- 앱: Expo(React Native)
- 웹(SEO): Next.js(SSR/ISR)
- 백엔드: Supabase(Postgres/Auth/Storage/Edge Functions)
- 검색: DB FTS(tsvector)로 시작

스택 변경은 가능하되, 정책/도메인/데이터 모델을 깨는 변경이면 ADR로 기록.

## 5) 현재 문서 위치
- 확정(LOCK): docs/DECISIONS.md
- 미결정(OPEN): docs/OPEN.md
- 다음 2~3단계: docs/TODO.md

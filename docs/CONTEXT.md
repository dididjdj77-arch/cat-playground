# CONTEXT — 고양이놀이터(가제) (세션 복구용 1장)

## Agent Operating Rules

### 읽기 순서
1. CONTEXT.md (이 파일)
2. INDEX.md (경로 목록)
3. DECISIONS.md (확정 원장)
4. 필요한 문서 (AUTHZ, DATA-MODEL 등)

### 문서 역할 (SSOT)

| 문서 | 책임 | 금지 |
|------|------|------|
| CONTEXT | 운영규칙/세션복구/읽기순서 | 도메인 정책식 복붙 |
| INDEX | 경로 목록만 | 규칙/설명 문장 |
| DECISIONS | 확정(D-###) 원장 | 삭제/번호 재사용 |
| OPEN | 미정의(O-###) | 확정 결론 |
| AUTHZ-MODEL | 정책식 원문(§0) | — |
| ADR/* | 방향 전환 근거 (최대 5개) | 템플릿 미준수 ADR |
| PROCESS | 프로세스/EP/PR 운영 규칙 | 정책/설계 결정 |
| CONFIG-BASELINES | 운영 파라미터 기준값(수치/임계치) | 원칙/정책 |
| playbooks/* | 수행자 실행 가이드(체크리스트/템플릿/검증). 작업유형별 8개: migrations, rls-and-guards, rpc-owner, rpc-public, ops-app-config, seo-web, moderation, payload-version-kpi | 정책식 원문 복붙 |

### 변경 규칙

- Start packet: 항상 docs/INDEX.md + docs/CONTEXT.md 를 함께 제공한다.
- INDEX: "문서 경로 목록"만 유지 (규칙/설명은 CONTEXT/각 문서에만).
- DECISIONS:
  - D-### 번호는 영구 할당 (재사용 금지).
  - 내용 수정 허용 (오타/명확화/정정).
  - 삭제 금지 (참조 안정성). superseded는 Status/링크로 표시.
  - 근본적 방향 전환은 ADR로 근거 기록.
- D-번호는 문서의 마지막 D-번호 + 1로 계산.
- OPEN: 해소되면 `Status: Resolved → D-###` 표시.
- ADR: 실제 ADR 최대 5개 (Template 제외). 초과시 DECISIONS에 흡수 후 삭제.
- docs 문서는 전체 덮어쓰기 금지 (부분 교체/추가만).

### 정책식 원문 위치
- 공개 노출 조건, 차단 정책, 불변식은 **AUTHZ-MODEL.md §0**에 정의.
- 다른 문서는 `See AUTHZ-MODEL §0` 링크만 사용.

---

## 1) 한 줄 정의
집사들이 다묘 관찰(다이어리)과 커뮤니티(채널 + 냥스타그램)를 통해 정보를 축적/탐색하는 서비스.

---

## Current Status (Session Restore)
- Phase: Implementation (docs/process refactor)
- Last merged PR: unknown
- Work starts: User-provided Execution Packet only (no task list doc)
- Tracking key: EP-ID + PR (no T-XXX)

---

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
> 상세는 DECISIONS.md 참조

- 앱 IA: 하단 탭 4개(하우스/다이어리/소셜/설정)
- 소셜 세그먼트: 냥스타그램, 채널 (+추후 알림/내 활동)
- 표면 분리: 다이어리="내 것", 소셜/웹="공개+발행된 것만"
- 공개 노출 조건: See AUTHZ-MODEL §0
- 채널 v1: 글/답글(1-depth)/좋아요/검색 + 피드3종 + 토픽 팔로우
- 운영 최소장치 v1: 레이트리밋 + 신고 + 차단(상호 비노출) + 자동숨김 + 감사로그

## 4) 기술 스택
- 앱: Expo(React Native)
- 웹(SEO): Next.js(SSR/ISR)
- 백엔드: Supabase(Postgres/Auth/Storage/Edge Functions)
- 검색: DB FTS(tsvector)로 시작

본 기술 스택 및 배포 기준선은 DECISIONS D-049로 확정(LOCK)됨. 변경 시에는 새로운 ADR/Decision이 필요함.

스택 변경 시 정책/도메인/데이터 모델을 깨면 ADR로 기록.

## 5) 협업 분업 원칙

**컨트롤 플레인** (사용자 + 어시스턴트):
- 설계·검증·판단: SSOT/LOCK/OPEN/ADR 기준
- 최종 리뷰·승인: PR diff/테스트 검토 → 승인/수정지시
- 충돌 처리: 자동 결론 금지, 차이/영향 정리 → 질문

**데이터 플레인** (omoc/Claude Code 등):
- 구현 실행: 컨트롤 플레인이 정한 스코프/DoD 범위 내에서만
- 산출: PR + CI/테스트 결과
- 불확실시: 임의 결론 대신 질문으로 멈춤

## 6) 현재 문서 위치
- 확정(LOCK): docs/DECISIONS.md
- 미결정(OPEN): docs/OPEN.md

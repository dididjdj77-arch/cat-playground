# INDEX — SSOT 문서 네비게이션(업로드용)

> Start packet: 새 채팅에서는 docs/INDEX.md + docs/CONTEXT.md 를 함께 제공한다.

> SSOT: 확정(LOCK)은 docs/DECISIONS.md 기준이며, 변경은 PR로만 반영한다.

> INDEX 원칙: docs/INDEX.md는 “문서 파일(경로/이름) 목록”만 관리한다.

> - docs/DECISIONS.md / docs/OPEN.md / docs/TODO.md의 항목(D-###/O-###/T-###) 내용은 각 파일에서만 관리한다(※ INDEX에 항목을 복제하지 않는다).

> - ADR은 파일 단위 문서이므로, 새 ADR 파일을 추가/삭제할 때만 INDEX의 docs/ADR 파일 목록을 갱신한다.


이 파일은 “ChatGPT에 1개만 업로드해도 문서 구조를 복구”하기 위한 인덱스다.
원문 SSOT는 각 문서에 있으며, 상세는 링크된 파일을 참조한다.

## 0) 최소 업로드 세트(추천)
- docs/INDEX.md (이 파일)
- docs/CONTEXT.md (세션 복구용 1장)

## 1) 핵심 진입점(우선순위)
- docs/CONTEXT.md
- docs/DECISIONS.md
- docs/ARCHITECTURE-OVERVIEW.md

## 2) 진행 상태(업무용)
- docs/OPEN.md
- docs/TODO.md

## 3) 도메인/데이터/권한(구현용)
- docs/DOMAIN-MAP.md
- docs/DATA-MODEL.md
- docs/AUTHZ-MODEL.md
- docs/RLS-POLICY.md

## 4) API/IA/QA(실행용)
- docs/API-CONTRACTS.md
- docs/ROUTES-AND-IA.md
- docs/QA-SCENARIOS.md

## 5) ADR(결정 근거)
- docs/ADR-000-template.md
- docs/ADR-001-channel-v1.md
- docs/ADR-002-observation-storage.md
- docs/ADR-003-web-seo-v1.md
- docs/ADR-004 jsonb-meta-promotion (Accepted)
- docs/ADR-005 guard-filters-performance (Accepted)
- docs/ADR-006 payload-version-kpi (Accepted)


## 6) 로컬 실행
- docs/HOWTO/local-setup.md

## 7) 운영 규칙(간단)
- 최신 LOCK만 진실: 확정은 DECISIONS 기준
- OPEN/TODO는 바뀌어도 됨(작업 상태)
- 컨텍스트 복구는 CONTEXT 1장으로 해결

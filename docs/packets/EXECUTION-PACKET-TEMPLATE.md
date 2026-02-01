1) SSOT read first

이 작업이 의존하는 필수 문서 경로

예: docs/RPC-SPECS.md, docs/DECISIONS.md의 특정 D-###, 관련 ADR, 스키마 체크리스트 등

2) Goal

실행자가 달성해야 할 정확한 목표(1~5줄)

“무엇을 구현/변경” + “성공 조건”이 포함돼야 함

3) Non-goals

이번 작업에서 하지 않는 것 (스코프 누수 방지)

4) Branch / PR

브랜치명, PR 제목, 커밋 메시지(표준화용)

PR 제목/본문에는 T-XXX 포함(우리 D-048 규칙)

5) Allowed changes

변경 허용 경로(가장 중요)

예: supabase/migrations/**만

금지 경로(필요하면 명시)

6) Validation

실행자가 반드시 돌릴 검증 명령/테스트

예: supabase db reset

예: SQL smoke / API 호출 / e2e 등

“무엇을 보면 성공인지”까지 적기

7) Evidence required

PR 본문(Result Packet)에 어떤 출력/증빙을 붙일지

예: git diff --name-only origin/main...HEAD 출력

예: SQL 호출 + 결과 출력

예: 스크린샷이 필요하면 어떤 화면인지

8) DoD (Definition of Done)

머지 가능한 “완료 정의”

기능 완료 + 검증 통과 + 증빙 첨부 + 스코프 준수

9) Risks / Notes (선택이지만 권장)

데이터 손상/권한/롤백 위험이 있으면 최소 안전장치

예: “트랜잭션 필수”, “유니크 제약 추가”, “SECURITY DEFINER search_path 고정” 등

10) OPEN questions (있으면 반드시)

SSOT에 없어서 결정 못 한 것(추측 금지)

“이건 질문하고 답 없으면 중단”까지 포함
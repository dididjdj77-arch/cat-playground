# PROCESS — 프로세스/워크플로우 SSOT

> 이 문서는 EP(Execution Packet) 운영, 문서 관리, PR 규칙, 리스크 판정, 역할 분업의 단일 원문입니다.
> 정책/설계 결정은 DECISIONS.md, 운영 수치는 CONFIG-BASELINES.md를 참조.

---

## 1. SSOT 운영 방식 (from D-011)

### 문서 체계
- SSOT: CONTEXT / INDEX / DECISIONS / OPEN (+ ADR/* 필요 시)
- Work unit: EP-ID + PR (Execution Packet 기반). TODO 문서는 사용하지 않는다.

### 회차 종료 체크(3줄)
1. DECISIONS: 신규 D-### 추가/정정 반영 여부
2. OPEN: 상태 갱신(Resolved → D-### 링크) 반영 여부
3. PR: EP-ID ↔ PR 링크(또는 PR 본문 Result Packet) 기록 여부

---

## 2. SSOT 문서 자동 PR 규칙 (from D-027)

- SSOT 문서 변경은 D-### 결정 키를 기준으로 수행한다(헤딩 전체 텍스트 일치에 의존하지 않는다).
- 동일 요청을 여러 번 실행해도 동일 PR을 반환해야 한다(멱등성).
- GitHub Contents API는 대상 브랜치의 최신 sha 기준으로 처리한다.
- sha mismatch(409) 발생 시 최신 sha 재조회 후 1회 재시도한다.

---

## 3. DECISIONS 운영 규칙 (from D-034)

- D-### 번호는 "영구 할당"이며 재사용 금지.
- 기존 D-###의 "내용 수정"을 허용한다(오타/명확화/정정/정보 업데이트 포함).
- 삭제는 금지한다(참조 안정성). 필요 시 해당 D 항목 상단에 Status를 표시한다:
  - Status: active | superseded | MOVED
  - See: ADR-### 또는 관련 D-### 링크
- 근본적 방향 전환(정책/권한/아키텍처 패턴 변경)은 ADR로 근거를 남긴다.
- Git commit 메시지에 변경 이유(Reason)를 남긴다(문서는 현재 상태 우선, 이력은 Git이 관리).

---

## 4. Execution/Result Packet 운영 (from D-047)

### 원칙
- 모든 구현 작업은 Execution Packet(EP) 단위로 진행한다.
- 각 티켓은 Execution Packet(EP)으로 지시하며, EP 템플릿은 이 문서 Appendix A를 따른다.
- 결과 제출은 PR 1개로 하며, PR 본문은 Result Packet 형식을 채운다.
- PR 생성 시 기본 본문은 `.github/pull_request_template.md`를 따른다.
- EP에는 최소한 Allowed changes / Validation / DoD / Evidence required를 포함한다.
- Result Packet에 Evidence(실행한 명령/SQL + 출력)가 없으면 "미검증"으로 간주하고 리뷰를 중단한다(불합격).
- EP는 작업 유형에 따라 Annex를 첨부한다 (See Appendix A):
  - Annex A (RPC/API): Contract + Security/Data integrity
  - Annex B (Migration): Migration file path + rollback + backfill
  - Annex C (Config/Ops): Config key + seed + access control
  - Annex가 없는 작업(문서/UI 등): 공용 코어만 작성
- EP Meta 섹션에는 Risk level(PRECISE/FAST), Playbook refs, Prerequisites를 필수 기재한다.
- Validation 기대 수준은 Risk level에 따라 구분한다:
  - PRECISE: exact smoke + exact negative + expected output
  - FAST: exact smoke 1개 이상 + negative는 조건 설명(output 생략 가능)

### EP 번들링 정책(실행 단위)
- 설계 원칙으로서 "유저 액션 = EP"는 유지하되, 실행 EP는 화면/플로우 번들링을 허용한다(속도 목적).
- 단, 아래 항목은 고위험으로 간주하여 **단독 EP**로 고정한다(번들 금지):
  - 관찰 upsert/patch(멱등/409/version_conflict/부분쓰기)
  - publish/unpublish 전이(썸네일 라이프사이클 트리거 포함)
  - 공개 표면 게이트(G-1~G-4)에 직접 영향(공개 DTO/404 통일/부모 가드 종속)
  - 차단/신고/자동숨김(운영/남용 리스크)
- 번들 EP도 Scope control(Allowed/Forbidden/Non-goals)을 강하게 작성한다.
- PR에서 Forbidden 변경이 발생하면 즉시 분리 EP로 쪼개서 재제출한다(범위 슬립 방지).
- PR 템플릿에는 "고위험 단독 EP 항목 포함 여부/단독 EP 분리 여부" 체크를 필수 기재한다.

---

## 5. EP-ID 관리 (from D-048)

- EP 식별자는 EP-ID를 SSOT로 사용한다(예: EP-YYYYMMDD-<slug>).
- Execution Packet ID는 `EP-<EP-ID>`로 표기한다.
- PR 제목과 본문(Result Packet)에는 EP-ID를 반드시 포함한다.
- Result Packet은 `EP-ID`로 추적하며, 별도 "Result 번호"는 두지 않는다.
- (선택) GitHub Issue를 쓰는 경우, Issue 번호는 참고 링크로만 둔다(SSOT는 EP-ID 유지).

---

## 6. 고위험 판정 원칙 (from D-032)

고위험은 키워드가 아니라 영향도(Blast radius)와 롤백 가능성으로 판단한다. 아래 6문항 중 하나라도 "예/의심"이면 PRECISE 우선:

1. 롤백 난이도(되돌리기 비용/다운타임/복구 난이도)
2. 데이터 유실/오염 가능성(대량 UPDATE/DELETE/정합성 훼손)
3. 공개/비공개 경계 변화(anon 접근, SEO 노출, 공개 URL/스토리지)
4. 권한/정책 변화(RLS, SECURITY DEFINER RPC, 우회 가능성)
5. 스키마/마이그레이션 성격(컬럼/인덱스/제약/키 변경, 백필성 작업 포함)
6. 외부/클라이언트 영향(API 계약, 앱/웹 동시 영향, 캐시/검색 영향)

PRECISE는 최소 안전장치(DoD/검증/롤백)를 반드시 포함한다. FAST도 PR/스모크/체크리스트로 되돌리기 가능성을 확보한다.

---

## 7. 컨트롤/데이터 플레인 분업 (from D-033)

**컨트롤 플레인** (사용자 + 어시스턴트):
- 설계·검증·판단: SSOT/LOCK/OPEN/ADR 기준
- 최종 리뷰·승인: PR diff/테스트 검토 → 승인/수정지시
- 충돌 처리: 자동 결론 금지, 차이/영향 정리 → 질문

**데이터 플레인** (omoc/Claude Code 등):
- 구현 실행: 컨트롤 플레인이 정한 스코프/DoD 범위 내에서만
- 산출: PR + CI/테스트 결과
- 불확실시: 임의 결론 대신 질문으로 멈춤

---

## 8. Public Surface Gate 운영 규칙

- Public 표면(공개 RPC/SEO 라우트/공개 DTO/404 통일/부모 가드 종속)에 영향을 주는 PR(추가/확장/버그픽스 포함)은 DTO whitelist 테스트를 반드시 동반한다.
- Public Surface Gate(G-1/G-2/G-3/G-4)는 Public 표면 영향 PR의 필수 자동 게이트이며, 4개 모두 통과해야 한다.
- G-1/G-2/G-3/G-4 중 하나라도 실패하면 해당 PR은 불합격(머지 불가)이다.
- Phase 2(App) 시작 전, Auth Spike Gate는 플랫폼별(최소 iOS 1회 + Android 1회)로 통과해야 한다.
- Auth Spike 증거는 staging 기준으로 플랫폼별 1세트를 PR에 첨부한다(dev/prod는 체크리스트 관리 중심).
- Auth Spike DoD/체크리스트는 `docs/VERIFICATION.md`의 "Auth Spike Gate"를 SSOT로 따른다.
- 게이트 정의와 시나리오는 `docs/VERIFICATION.md`를 SSOT로 참조한다.

## History

### 해소된 충돌 (DECISIONS에서 이관)
- 채널 v1 범위: "답글/좋아요/검색까지 포함" 사용자 확정 발언으로 D-013 고정.
- 닉네임 이동 UX: "바로 페이지 이동 아님, 메뉴로" 사용자 확정 발언으로 D-017 고정.

---

## Appendix A — Execution/Result Packet 템플릿


> 작업 지시(Execution)와 결과 보고(Result)를 위한 표준 양식.
> See: D-047 (Execution/Result Packet 운영 표준), D-048 (EP-ID 식별자)

---

## 사용 방법

1. 공용 코어는 모든 EP에 필수다.
2. Annex는 작업 유형에 맞는 것만 선택 첨부한다.
3. Annex가 없는 작업(문서/UI 등)은 코어만 작성한다.
4. Result Packet은 모든 작업 유형에서 동일 양식을 사용한다.

---

## Execution Packet — 공용 코어 (모든 EP 필수)

```markdown
# Execution Packet — EP-<EP-ID>: <short title>

## Meta
- Risk level: PRECISE / FAST (See PROCESS §6)
- Playbook refs: docs/playbooks/<...>.md (복수 가능)
- Prerequisites: EP-<선행 EP-ID> (없으면 "none")

## SSOT read first
- docs/<...>.md
- docs/DECISIONS.md (D-###, D-###)
- docs/ADR/ADR-###-....md (if any)

## Goal
- What to implement:
  - ...
- Success criteria (user-visible / API-visible):
  - ...

## Scope control
- Allowed changes:
  - <paths>
- Forbidden changes:
  - <paths / "everything else">
- Non-goals (out of scope, explicit):
  - ...

## Implementation notes
- Minimal design constraints (do not over-engineer):
  - ...
- Known risks / edge cases:
  - ...

## Validation (must run)
- PRECISE: exact commands/sql + expected output (smoke + negative)
- FAST: exact smoke 1개 이상 + negative는 조건 설명 가능
- Setup:
  - <commands>
- Smoke tests:
  - <exact commands/sql + expected output>
- Negative tests:
  - <exact commands/sql + expected failure>

## DoD
- Functional DoD:
  - ...
- Safety DoD:
  - no partial writes / no privilege leak / no scope creep
- Evidence required in PR:
  - paste output for smoke + negative tests
  - list changed files

## OPEN questions (if any)
- ...
```

---

## Annex A — RPC/API 작업

```markdown
## [Annex A] Contract
- Entry point(s): <RPC / route / job>
- Inputs (required): <fields>
- Outputs (required): <fields>
- Error policy (해당 코드만 기재):
  - 400: ...
  - 409: ...
  - (기타 해당 시)

## [Annex A] Security / Data integrity
- AuthN/AuthZ expectations:
  - <SECURITY DEFINER? RLS? auth-only?>
- Transaction boundary:
  - <single tx?> <rollback on error?>
- Idempotency:
  - key: <field>
  - uniqueness scope: <e.g., (owner_id, idempotency_key)>
  - replay behavior: 최초 성공과 동일 응답 shape 반환 (status-only 금지)
- Error return pattern:
  - DB 함수는 비즈니스 에러를 JSON return으로 전달한다 (raise exception은 hard fail만, D-065)
  - PostgREST 경유 시 DB 함수가 예외 없이 정상 return하면 HTTP 200이 기본이며, 클라이언트는 body.error_code로 판별한다
  - 권한/EXECUTE 거부나 hard fail 예외는 4xx/5xx가 될 수 있다
- Invariants to enforce:
  - <DB CHECK/UNIQUE constraints>
  - <state invariants>
```

---

## Annex B — Migration 작업

```markdown
## [Annex B] Migration details
- Migration file path: supabase/migrations/<NNN>_<name>.sql
- File order dependencies: <선행 migration 번호>
- Rollback SQL path: supabase/migrations/<NNN>_<name>_down.sql (또는 inline)
- Backfill plan: <있으면 기술, 없으면 "N/A">
- RLS 분리: RLS 변경은 별도 migration/단계로 분리 (See playbook: migrations)
```

---

## Annex C — Config/Ops 작업

```markdown
## [Annex C] Config details
- Config key(s): <app_config key 목록>
- Seed value reference: CONFIG-BASELINES.md#<section>
- Access control changes: <GRANT/REVOKE 변경 여부>
- Whitelist update: <rpc_get_app_config whitelist에 key 추가 여부>
```

---

## Result Packet Template (PR Description)

```markdown
# Result Packet — EP-<EP-ID>: <short title>

## What changed
- Files changed:
  - ...
- Summary:
  - ...

## Scope compliance
- EP Scope control 기준: EP-<EP-ID>
- Allowed changes only: ✅ / ❌
- Forbidden paths touched: ✅ none / ❌ yes (explain)

## How to verify
- Environment:
  - <local / CI> + <versions if relevant>
- Commands executed:
  - <cmd1>
  - <cmd2>

## Evidence (copy/paste outputs)
### Smoke
- <command/sql>
- Output:
  - ...

### Negative tests
- <command/sql>
- Output:
  - ...

## Risk notes
- Rollback plan:
  - <how to revert safely>
- Edge cases:
  - ...

## OPEN questions (if any)
- ...
```

---

## Appendix B — 로컬 셋업(초안)


전제: Expo 앱 + Next.js 웹 + Supabase 백엔드

1) Node LTS, pnpm, Supabase CLI 설치
2) supabase start
3) migrations 적용(supabase/migrations)
4) env 설정(SUPABASE_URL/KEY)
5) 앱 실행(expo start), 웹 실행(next dev)
6) 체크:
- anon으로 공개 토픽/스레드/공개 글 읽기
- 로그인 후 작성/댓글/답글/좋아요
- 차단/숨김이 노출 정책에 반영

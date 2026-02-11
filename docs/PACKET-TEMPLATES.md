# PACKET-TEMPLATES — Execution/Result Packet 템플릿

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

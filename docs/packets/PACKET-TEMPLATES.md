# PACKET-TEMPLATES — Execution/Result Packet 템플릿

> 작업 지시(Execution)와 결과 보고(Result)를 위한 표준 양식.
> See: D-047 (Execution/Result Packet 운영 표준), D-048 (T-XXX 식별자)

---

## Execution Packet Template

```markdown
# Execution Packet — EP-T-XXX: <short title>

## SSOT read first
- docs/<...>.md
- docs/DECISIONS.md (D-###, D-###)
- docs/ADR-###-....md (if any)

## Goal
- What to implement:
  - ...
- Success criteria (user-visible / API-visible):
  - ...

## Non-goals
- Out of scope (explicit):
  - ...

## Scope control
- Allowed changes:
  - <paths>
- Forbidden changes:
  - <paths / "everything else">

## Contract
- Entry point(s): <RPC / route / job>
- Inputs (required): <fields>
- Outputs (required): <fields>
- Error policy:
  - 400: ...
  - 401/403: ...
  - 404: ...
  - 409: ...

## Security / Data integrity
- AuthN/AuthZ expectations:
  - <SECURITY DEFINER? RLS? auth-only?>
- Transaction boundary:
  - <single tx?> <rollback on error?>
- Idempotency:
  - key: <field>
  - uniqueness scope: <e.g., (owner_id, idempotency_key)>
  - retry behavior: <return same result>
- Invariants to enforce:
  - <DB CHECK/UNIQUE constraints>
  - <state invariants>

## Implementation notes
- Minimal design constraints (do not over-engineer):
  - ...
- Known risks / edge cases:
  - ...

## Validation (must run)
- Setup:
  - <commands>
- Smoke tests:
  - <exact commands/sql + expected output>
- Negative tests (at least 1~2):
  - <exact commands/sql + expected failure>

## DoD
- Functional DoD:
  - ...
- Safety DoD:
  - no partial writes / no privilege leak / no scope creep
- Evidence required in PR:
  - paste output for smoke + negative tests
  - list changed files
```

---

## Result Packet Template (PR Description)

```markdown
# Result Packet — T-XXX: <short title>

## What changed
- Files changed:
  - ...
- Summary:
  - ...

## Scope compliance
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

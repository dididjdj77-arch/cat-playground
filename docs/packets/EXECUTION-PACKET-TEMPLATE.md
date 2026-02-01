# OMOC Execution Packet — EP-XX: <short title>

## SSOT read first
- docs/<...>.md
- docs/DECISIONS.md (D-###, D-###)
- docs/ADR/ADR-###-....md (if any)

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
  - <paths / “everything else”>

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

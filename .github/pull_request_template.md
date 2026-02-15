# Result Packet (PR Evidence Template)

> Paste this into the PR description. Do not delete sections.

## What changed
- Files changed:
  - ...
- Summary:
  - ...

## Scope compliance
- Allowed changes only: ✅ / ❌
- Forbidden paths touched: ✅ none / ❌ yes (explain)

## EP / Gate checks
- EP-ID: EP-<EP-ID>
- [ ] 고위험 단독 EP 항목 없음
- [ ] 고위험 단독 EP 항목 포함, 단독 EP로 분리 완료
- [ ] Public 표면 영향 없음
- [ ] Public 표면 영향 있음, G-1/G-2/G-3/G-4 모두 green
- [ ] (해당 시) Auth Spike Gate(iOS/Android staging) 증거 링크 첨부

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

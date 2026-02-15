# Doc refactor apply notes (for Codex)

## Add / Update (write these paths)
- docs/CONTEXT.md
- docs/INDEX.md
- docs/DECISIONS.md
- docs/OPEN.md
- docs/ARCHITECTURE-OVERVIEW.md
- docs/AUTHZ-MODEL.md
- docs/DATA-MODEL.md
- docs/CONFIG-BASELINES.md
- docs/PROCESS.md
- docs/API.md (new)
- docs/VERIFICATION.md (new)

Playbooks:
- docs/playbooks/migrations.md
- docs/playbooks/rls-and-guards.md
- docs/playbooks/rpc-owner.md
- docs/playbooks/rpc-public.md
- docs/playbooks/ops-app-config.md
- docs/playbooks/seo-web.md
- docs/playbooks/moderation.md
- docs/playbooks/payload-version-kpi.md

ADR:
- docs/ADR/*.md (no change except ADR-007 references updated)

## Delete (remove these files)
- docs/PACKET-TEMPLATES.md
- docs/DOMAIN-MAP.md
- docs/API-CONTRACTS.md
- docs/RPC-SPECS.md
- docs/QA-SCENARIOS.md
- docs/TESTING-STRATEGY.md
- docs/RLS-POLICY.md
- docs/SCHEMA-MIGRATIONS.md
- docs/HOWTO/local-setup.md

## P0 drift fixes included
- profiles join 규약: profiles.user_id로 통일 (playbooks/rpc-public, playbooks/moderation)
- app_config whitelist: popular_feed 포함 (playbooks/ops-app-config) + D-056 정합
- payload_version_rollups: unknown_count 집계 추가 (playbooks/payload-version-kpi)
- moderation write RPC: guard_terms_agreed -> guard_block -> soft_state/visibility, 실패 not_found 통일 (playbooks/moderation)
- public house summary: jsonb 고정 shape + 8 슬롯 안정 반환 (playbooks/rpc-public)
- cats 아바타 누출 방지: avatar_key/avatar_url 모두 금지로 문서/검증 정합
- Transport Adapter 매핑: invalid_request(400) 포함 (docs/API.md)

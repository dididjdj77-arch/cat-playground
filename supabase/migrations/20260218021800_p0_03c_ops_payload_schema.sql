begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create table if not exists public.ops_metrics (
  id uuid primary key default gen_random_uuid(),
  ts timestamptz not null default now(),
  metric_key text not null,
  metric_value_num numeric,
  metric_value_text text,
  meta jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_ops_metrics_metric_key_ts
  on public.ops_metrics (metric_key, ts desc);

create table if not exists public.payload_versions (
  version text primary key,
  state text not null,
  meta jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payload_versions_state_chk
    check (state in ('ACTIVE', 'DEPRECATED', 'REJECT'))
);

create table if not exists public.payload_version_events (
  id uuid primary key default gen_random_uuid(),
  ts timestamptz not null default now(),
  version text not null,
  event_type text not null,
  request_id uuid,
  reason text,
  created_at timestamptz not null default now(),
  constraint payload_version_events_event_type_chk
    check (event_type in ('seen', 'reject', 'normalize_fail', 'unknown'))
);

create index if not exists idx_payload_version_events_version_ts
  on public.payload_version_events (version, ts desc);

create index if not exists idx_payload_version_events_ts
  on public.payload_version_events (ts desc);

create table if not exists public.payload_version_rollups (
  version text not null,
  bucket_ts timestamptz not null,
  seen_count bigint not null default 0,
  reject_count bigint not null default 0,
  normalize_fail_count bigint not null default 0,
  unknown_count bigint not null default 0,
  last_seen_at timestamptz,
  primary key (version, bucket_ts),
  constraint payload_version_rollups_seen_count_chk check (seen_count >= 0),
  constraint payload_version_rollups_reject_count_chk check (reject_count >= 0),
  constraint payload_version_rollups_normalize_fail_count_chk check (normalize_fail_count >= 0),
  constraint payload_version_rollups_unknown_count_chk check (unknown_count >= 0)
);

create index if not exists idx_payload_version_rollups_bucket_ts
  on public.payload_version_rollups (bucket_ts desc);

commit;

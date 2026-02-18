begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(user_id)
);

revoke all on table public.app_config from public;
revoke all on table public.app_config from anon, authenticated;

create or replace function public.rpc_get_app_config(p_keys text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'auth required';
  end if;

  with requested as (
    select distinct unnest(coalesce(p_keys, array[]::text[])) as key
  ),
  allowed as (
    select key
    from requested
    where key in ('rate_limits', 'rate_limits_new_account', 'auto_hide', 'popular_feed')
  )
  select coalesce(jsonb_object_agg(c.key, c.value), '{}'::jsonb)
    into v_result
  from public.app_config c
  join allowed a on a.key = c.key;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_app_config(text[]) from public;
grant execute on function public.rpc_get_app_config(text[]) to authenticated;

insert into public.app_config (key, value)
values
  (
    'rate_limits',
    '{"posts":{"per_min":2,"per_day":20},"comments/replies":{"per_min":10,"per_day":200},"likes":{"per_min":60,"per_day":1500},"reports":{"per_min":3,"per_day":30}}'::jsonb
  ),
  (
    'rate_limits_new_account',
    '{"posts":{"per_min":1,"per_day":5},"comments/replies":{"per_min":5,"per_day":50},"likes":{"per_min":30,"per_day":500},"reports":{"per_min":2,"per_day":10}}'::jsonb
  ),
  (
    'auto_hide',
    '{"threshold_n":5,"window_hours":24,"trust_days":7}'::jsonb
  ),
  (
    'popular_feed',
    '{"like_weight":1,"reply_weight":2,"window_days":7}'::jsonb
  )
on conflict (key) do update
set value = excluded.value,
    updated_at = now(),
    updated_by = null;

commit;

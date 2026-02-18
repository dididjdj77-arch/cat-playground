begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.guard_terms_agreed()
returns jsonb
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select
    case
      when auth.uid() is not null
        and exists (
          select 1
          from public.profiles p
          where p.user_id = auth.uid()
            and p.terms_agreed_at is not null
        )
      then null::jsonb
      else jsonb_build_object('error_code', 'terms_not_agreed')
    end;
$$;

create or replace function public.guard_block(
  p_viewer_id uuid,
  p_target_user_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select
    case
      when p_viewer_id is null then true
      when p_target_user_id is null then true
      else not exists (
        select 1
        from public.blocks b
        where (b.blocker_id = p_viewer_id and b.blocked_id = p_target_user_id)
           or (b.blocker_id = p_target_user_id and b.blocked_id = p_viewer_id)
      )
    end;
$$;

create or replace function public.guard_soft_state(
  p_deleted_at timestamptz,
  p_hidden_at timestamptz
)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select p_deleted_at is null and p_hidden_at is null;
$$;

create or replace function public.guard_visibility_published(
  p_visibility text,
  p_published_at timestamptz
)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select p_visibility = 'public' and p_published_at is not null;
$$;

-- guard 함수는 RPC 내부에서만 호출됨 — 외부 EXECUTE 차단
revoke all on function public.guard_terms_agreed() from public, anon, authenticated, service_role;
revoke all on function public.guard_block(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.guard_soft_state(timestamptz, timestamptz) from public, anon, authenticated, service_role;
revoke all on function public.guard_visibility_published(text, timestamptz) from public, anon, authenticated, service_role;

commit;

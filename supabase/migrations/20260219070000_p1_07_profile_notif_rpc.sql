begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_agree_terms()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_terms_agreed_at timestamptz;
begin
  -- D-097 pre-terms 예외: guard_terms_agreed 생략
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  update public.profiles p
  set terms_agreed_at = coalesce(p.terms_agreed_at, now()),
      updated_at = now()
  where p.user_id = v_user_id
  returning p.terms_agreed_at
  into v_terms_agreed_at;

  if v_terms_agreed_at is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return jsonb_build_object('terms_agreed_at', v_terms_agreed_at);
end;
$$;

create or replace function public.rpc_set_initial_nickname(
  p_nickname text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_nickname text := btrim(coalesce(p_nickname, ''));
  v_nickname_applied text;
begin
  -- D-097 pre-terms 예외: guard_terms_agreed 생략
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  if char_length(v_nickname) < 2 or char_length(v_nickname) > 20 then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'nickname_length_out_of_range');
  end if;

  -- 온보딩 최초 설정 1회만 허용
  update public.profiles p
  set nickname = v_nickname,
      nickname_changed_at = now(),
      updated_at = now()
  where p.user_id = v_user_id
    and p.nickname_changed_at is null
  returning p.nickname
  into v_nickname_applied;

  if v_nickname_applied is null then
    if exists (
      select 1
      from public.profiles p
      where p.user_id = v_user_id
    ) then
      return jsonb_build_object('error_code', 'invalid_request', 'message', 'nickname_already_initialized');
    end if;

    return jsonb_build_object('error_code', 'not_found');
  end if;

  return jsonb_build_object('nickname', v_nickname_applied);
exception
  when unique_violation then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'nickname_taken');
  when check_violation then
    return jsonb_build_object('error_code', 'invalid_request');
end;
$$;

create or replace function public.rpc_update_profile(
  p_nickname text default null,
  p_bio text default null,
  p_avatar_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_terms_guard jsonb;
  v_deleted_at timestamptz;
  v_avatar_key text := case
    when p_avatar_key is null then null
    else nullif(btrim(p_avatar_key), '')
  end;
  v_profile jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-096 #1 terms
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  -- D-096 #2 block (N/A: 자기 프로필)
  -- no-op

  -- D-096 #3 soft_state
  select p.deleted_at
  into v_deleted_at
  from public.profiles p
  where p.user_id = v_user_id;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_deleted_at, null) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- D-096 #4 domain
  -- D-051: p_nickname silently ignored (reference to suppress lint)
  perform p_nickname;
  if v_avatar_key is not null and (
    v_avatar_key like '/%'
    or position('..' in v_avatar_key) > 0
    or position('://' in v_avatar_key) > 0
    or v_avatar_key !~ '^[A-Za-z0-9][A-Za-z0-9/_\.-]*$'
  ) then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'invalid_avatar_key');
  end if;

  update public.profiles p
  set bio = coalesce(p_bio, p.bio),
      avatar_key = case
        when p_avatar_key is null then p.avatar_key
        else v_avatar_key
      end,
      updated_at = now()
  where p.user_id = v_user_id
  returning jsonb_build_object(
    'user_id', p.user_id,
    'nickname', p.nickname,
    'bio', p.bio,
    'avatar_key', p.avatar_key,
    'terms_agreed_at', p.terms_agreed_at,
    'created_at', p.created_at,
    'updated_at', p.updated_at
  )
  into v_profile;

  return jsonb_build_object('profile', v_profile);
exception
  when check_violation then
    return jsonb_build_object('error_code', 'invalid_request');
end;
$$;

create or replace function public.rpc_get_notifications(
  p_cursor text default null,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_cursor_created_at timestamptz;
  v_cursor_id uuid;
  v_notifications jsonb;
  v_next_created_at timestamptz;
  v_next_id uuid;
begin
  -- D-073: read RPC는 guard_terms_agreed 미적용
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  if p_cursor is not null and btrim(p_cursor) <> '' then
    begin
      v_cursor_created_at := split_part(p_cursor, '|', 1)::timestamptz;
      if nullif(split_part(p_cursor, '|', 2), '') is not null then
        v_cursor_id := split_part(p_cursor, '|', 2)::uuid;
      end if;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request', 'message', 'invalid_cursor');
    end;
  end if;

  with raw_page as (
    select
      n.id,
      n.type,
      n.actor_id,
      n.target_type,
      n.target_id,
      n.read_at,
      n.created_at
    from public.notifications n
    where n.user_id = v_user_id
      and (
        v_cursor_created_at is null
        or n.created_at < v_cursor_created_at
        or (v_cursor_id is not null and n.created_at = v_cursor_created_at and n.id < v_cursor_id)
      )
    order by n.created_at desc, n.id desc
    limit v_limit + 1
  ),
  page as (
    select *
    from raw_page
    order by created_at desc, id desc
    limit v_limit
  ),
  next_row as (
    select r.created_at, r.id
    from raw_page r
    order by r.created_at desc, r.id desc
    offset v_limit
    limit 1
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'type', p.type,
          'actor_id', p.actor_id,
          'target_type', p.target_type,
          'target_id', p.target_id,
          'read_at', p.read_at,
          'created_at', p.created_at
        )
        order by p.created_at desc, p.id desc
      ),
      '[]'::jsonb
    ),
    nr.created_at,
    nr.id
  into v_notifications, v_next_created_at, v_next_id
  from page p
  left join next_row nr on true
  group by nr.created_at, nr.id;

  return jsonb_build_object(
    'notifications', coalesce(v_notifications, '[]'::jsonb),
    'next_cursor', case
      when v_next_created_at is null then null
      else to_char(v_next_created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') || '|' || v_next_id::text
    end
  );
end;
$$;

create or replace function public.rpc_mark_notification_read(
  p_notification_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_terms_guard jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-073: write RPC guard_terms_agreed 적용
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  if p_notification_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  update public.notifications n
  set read_at = coalesce(n.read_at, now())
  where n.user_id = v_user_id
    and n.id = p_notification_id;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.rpc_mark_all_notifications_read()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_terms_guard jsonb;
  v_updated_count int := 0;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-073: write RPC guard_terms_agreed 적용
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  update public.notifications n
  set read_at = now()
  where n.user_id = v_user_id
    and n.read_at is null;

  get diagnostics v_updated_count = row_count;

  return jsonb_build_object('updated_count', v_updated_count);
end;
$$;

revoke all on function public.rpc_agree_terms() from public;
revoke all on function public.rpc_agree_terms() from anon;
revoke all on function public.rpc_agree_terms() from service_role;
grant execute on function public.rpc_agree_terms() to authenticated;

revoke all on function public.rpc_set_initial_nickname(text) from public;
revoke all on function public.rpc_set_initial_nickname(text) from anon;
revoke all on function public.rpc_set_initial_nickname(text) from service_role;
grant execute on function public.rpc_set_initial_nickname(text) to authenticated;

revoke all on function public.rpc_update_profile(text, text, text) from public;
revoke all on function public.rpc_update_profile(text, text, text) from anon;
revoke all on function public.rpc_update_profile(text, text, text) from service_role;
grant execute on function public.rpc_update_profile(text, text, text) to authenticated;

revoke all on function public.rpc_get_notifications(text, int) from public;
revoke all on function public.rpc_get_notifications(text, int) from anon;
revoke all on function public.rpc_get_notifications(text, int) from service_role;
grant execute on function public.rpc_get_notifications(text, int) to authenticated;

revoke all on function public.rpc_mark_notification_read(uuid) from public;
revoke all on function public.rpc_mark_notification_read(uuid) from anon;
revoke all on function public.rpc_mark_notification_read(uuid) from service_role;
grant execute on function public.rpc_mark_notification_read(uuid) to authenticated;

revoke all on function public.rpc_mark_all_notifications_read() from public;
revoke all on function public.rpc_mark_all_notifications_read() from anon;
revoke all on function public.rpc_mark_all_notifications_read() from service_role;
grant execute on function public.rpc_mark_all_notifications_read() to authenticated;

commit;

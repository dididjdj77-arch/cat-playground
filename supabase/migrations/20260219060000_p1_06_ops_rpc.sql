begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.check_auto_hide(
  p_target_type text,
  p_target_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target_type text := lower(coalesce(p_target_type, ''));
  v_config jsonb;
  v_threshold int;
  v_window_hours int;
  v_trust_days int;
  v_report_count int;
  v_hidden_applied boolean := false;
begin
  if p_target_id is null then
    return;
  end if;

  if v_target_type not in ('post', 'comment', 'thread', 'reply') then
    return;
  end if;

  select c.value
    into v_config
  from public.app_config c
  where c.key = 'auto_hide';

  if v_config is null then
    return;
  end if;

  v_threshold := coalesce((v_config->>'threshold_n')::int, 0);
  v_window_hours := coalesce((v_config->>'window_hours')::int, 0);
  v_trust_days := coalesce((v_config->>'trust_days')::int, 0);

  if v_threshold <= 0 or v_window_hours <= 0 then
    return;
  end if;

  select count(distinct r.reporter_id)
    into v_report_count
  from public.reports r
  join public.profiles pr
    on pr.user_id = r.reporter_id
  where r.target_type = v_target_type
    and r.target_id = p_target_id
    and r.deleted_at is null
    and r.created_at >= now() - make_interval(hours => v_window_hours)
    and pr.created_at <= now() - make_interval(days => v_trust_days);

  if v_report_count < v_threshold then
    return;
  end if;

  if v_target_type = 'post' then
    update public.posts p
    set hidden_at = now(),
        updated_at = now()
    where p.id = p_target_id
      and p.deleted_at is null
      and p.hidden_at is null
    returning true into v_hidden_applied;
  elsif v_target_type = 'comment' then
    update public.comments c
    set hidden_at = now(),
        updated_at = now()
    where c.id = p_target_id
      and c.deleted_at is null
      and c.hidden_at is null
    returning true into v_hidden_applied;
  elsif v_target_type = 'thread' then
    update public.threads t
    set hidden_at = now(),
        updated_at = now()
    where t.id = p_target_id
      and t.deleted_at is null
      and t.hidden_at is null
    returning true into v_hidden_applied;
  else
    update public.replies r
    set hidden_at = now(),
        updated_at = now()
    where r.id = p_target_id
      and r.deleted_at is null
      and r.hidden_at is null
    returning true into v_hidden_applied;
  end if;

  if not coalesce(v_hidden_applied, false) then
    return;
  end if;

  insert into public.moderation_actions (
    actor_id,
    action,
    target_type,
    target_id,
    meta,
    created_at
  )
  values (
    null,
    'auto_hide',
    v_target_type,
    p_target_id,
    jsonb_build_object(
      'report_count', v_report_count,
      'threshold_n', v_threshold,
      'window_hours', v_window_hours,
      'trust_days', v_trust_days
    ),
    now()
  );
end;
$$;

create or replace function public.rpc_report_content(
  p_target_type text,
  p_target_id uuid,
  p_reason_code text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_reporter_id uuid := auth.uid();
  v_guard jsonb;
  v_target_type text := lower(coalesce(p_target_type, ''));
  v_reason_code text := lower(coalesce(p_reason_code, ''));
  v_target_author_id uuid;
  v_target_deleted_at timestamptz;
  v_target_hidden_at timestamptz;
  v_parent_deleted_at timestamptz;
  v_parent_hidden_at timestamptz;
  v_parent_visibility text;
  v_parent_published_at timestamptz;
  v_snapshot jsonb;
  v_report_id uuid;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_target_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_target_type not in ('post', 'comment', 'thread', 'reply') then
    return jsonb_build_object('error_code', 'invalid_target_type');
  end if;

  if v_reason_code not in ('spam', 'harassment', 'inappropriate', 'copyright', 'other') then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_target_type = 'post' then
    select p.author_id,
           p.deleted_at,
           p.hidden_at,
           p.visibility,
           p.published_at,
           to_jsonb(p.*)
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_parent_visibility,
           v_parent_published_at,
           v_snapshot
    from public.posts p
    where p.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_block(v_reporter_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_visibility_published(v_parent_visibility, v_parent_published_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  elsif v_target_type = 'comment' then
    select c.author_id,
           c.deleted_at,
           c.hidden_at,
           p.deleted_at,
           p.hidden_at,
           p.visibility,
           p.published_at,
           to_jsonb(c.*)
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_parent_deleted_at,
           v_parent_hidden_at,
           v_parent_visibility,
           v_parent_published_at,
           v_snapshot
    from public.comments c
    join public.posts p
      on p.id = c.post_id
    where c.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_block(v_reporter_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_parent_deleted_at, v_parent_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_visibility_published(v_parent_visibility, v_parent_published_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  elsif v_target_type = 'thread' then
    select t.author_id,
           t.deleted_at,
           t.hidden_at,
           to_jsonb(t.*)
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_snapshot
    from public.threads t
    where t.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_block(v_reporter_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  else
    select r.author_id,
           r.deleted_at,
           r.hidden_at,
           t.deleted_at,
           t.hidden_at,
           to_jsonb(r.*)
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_parent_deleted_at,
           v_parent_hidden_at,
           v_snapshot
    from public.replies r
    join public.threads t
      on t.id = r.thread_id
    where r.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_block(v_reporter_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;

    if not public.guard_soft_state(v_parent_deleted_at, v_parent_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  end if;

  insert into public.reports (
    reporter_id,
    target_type,
    target_id,
    reason_code,
    note,
    snapshot,
    created_at,
    deleted_at
  )
  values (
    v_reporter_id,
    v_target_type,
    p_target_id,
    v_reason_code,
    p_note,
    v_snapshot,
    now(),
    null
  )
  on conflict (reporter_id, target_type, target_id) where deleted_at is null
  do nothing
  returning id into v_report_id;

  if v_report_id is null then
    return jsonb_build_object('error_code', 'duplicate_report');
  end if;

  insert into public.moderation_actions (
    actor_id,
    action,
    target_type,
    target_id,
    meta,
    created_at
  )
  values (
    v_reporter_id,
    'report',
    v_target_type,
    p_target_id,
    jsonb_build_object('report_id', v_report_id),
    now()
  );

  perform public.check_auto_hide(v_target_type, p_target_id);

  return jsonb_build_object('report_id', v_report_id);
end;
$$;

create or replace function public.rpc_block_user(
  p_blocked_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_blocked_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_user_id = p_blocked_user_id then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.user_id = p_blocked_user_id
  ) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.blocks (
    blocker_id,
    blocked_id,
    created_at
  )
  values (
    v_user_id,
    p_blocked_user_id,
    now()
  )
  on conflict (blocker_id, blocked_id)
  do nothing;

  insert into public.moderation_actions (
    actor_id,
    action,
    target_type,
    target_id,
    created_at
  )
  values (
    v_user_id,
    'block',
    'user',
    p_blocked_user_id,
    now()
  );

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.rpc_unblock_user(
  p_blocked_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_blocked_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_user_id = p_blocked_user_id then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  delete from public.blocks b
  where b.blocker_id = v_user_id
    and b.blocked_id = p_blocked_user_id;

  insert into public.moderation_actions (
    actor_id,
    action,
    target_type,
    target_id,
    created_at
  )
  values (
    v_user_id,
    'unblock',
    'user',
    p_blocked_user_id,
    now()
  );

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.rpc_unhide_content(
  p_target_type text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_guard jsonb;
  v_target_type text := lower(coalesce(p_target_type, ''));
  v_is_admin boolean := false;
  v_target_deleted_at timestamptz;
  v_reports_soft_deleted int := 0;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_target_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_target_type not in ('post', 'comment', 'thread', 'reply') then
    return jsonb_build_object('error_code', 'invalid_target_type');
  end if;

  select coalesce(p.is_admin, false)
    into v_is_admin
  from public.profiles p
  where p.user_id = v_actor_id;

  if not v_is_admin then
    return jsonb_build_object('error_code', 'forbidden');
  end if;

  if v_target_type = 'post' then
    select p.deleted_at
      into v_target_deleted_at
    from public.posts p
    where p.id = p_target_id
    for update;
  elsif v_target_type = 'comment' then
    select c.deleted_at
      into v_target_deleted_at
    from public.comments c
    where c.id = p_target_id
    for update;
  elsif v_target_type = 'thread' then
    select t.deleted_at
      into v_target_deleted_at
    from public.threads t
    where t.id = p_target_id
    for update;
  else
    select r.deleted_at
      into v_target_deleted_at
    from public.replies r
    where r.id = p_target_id
    for update;
  end if;

  if v_target_deleted_at is not null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_target_type = 'post' then
    update public.posts p
    set hidden_at = null,
        updated_at = now()
    where p.id = p_target_id
      and p.deleted_at is null;
  elsif v_target_type = 'comment' then
    update public.comments c
    set hidden_at = null,
        updated_at = now()
    where c.id = p_target_id
      and c.deleted_at is null;
  elsif v_target_type = 'thread' then
    update public.threads t
    set hidden_at = null,
        updated_at = now()
    where t.id = p_target_id
      and t.deleted_at is null;
  else
    update public.replies r
    set hidden_at = null,
        updated_at = now()
    where r.id = p_target_id
      and r.deleted_at is null;
  end if;

  update public.reports r
  set deleted_at = now()
  where r.target_type = v_target_type
    and r.target_id = p_target_id
    and r.deleted_at is null;

  get diagnostics v_reports_soft_deleted = row_count;

  insert into public.moderation_actions (
    actor_id,
    action,
    target_type,
    target_id,
    meta,
    created_at
  )
  values (
    v_actor_id,
    'unhide',
    v_target_type,
    p_target_id,
    jsonb_build_object('reports_soft_deleted', v_reports_soft_deleted),
    now()
  );

  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.check_auto_hide(text, uuid) from public, anon, authenticated, service_role;

revoke all on function public.rpc_report_content(text, uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_block_user(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_unblock_user(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_unhide_content(text, uuid) from public, anon, authenticated, service_role;

grant execute on function public.rpc_report_content(text, uuid, text, text) to authenticated;
grant execute on function public.rpc_block_user(uuid) to authenticated;
grant execute on function public.rpc_unblock_user(uuid) to authenticated;
grant execute on function public.rpc_unhide_content(text, uuid) to authenticated;

commit;

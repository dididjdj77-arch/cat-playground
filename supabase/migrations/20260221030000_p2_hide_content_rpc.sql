begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_hide_content(
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
  v_target_hidden_at timestamptz;
begin
  -- D-096 #1: guard_terms_agreed (rpc_unhide_content과 일관)
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

  -- admin 체크 (D-068)
  select coalesce(p.is_admin, false)
    into v_is_admin
  from public.profiles p
  where p.user_id = v_actor_id;

  if not v_is_admin then
    return jsonb_build_object('error_code', 'forbidden');
  end if;

  -- 대상 조회 + FOR UPDATE
  if v_target_type = 'post' then
    select p.deleted_at, p.hidden_at
      into v_target_deleted_at, v_target_hidden_at
    from public.posts p
    where p.id = p_target_id
    for update;
  elsif v_target_type = 'comment' then
    select c.deleted_at, c.hidden_at
      into v_target_deleted_at, v_target_hidden_at
    from public.comments c
    where c.id = p_target_id
    for update;
  elsif v_target_type = 'thread' then
    select t.deleted_at, t.hidden_at
      into v_target_deleted_at, v_target_hidden_at
    from public.threads t
    where t.id = p_target_id
    for update;
  else
    select r.deleted_at, r.hidden_at
      into v_target_deleted_at, v_target_hidden_at
    from public.replies r
    where r.id = p_target_id
    for update;
  end if;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_target_deleted_at is not null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- 이미 hidden이면 멱등 성공 (hidden_at 갱신 안 함, 감사로그만 기록)
  if v_target_hidden_at is not null then
    insert into public.moderation_actions (
      actor_id, action, target_type, target_id, meta, created_at
    ) values (
      v_actor_id, 'hide', v_target_type, p_target_id,
      jsonb_build_object('idempotent', true),
      now()
    );
    return jsonb_build_object('success', true);
  end if;

  -- hidden_at 설정
  if v_target_type = 'post' then
    update public.posts p
    set hidden_at = now(), updated_at = now()
    where p.id = p_target_id and p.deleted_at is null;
  elsif v_target_type = 'comment' then
    update public.comments c
    set hidden_at = now(), updated_at = now()
    where c.id = p_target_id and c.deleted_at is null;
  elsif v_target_type = 'thread' then
    update public.threads t
    set hidden_at = now(), updated_at = now()
    where t.id = p_target_id and t.deleted_at is null;
  else
    update public.replies r
    set hidden_at = now(), updated_at = now()
    where r.id = p_target_id and r.deleted_at is null;
  end if;

  -- 감사 로그 (reports는 건드리지 않음 — unhide와 차이점)
  insert into public.moderation_actions (
    actor_id, action, target_type, target_id, created_at
  ) values (
    v_actor_id, 'hide', v_target_type, p_target_id, now()
  );

  return jsonb_build_object('success', true);
end;
$$;

-- GRANT: authenticated only (admin 체크는 함수 내부)
revoke all on function public.rpc_hide_content(text, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.rpc_hide_content(text, uuid) to authenticated;

commit;

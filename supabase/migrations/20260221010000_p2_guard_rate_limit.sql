begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- guard_rate_limit: 공통 레이트리밋 헬퍼 (D-053)
-- 반환: null(통과) 또는 {"error_code":"rate_limited"}
create or replace function public.guard_rate_limit(
  p_action_key text
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_bucket_key text;
  v_is_new_account boolean;
  v_limits jsonb;
  v_per_minute int;
  v_per_day int;
  v_count_minute int;
  v_count_day int;
begin
  -- 1) action_key → bucket_key 매핑
  v_bucket_key := case p_action_key
    when 'rpc_create_post' then 'posts'
    when 'rpc_create_thread' then 'posts'
    when 'rpc_create_comment' then 'comments/replies'
    when 'rpc_create_reply' then 'comments/replies'
    when 'rpc_toggle_like' then 'likes'
    when 'rpc_report_content' then 'reports'
    else null
  end;

  if v_bucket_key is null then
    return null;
  end if;

  -- 2) 신규 계정 판정 (created_at이 24시간 이내)
  select p.created_at > now() - interval '24 hours'
    into v_is_new_account
  from public.profiles p
  where p.user_id = v_user_id;

  if v_is_new_account is null then
    return null;
  end if;

  -- 3) app_config에서 런타임 한도 조회 (D-056)
  select c.value -> v_bucket_key
    into v_limits
  from public.app_config c
  where c.key = case
    when v_is_new_account then 'rate_limits_new_account'
    else 'rate_limits'
  end;

  if v_limits is null then
    return null;
  end if;

  v_per_minute := coalesce((v_limits->>'per_minute')::int, 0);
  v_per_day    := coalesce((v_limits->>'per_day')::int, 0);

  -- 4) 카운트 소스: 각 테이블의 created_at 기준
  if v_bucket_key = 'posts' then
    select count(*) into v_count_minute
    from (
      select 1 from public.posts
        where author_id = v_user_id and created_at > now() - interval '1 minute'
      union all
      select 1 from public.threads
        where author_id = v_user_id and created_at > now() - interval '1 minute'
    ) sub;
    select count(*) into v_count_day
    from (
      select 1 from public.posts
        where author_id = v_user_id and created_at > now() - interval '1 day'
      union all
      select 1 from public.threads
        where author_id = v_user_id and created_at > now() - interval '1 day'
    ) sub;

  elsif v_bucket_key = 'comments/replies' then
    select count(*) into v_count_minute
    from (
      select 1 from public.comments
        where author_id = v_user_id and created_at > now() - interval '1 minute'
      union all
      select 1 from public.replies
        where author_id = v_user_id and created_at > now() - interval '1 minute'
    ) sub;
    select count(*) into v_count_day
    from (
      select 1 from public.comments
        where author_id = v_user_id and created_at > now() - interval '1 day'
      union all
      select 1 from public.replies
        where author_id = v_user_id and created_at > now() - interval '1 day'
    ) sub;

  elsif v_bucket_key = 'likes' then
    select count(*) into v_count_minute
    from public.likes
    where user_id = v_user_id and created_at > now() - interval '1 minute';
    select count(*) into v_count_day
    from public.likes
    where user_id = v_user_id and created_at > now() - interval '1 day';

  else -- 'reports'
    select count(*) into v_count_minute
    from public.reports
    where reporter_id = v_user_id and created_at > now() - interval '1 minute';
    select count(*) into v_count_day
    from public.reports
    where reporter_id = v_user_id and created_at > now() - interval '1 day';
  end if;

  -- 5) 윈도우 체크
  if v_per_minute > 0 and v_count_minute >= v_per_minute then
    return jsonb_build_object('error_code', 'rate_limited');
  end if;

  if v_per_day > 0 and v_count_day >= v_per_day then
    return jsonb_build_object('error_code', 'rate_limited');
  end if;

  return null;
end;
$$;

-- guard 함수: 외부 EXECUTE 차단 (내부 호출 전용)
revoke all on function public.guard_rate_limit(text)
  from public, anon, authenticated, service_role;

commit;

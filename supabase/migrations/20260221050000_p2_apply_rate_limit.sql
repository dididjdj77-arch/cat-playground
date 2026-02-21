begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- ============================================================
-- 기존 6개 write RPC에 guard_rate_limit 호출 삽입 (D-053)
-- 삽입 위치: guard_terms_agreed() 직후, 나머지 가드 이전
-- CREATE OR REPLACE로 기존 GRANT 유지
-- ============================================================

-- 1) rpc_create_post
create or replace function public.rpc_create_post(
  p_body text,
  p_log_date date,
  p_visibility text,
  p_hide_from_profile bool default false,
  p_meta jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_post public.posts;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_create_post');
  if v_guard is not null then return v_guard; end if;

  if p_visibility not in ('private', 'public') then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_body is null or char_length(p_body) < 1 or char_length(p_body) > 5000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_log_date is null or p_log_date > current_date then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  insert into public.posts (
    author_id, body, log_date, visibility, published_at,
    hide_from_profile, meta, created_at, updated_at
  )
  values (
    v_user_id, p_body, p_log_date, p_visibility, null,
    coalesce(p_hide_from_profile, false),
    coalesce(p_meta, '{}'::jsonb),
    now(), now()
  )
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

-- 2) rpc_create_comment
create or replace function public.rpc_create_comment(
  p_post_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_post public.posts;
  v_comment public.comments;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_create_comment');
  if v_guard is not null then return v_guard; end if;

  select *
    into v_post
  from public.posts p
  where p.id = p_post_id;

  if v_post.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_block(v_user_id, v_post.author_id) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post.deleted_at, v_post.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_visibility_published(v_post.visibility, v_post.published_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if p_body is null or char_length(p_body) < 1 or char_length(p_body) > 2000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  insert into public.comments (
    post_id, author_id, body, created_at, updated_at
  )
  values (
    p_post_id, v_user_id, p_body, now(), now()
  )
  returning * into v_comment;

  update public.posts p
  set comment_count = p.comment_count + 1,
      updated_at = now()
  where p.id = p_post_id;

  if v_post.author_id <> v_user_id then
    insert into public.notifications (
      user_id, type, actor_id, target_type, target_id, created_at
    )
    values (
      v_post.author_id, 'comment', v_user_id, 'post', p_post_id, now()
    );
  end if;

  return jsonb_build_object('comment', to_jsonb(v_comment));
end;
$$;

-- 3) rpc_toggle_like
create or replace function public.rpc_toggle_like(
  p_target_type text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_target_type text := lower(coalesce(p_target_type, ''));
  v_target_author_id uuid;
  v_parent_author_id uuid;
  v_target_deleted_at timestamptz;
  v_target_hidden_at timestamptz;
  v_parent_deleted_at timestamptz;
  v_parent_hidden_at timestamptz;
  v_target_visibility text;
  v_target_published_at timestamptz;
  v_like_id uuid;
  v_like_count int;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_toggle_like');
  if v_guard is not null then return v_guard; end if;

  if p_target_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_target_type not in ('post', 'comment', 'thread', 'reply') then
    return jsonb_build_object('error_code', 'invalid_target_type');
  end if;

  if v_target_type = 'post' then
    select p.author_id, p.deleted_at, p.hidden_at, p.visibility, p.published_at
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_target_visibility, v_target_published_at
    from public.posts p where p.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_visibility_published(v_target_visibility, v_target_published_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  elsif v_target_type = 'comment' then
    select c.author_id, c.deleted_at, c.hidden_at,
           p.author_id, p.deleted_at, p.hidden_at, p.visibility, p.published_at
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_parent_author_id, v_parent_deleted_at, v_parent_hidden_at,
           v_target_visibility, v_target_published_at
    from public.comments c
    join public.posts p on p.id = c.post_id
    where c.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_parent_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_parent_deleted_at, v_parent_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_visibility_published(v_target_visibility, v_target_published_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  elsif v_target_type = 'thread' then
    select t.author_id, t.deleted_at, t.hidden_at
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at
    from public.threads t where t.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  else
    select r.author_id, r.deleted_at, r.hidden_at,
           t.author_id, t.deleted_at, t.hidden_at
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_parent_author_id, v_parent_deleted_at, v_parent_hidden_at
    from public.replies r
    join public.threads t on t.id = r.thread_id
    where r.id = p_target_id;

    if v_target_author_id is null then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_target_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_block(v_user_id, v_parent_author_id) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_target_deleted_at, v_target_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
    if not public.guard_soft_state(v_parent_deleted_at, v_parent_hidden_at) then
      return jsonb_build_object('error_code', 'not_found');
    end if;
  end if;

  select l.id
    into v_like_id
  from public.likes l
  where l.user_id = v_user_id
    and l.target_type = v_target_type
    and l.target_id = p_target_id;

  if v_like_id is not null then
    delete from public.likes l where l.id = v_like_id;

    if v_target_type = 'post' then
      update public.posts p set like_count = greatest(p.like_count - 1, 0), updated_at = now()
      where p.id = p_target_id returning p.like_count into v_like_count;
    elsif v_target_type = 'comment' then
      update public.comments c set like_count = greatest(c.like_count - 1, 0), updated_at = now()
      where c.id = p_target_id returning c.like_count into v_like_count;
    elsif v_target_type = 'thread' then
      update public.threads t set like_count = greatest(t.like_count - 1, 0), updated_at = now()
      where t.id = p_target_id returning t.like_count into v_like_count;
    else
      update public.replies r set like_count = greatest(r.like_count - 1, 0), updated_at = now()
      where r.id = p_target_id returning r.like_count into v_like_count;
    end if;

    return jsonb_build_object(
      'target_type', v_target_type, 'target_id', p_target_id,
      'liked', false, 'like_count', coalesce(v_like_count, 0)
    );
  end if;

  insert into public.likes (user_id, target_type, target_id, created_at)
  values (v_user_id, v_target_type, p_target_id, now());

  if v_target_type = 'post' then
    update public.posts p set like_count = p.like_count + 1, updated_at = now()
    where p.id = p_target_id returning p.like_count into v_like_count;
  elsif v_target_type = 'comment' then
    update public.comments c set like_count = c.like_count + 1, updated_at = now()
    where c.id = p_target_id returning c.like_count into v_like_count;
  elsif v_target_type = 'thread' then
    update public.threads t set like_count = t.like_count + 1, updated_at = now()
    where t.id = p_target_id returning t.like_count into v_like_count;
  else
    update public.replies r set like_count = r.like_count + 1, updated_at = now()
    where r.id = p_target_id returning r.like_count into v_like_count;
  end if;

  if v_target_type = 'post'
     and v_target_author_id is not null
     and v_target_author_id <> v_user_id then
    insert into public.notifications (
      user_id, type, actor_id, target_type, target_id, created_at
    )
    values (
      v_target_author_id, 'like', v_user_id, 'post', p_target_id, now()
    );
  end if;

  return jsonb_build_object(
    'target_type', v_target_type, 'target_id', p_target_id,
    'liked', true, 'like_count', coalesce(v_like_count, 0)
  );
end;
$$;

-- 4) rpc_create_thread
create or replace function public.rpc_create_thread(
  p_topic_id uuid,
  p_title text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_topic_id uuid;
  v_thread public.threads;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_create_thread');
  if v_guard is not null then return v_guard; end if;

  if p_topic_id is null
     or p_title is null
     or p_body is null
     or char_length(p_title) < 1
     or char_length(p_title) > 120
     or char_length(p_body) < 1
     or char_length(p_body) > 10000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select t.id
    into v_topic_id
  from public.topics t
  where t.id = p_topic_id
    and t.is_public = true
    and t.deleted_at is null;

  if v_topic_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.threads (
    topic_id, author_id, title, body, created_at, updated_at
  )
  values (
    p_topic_id, v_user_id, p_title, p_body, now(), now()
  )
  returning * into v_thread;

  return jsonb_build_object(
    'thread',
    jsonb_build_object(
      'id', v_thread.id,
      'topic_id', v_thread.topic_id,
      'author_id', v_thread.author_id,
      'title', v_thread.title,
      'body', v_thread.body,
      'like_count', v_thread.like_count,
      'reply_count', v_thread.reply_count,
      'created_at', v_thread.created_at,
      'updated_at', v_thread.updated_at
    )
  );
end;
$$;

-- 5) rpc_create_reply
create or replace function public.rpc_create_reply(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_thread public.threads;
  v_reply public.replies;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_create_reply');
  if v_guard is not null then return v_guard; end if;

  if p_thread_id is null
     or p_body is null
     or char_length(p_body) < 1
     or char_length(p_body) > 5000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select *
    into v_thread
  from public.threads t
  where t.id = p_thread_id
  for update;

  if v_thread.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_block(v_user_id, v_thread.author_id) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_thread.deleted_at, v_thread.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.replies (
    thread_id, author_id, body, created_at, updated_at
  )
  values (
    p_thread_id, v_user_id, p_body, now(), now()
  )
  returning * into v_reply;

  update public.threads t
  set reply_count = t.reply_count + 1,
      updated_at = now()
  where t.id = p_thread_id;

  if v_thread.author_id <> v_user_id
     and public.guard_block(v_user_id, v_thread.author_id) then
    insert into public.notifications (
      user_id, type, actor_id, target_type, target_id, created_at
    )
    values (
      v_thread.author_id, 'reply', v_user_id, 'thread', p_thread_id, now()
    );
  end if;

  return jsonb_build_object(
    'reply',
    jsonb_build_object(
      'id', v_reply.id,
      'thread_id', v_reply.thread_id,
      'author_id', v_reply.author_id,
      'body', v_reply.body,
      'like_count', v_reply.like_count,
      'edited_at', v_reply.edited_at,
      'created_at', v_reply.created_at,
      'updated_at', v_reply.updated_at
    )
  );
end;
$$;

-- 6) rpc_report_content
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
  if v_guard is not null then return v_guard; end if;

  -- D-053: rate limit
  v_guard := public.guard_rate_limit('rpc_report_content');
  if v_guard is not null then return v_guard; end if;

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
    select p.author_id, p.deleted_at, p.hidden_at, p.visibility, p.published_at, to_jsonb(p.*)
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_parent_visibility, v_parent_published_at, v_snapshot
    from public.posts p where p.id = p_target_id;

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
    select c.author_id, c.deleted_at, c.hidden_at,
           p.deleted_at, p.hidden_at, p.visibility, p.published_at, to_jsonb(c.*)
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_parent_deleted_at, v_parent_hidden_at, v_parent_visibility, v_parent_published_at,
           v_snapshot
    from public.comments c
    join public.posts p on p.id = c.post_id
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
    select t.author_id, t.deleted_at, t.hidden_at, to_jsonb(t.*)
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at, v_snapshot
    from public.threads t where t.id = p_target_id;

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
    select r.author_id, r.deleted_at, r.hidden_at,
           t.deleted_at, t.hidden_at, to_jsonb(r.*)
      into v_target_author_id, v_target_deleted_at, v_target_hidden_at,
           v_parent_deleted_at, v_parent_hidden_at, v_snapshot
    from public.replies r
    join public.threads t on t.id = r.thread_id
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
    reporter_id, target_type, target_id, reason_code, note, snapshot, created_at, deleted_at
  )
  values (
    v_reporter_id, v_target_type, p_target_id, v_reason_code, p_note, v_snapshot, now(), null
  )
  on conflict (reporter_id, target_type, target_id) where deleted_at is null
  do nothing
  returning id into v_report_id;

  if v_report_id is null then
    return jsonb_build_object('error_code', 'duplicate_report');
  end if;

  insert into public.moderation_actions (
    actor_id, action, target_type, target_id, meta, created_at
  )
  values (
    v_reporter_id, 'report', v_target_type, p_target_id,
    jsonb_build_object('report_id', v_report_id), now()
  );

  perform public.check_auto_hide(v_target_type, p_target_id);

  return jsonb_build_object('report_id', v_report_id);
end;
$$;

commit;

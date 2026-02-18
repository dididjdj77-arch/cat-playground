begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

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
  if v_guard is not null then
    return v_guard;
  end if;

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
    author_id,
    body,
    log_date,
    visibility,
    published_at,
    hide_from_profile,
    meta,
    created_at,
    updated_at
  )
  values (
    v_user_id,
    p_body,
    p_log_date,
    p_visibility,
    null,
    coalesce(p_hide_from_profile, false),
    coalesce(p_meta, '{}'::jsonb),
    now(),
    now()
  )
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

create or replace function public.rpc_update_post(
  p_post_id uuid,
  p_body text default null,
  p_visibility text default null,
  p_hide_from_profile bool default null,
  p_meta jsonb default null
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
  v_next_visibility text;
  v_next_published_at timestamptz;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  select *
    into v_post
  from public.posts p
  where p.id = p_post_id
  for update;

  if v_post.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post.deleted_at, v_post.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_post.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  v_next_visibility := coalesce(p_visibility, v_post.visibility);
  if v_next_visibility not in ('private', 'public') then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_body is not null and (char_length(p_body) < 1 or char_length(p_body) > 5000) then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  v_next_published_at := v_post.published_at;
  if v_next_visibility = 'private' then
    v_next_published_at := null;
  end if;

  update public.posts p
  set body = coalesce(p_body, p.body),
      visibility = v_next_visibility,
      published_at = v_next_published_at,
      hide_from_profile = coalesce(p_hide_from_profile, p.hide_from_profile),
      meta = coalesce(p_meta, p.meta),
      updated_at = now()
  where p.id = p_post_id
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

create or replace function public.rpc_delete_post(
  p_post_id uuid
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
  if v_guard is not null then
    return v_guard;
  end if;

  select *
    into v_post
  from public.posts p
  where p.id = p_post_id
  for update;

  if v_post.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post.deleted_at, v_post.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_post.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.posts p
  set deleted_at = now(),
      updated_at = now(),
      published_at = null
  where p.id = p_post_id
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

create or replace function public.rpc_publish_post(
  p_post_id uuid
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
  if v_guard is not null then
    return v_guard;
  end if;

  select *
    into v_post
  from public.posts p
  where p.id = p_post_id
  for update;

  if v_post.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post.deleted_at, v_post.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_post.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.posts p
  set visibility = 'public',
      published_at = now(),
      updated_at = now()
  where p.id = p_post_id
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

create or replace function public.rpc_unpublish_post(
  p_post_id uuid
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
  if v_guard is not null then
    return v_guard;
  end if;

  select *
    into v_post
  from public.posts p
  where p.id = p_post_id
  for update;

  if v_post.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post.deleted_at, v_post.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_post.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.posts p
  set published_at = null,
      updated_at = now()
  where p.id = p_post_id
  returning * into v_post;

  return jsonb_build_object('post', to_jsonb(v_post));
end;
$$;

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
  if v_guard is not null then
    return v_guard;
  end if;

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
    post_id,
    author_id,
    body,
    created_at,
    updated_at
  )
  values (
    p_post_id,
    v_user_id,
    p_body,
    now(),
    now()
  )
  returning * into v_comment;

  update public.posts p
  set comment_count = p.comment_count + 1,
      updated_at = now()
  where p.id = p_post_id;

  if v_post.author_id <> v_user_id then
    insert into public.notifications (
      user_id,
      type,
      actor_id,
      target_type,
      target_id,
      created_at
    )
    values (
      v_post.author_id,
      'comment',
      v_user_id,
      'post',
      p_post_id,
      now()
    );
  end if;

  return jsonb_build_object('comment', to_jsonb(v_comment));
end;
$$;

create or replace function public.rpc_update_comment(
  p_comment_id uuid,
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
  v_comment public.comments;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_body is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if char_length(p_body) < 1 or char_length(p_body) > 2000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select *
    into v_comment
  from public.comments c
  where c.id = p_comment_id
  for update;

  if v_comment.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_comment.deleted_at, v_comment.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_comment.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.comment_revisions (
    comment_id,
    previous_body,
    created_at
  )
  values (
    v_comment.id,
    v_comment.body,
    now()
  )
  on conflict (comment_id)
  do update
     set previous_body = excluded.previous_body,
         created_at = excluded.created_at;

  update public.comments c
  set body = p_body,
      edited_at = now(),
      updated_at = now()
  where c.id = p_comment_id
  returning * into v_comment;

  return jsonb_build_object('comment', to_jsonb(v_comment));
end;
$$;

create or replace function public.rpc_delete_comment(
  p_comment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_comment public.comments;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  select *
    into v_comment
  from public.comments c
  where c.id = p_comment_id
  for update;

  if v_comment.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_comment.deleted_at, v_comment.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_comment.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.comments c
  set deleted_at = now(),
      updated_at = now()
  where c.id = p_comment_id
  returning * into v_comment;

  update public.posts p
  set comment_count = greatest(p.comment_count - 1, 0),
      updated_at = now()
  where p.id = v_comment.post_id;

  return jsonb_build_object('comment', to_jsonb(v_comment));
end;
$$;

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
  if v_guard is not null then
    return v_guard;
  end if;

  if p_target_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if v_target_type not in ('post', 'comment', 'thread', 'reply') then
    return jsonb_build_object('error_code', 'invalid_target_type');
  end if;

  if v_target_type = 'post' then
    select p.author_id,
           p.deleted_at,
           p.hidden_at,
           p.visibility,
           p.published_at
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_target_visibility,
           v_target_published_at
    from public.posts p
    where p.id = p_target_id;

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
    select c.author_id,
           c.deleted_at,
           c.hidden_at,
           p.author_id,
           p.deleted_at,
           p.hidden_at,
           p.visibility,
           p.published_at
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_parent_author_id,
           v_parent_deleted_at,
           v_parent_hidden_at,
           v_target_visibility,
           v_target_published_at
    from public.comments c
    join public.posts p
      on p.id = c.post_id
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
    select t.author_id,
           t.deleted_at,
           t.hidden_at
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at
    from public.threads t
    where t.id = p_target_id;

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
    select r.author_id,
           r.deleted_at,
           r.hidden_at,
           t.author_id,
           t.deleted_at,
           t.hidden_at
      into v_target_author_id,
           v_target_deleted_at,
           v_target_hidden_at,
           v_parent_author_id,
           v_parent_deleted_at,
           v_parent_hidden_at
    from public.replies r
    join public.threads t
      on t.id = r.thread_id
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
    delete from public.likes l
    where l.id = v_like_id;

    if v_target_type = 'post' then
      update public.posts p
      set like_count = greatest(p.like_count - 1, 0),
          updated_at = now()
      where p.id = p_target_id
      returning p.like_count into v_like_count;
    elsif v_target_type = 'comment' then
      update public.comments c
      set like_count = greatest(c.like_count - 1, 0),
          updated_at = now()
      where c.id = p_target_id
      returning c.like_count into v_like_count;
    elsif v_target_type = 'thread' then
      update public.threads t
      set like_count = greatest(t.like_count - 1, 0),
          updated_at = now()
      where t.id = p_target_id
      returning t.like_count into v_like_count;
    else
      update public.replies r
      set like_count = greatest(r.like_count - 1, 0),
          updated_at = now()
      where r.id = p_target_id
      returning r.like_count into v_like_count;
    end if;

    return jsonb_build_object(
      'target_type', v_target_type,
      'target_id', p_target_id,
      'liked', false,
      'like_count', coalesce(v_like_count, 0)
    );
  end if;

  insert into public.likes (
    user_id,
    target_type,
    target_id,
    created_at
  )
  values (
    v_user_id,
    v_target_type,
    p_target_id,
    now()
  );

  if v_target_type = 'post' then
    update public.posts p
    set like_count = p.like_count + 1,
        updated_at = now()
    where p.id = p_target_id
    returning p.like_count into v_like_count;
  elsif v_target_type = 'comment' then
    update public.comments c
    set like_count = c.like_count + 1,
        updated_at = now()
    where c.id = p_target_id
    returning c.like_count into v_like_count;
  elsif v_target_type = 'thread' then
    update public.threads t
    set like_count = t.like_count + 1,
        updated_at = now()
    where t.id = p_target_id
    returning t.like_count into v_like_count;
  else
    update public.replies r
    set like_count = r.like_count + 1,
        updated_at = now()
    where r.id = p_target_id
    returning r.like_count into v_like_count;
  end if;

  if v_target_type = 'post'
     and v_target_author_id is not null
     and v_target_author_id <> v_user_id then
    insert into public.notifications (
      user_id,
      type,
      actor_id,
      target_type,
      target_id,
      created_at
    )
    values (
      v_target_author_id,
      'like',
      v_user_id,
      'post',
      p_target_id,
      now()
    );
  end if;

  return jsonb_build_object(
    'target_type', v_target_type,
    'target_id', p_target_id,
    'liked', true,
    'like_count', coalesce(v_like_count, 0)
  );
end;
$$;

create or replace function public.rpc_get_public_posts_feed(
  p_cursor text default null,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_cursor_ts timestamptz;
  v_result jsonb;
begin
  if p_cursor is not null then
    begin
      v_cursor_ts := p_cursor::timestamptz;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;
  end if;

  with feed as (
    select p.id,
           p.body,
           p.log_date,
           p.like_count,
           p.comment_count,
           p.published_at,
           p.created_at,
           pr.nickname as author_nickname
    from public.posts p
    join public.profiles pr
      on pr.user_id = p.author_id
    where public.guard_soft_state(p.deleted_at, p.hidden_at)
      and public.guard_visibility_published(p.visibility, p.published_at)
      and public.guard_block(v_viewer_id, p.author_id)
      and (v_cursor_ts is null or p.published_at < v_cursor_ts)
    order by p.published_at desc, p.id desc
    limit v_limit
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', feed.id,
               'body', feed.body,
               'log_date', feed.log_date,
               'like_count', feed.like_count,
               'comment_count', feed.comment_count,
               'published_at', feed.published_at,
               'created_at', feed.created_at,
               'author_nickname', feed.author_nickname
             )
             order by feed.published_at desc, feed.id desc
           ),
           '[]'::jsonb
         )
    into v_result
  from feed;

  return v_result;
end;
$$;

create or replace function public.rpc_get_public_post_detail(
  p_post_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_result jsonb;
begin
  select jsonb_build_object(
           'id', p.id,
           'body', p.body,
           'log_date', p.log_date,
           'like_count', p.like_count,
           'comment_count', p.comment_count,
           'published_at', p.published_at,
           'created_at', p.created_at,
           'author_nickname', pr.nickname
         )
    into v_result
  from public.posts p
  join public.profiles pr
    on pr.user_id = p.author_id
  where p.id = p_post_id
    and public.guard_soft_state(p.deleted_at, p.hidden_at)
    and public.guard_visibility_published(p.visibility, p.published_at)
    and public.guard_block(v_viewer_id, p.author_id);

  if v_result is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return v_result;
end;
$$;

create or replace function public.rpc_get_public_post_comments(
  p_post_id uuid,
  p_cursor text default null,
  p_limit int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_cursor_ts timestamptz;
  v_post_author_id uuid;
  v_post_deleted_at timestamptz;
  v_post_hidden_at timestamptz;
  v_post_visibility text;
  v_post_published_at timestamptz;
  v_result jsonb;
begin
  if p_cursor is not null then
    begin
      v_cursor_ts := p_cursor::timestamptz;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;
  end if;

  select p.author_id,
         p.deleted_at,
         p.hidden_at,
         p.visibility,
         p.published_at
    into v_post_author_id,
         v_post_deleted_at,
         v_post_hidden_at,
         v_post_visibility,
         v_post_published_at
  from public.posts p
  where p.id = p_post_id;

  if v_post_author_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_block(v_viewer_id, v_post_author_id) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_post_deleted_at, v_post_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_visibility_published(v_post_visibility, v_post_published_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  with comment_rows as (
    select c.id,
           c.body,
           c.like_count,
           c.edited_at,
           c.created_at,
           pr.nickname as author_nickname
    from public.comments c
    join public.profiles pr
      on pr.user_id = c.author_id
    where c.post_id = p_post_id
      and public.guard_soft_state(c.deleted_at, c.hidden_at)
      and public.guard_block(v_viewer_id, c.author_id)
      and (v_cursor_ts is null or c.created_at < v_cursor_ts)
    order by c.created_at desc, c.id desc
    limit v_limit
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', comment_rows.id,
               'body', comment_rows.body,
               'like_count', comment_rows.like_count,
               'edited_at', comment_rows.edited_at,
               'created_at', comment_rows.created_at,
               'author_nickname', comment_rows.author_nickname
             )
             order by comment_rows.created_at desc, comment_rows.id desc
           ),
           '[]'::jsonb
         )
    into v_result
  from comment_rows;

  return v_result;
end;
$$;

revoke all on function public.rpc_create_post(text, date, text, bool, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.rpc_update_post(uuid, text, text, bool, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.rpc_delete_post(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_publish_post(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_unpublish_post(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_create_comment(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_update_comment(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_delete_comment(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_toggle_like(text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_get_public_posts_feed(text, int) from public, anon, authenticated, service_role;
revoke all on function public.rpc_get_public_post_detail(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_get_public_post_comments(uuid, text, int) from public, anon, authenticated, service_role;

grant execute on function public.rpc_create_post(text, date, text, bool, jsonb) to authenticated;
grant execute on function public.rpc_update_post(uuid, text, text, bool, jsonb) to authenticated;
grant execute on function public.rpc_delete_post(uuid) to authenticated;
grant execute on function public.rpc_publish_post(uuid) to authenticated;
grant execute on function public.rpc_unpublish_post(uuid) to authenticated;
grant execute on function public.rpc_create_comment(uuid, text) to authenticated;
grant execute on function public.rpc_update_comment(uuid, text) to authenticated;
grant execute on function public.rpc_delete_comment(uuid) to authenticated;
grant execute on function public.rpc_toggle_like(text, uuid) to authenticated;

grant execute on function public.rpc_get_public_posts_feed(text, int) to anon;
grant execute on function public.rpc_get_public_posts_feed(text, int) to authenticated;
grant execute on function public.rpc_get_public_post_detail(uuid) to anon;
grant execute on function public.rpc_get_public_post_detail(uuid) to authenticated;
grant execute on function public.rpc_get_public_post_comments(uuid, text, int) to anon;
grant execute on function public.rpc_get_public_post_comments(uuid, text, int) to authenticated;

commit;

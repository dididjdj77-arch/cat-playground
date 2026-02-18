begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_list_topics()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_topics jsonb;
begin
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', t.id,
               'slug', t.slug,
               'name', t.name,
               'description', t.description,
               'is_public', t.is_public,
               'created_at', t.created_at,
               'updated_at', t.updated_at
             )
             order by t.name asc, t.id asc
           ),
           '[]'::jsonb
         )
    into v_topics
  from public.topics t
  where t.is_public = true
    and t.deleted_at is null;

  return jsonb_build_object('topics', v_topics);
end;
$$;

create or replace function public.rpc_follow_topic(
  p_topic_id uuid
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
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_topic_id is null then
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

  insert into public.topic_follows (
    user_id,
    topic_id,
    created_at
  )
  values (
    v_user_id,
    p_topic_id,
    now()
  )
  on conflict (user_id, topic_id)
  do nothing;

  return jsonb_build_object(
    'success', true,
    'topic_id', p_topic_id,
    'following', true
  );
end;
$$;

create or replace function public.rpc_unfollow_topic(
  p_topic_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_guard jsonb;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_topic_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  delete from public.topic_follows tf
  where tf.user_id = auth.uid()
    and tf.topic_id = p_topic_id;

  return jsonb_build_object(
    'success', true,
    'topic_id', p_topic_id,
    'following', false
  );
end;
$$;

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
  if v_guard is not null then
    return v_guard;
  end if;

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
    topic_id,
    author_id,
    title,
    body,
    created_at,
    updated_at
  )
  values (
    p_topic_id,
    v_user_id,
    p_title,
    p_body,
    now(),
    now()
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

create or replace function public.rpc_update_thread(
  p_thread_id uuid,
  p_title text default null,
  p_body text default null
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
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_thread_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_title is null and p_body is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_title is not null and (char_length(p_title) < 1 or char_length(p_title) > 120) then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_body is not null and (char_length(p_body) < 1 or char_length(p_body) > 10000) then
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

  if not public.guard_soft_state(v_thread.deleted_at, v_thread.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_thread.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.threads t
  set title = coalesce(p_title, t.title),
      body = coalesce(p_body, t.body),
      updated_at = now()
  where t.id = p_thread_id
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

create or replace function public.rpc_delete_thread(
  p_thread_id uuid
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
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_thread_id is null then
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

  if not public.guard_soft_state(v_thread.deleted_at, v_thread.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_thread.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.threads t
  set deleted_at = now(),
      updated_at = now()
  where t.id = p_thread_id
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
      'deleted_at', v_thread.deleted_at,
      'updated_at', v_thread.updated_at
    )
  );
end;
$$;

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
  if v_guard is not null then
    return v_guard;
  end if;

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
    thread_id,
    author_id,
    body,
    created_at,
    updated_at
  )
  values (
    p_thread_id,
    v_user_id,
    p_body,
    now(),
    now()
  )
  returning * into v_reply;

  update public.threads t
  set reply_count = t.reply_count + 1,
      updated_at = now()
  where t.id = p_thread_id;

  if v_thread.author_id <> v_user_id
     and public.guard_block(v_user_id, v_thread.author_id) then
    insert into public.notifications (
      user_id,
      type,
      actor_id,
      target_type,
      target_id,
      created_at
    )
    values (
      v_thread.author_id,
      'reply',
      v_user_id,
      'thread',
      p_thread_id,
      now()
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

create or replace function public.rpc_update_reply(
  p_reply_id uuid,
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
  v_reply public.replies;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_reply_id is null
     or p_body is null
     or char_length(p_body) < 1
     or char_length(p_body) > 5000 then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select *
    into v_reply
  from public.replies r
  where r.id = p_reply_id
  for update;

  if v_reply.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_reply.deleted_at, v_reply.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_reply.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.reply_revisions (
    reply_id,
    previous_body,
    created_at
  )
  values (
    v_reply.id,
    v_reply.body,
    now()
  )
  on conflict (reply_id)
  do update
     set previous_body = excluded.previous_body,
         created_at = excluded.created_at;

  update public.replies r
  set body = p_body,
      edited_at = now(),
      updated_at = now()
  where r.id = p_reply_id
  returning * into v_reply;

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

create or replace function public.rpc_delete_reply(
  p_reply_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_guard jsonb;
  v_reply public.replies;
begin
  v_guard := public.guard_terms_agreed();
  if v_guard is not null then
    return v_guard;
  end if;

  if p_reply_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select *
    into v_reply
  from public.replies r
  where r.id = p_reply_id
  for update;

  if v_reply.id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_reply.deleted_at, v_reply.hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if v_reply.author_id <> v_user_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.replies r
  set deleted_at = now(),
      updated_at = now()
  where r.id = p_reply_id
  returning * into v_reply;

  update public.threads t
  set reply_count = greatest(t.reply_count - 1, 0),
      updated_at = now()
  where t.id = v_reply.thread_id;

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
      'updated_at', v_reply.updated_at,
      'deleted_at', v_reply.deleted_at
    )
  );
end;
$$;

create or replace function public.rpc_search_threads(
  p_q text,
  p_topic_id uuid default null,
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
  v_q text := btrim(coalesce(p_q, ''));
  v_tsquery tsquery;
  v_cursor jsonb;
  v_cursor_rank real;
  v_cursor_created_at timestamptz;
  v_cursor_id uuid;
  v_threads jsonb;
  v_next_rank real;
  v_next_created_at timestamptz;
  v_next_id uuid;
begin
  if v_q = '' then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  begin
    v_tsquery := plainto_tsquery('simple', v_q);
  exception
    when others then
      return jsonb_build_object('error_code', 'invalid_request');
  end;

  if p_cursor is not null and btrim(p_cursor) <> '' then
    begin
      v_cursor := p_cursor::jsonb;
      v_cursor_rank := (v_cursor->>'rank')::real;
      v_cursor_created_at := (v_cursor->>'created_at')::timestamptz;
      v_cursor_id := (v_cursor->>'id')::uuid;
      if v_cursor_rank is null or v_cursor_created_at is null or v_cursor_id is null then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;
  end if;

  with scored as (
    select t.id,
           t.topic_id,
           tp.slug as topic_slug,
           tp.name as topic_name,
           t.author_id,
           p.nickname as author_nickname,
           t.title,
           t.body,
           t.like_count,
           t.reply_count,
           t.created_at,
           t.updated_at,
           ts_rank_cd(t.fts_vector, v_tsquery) as rank
    from public.threads t
    join public.topics tp
      on tp.id = t.topic_id
    join public.profiles p
      on p.user_id = t.author_id
    where tp.deleted_at is null
      and tp.is_public = true
      and public.guard_soft_state(t.deleted_at, t.hidden_at)
      and public.guard_block(v_viewer_id, t.author_id)
      and (p_topic_id is null or t.topic_id = p_topic_id)
      and t.fts_vector @@ v_tsquery
  ),
  raw_page as (
    select s.*
    from scored s
    where (
      v_cursor_rank is null
      or s.rank < v_cursor_rank
      or (
        s.rank = v_cursor_rank
        and (
          s.created_at < v_cursor_created_at
          or (s.created_at = v_cursor_created_at and s.id < v_cursor_id)
        )
      )
    )
    order by s.rank desc, s.created_at desc, s.id desc
    limit v_limit + 1
  ),
  page as (
    select *
    from raw_page
    order by rank desc, created_at desc, id desc
    limit v_limit
  ),
  next_row as (
    select rp.rank, rp.created_at, rp.id
    from raw_page rp
    order by rp.rank desc, rp.created_at desc, rp.id desc
    offset v_limit
    limit 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', pg.id,
               'topic_id', pg.topic_id,
               'topic_slug', pg.topic_slug,
               'topic_name', pg.topic_name,
               'author_id', pg.author_id,
               'author_nickname', pg.author_nickname,
               'title', pg.title,
               'body', pg.body,
               'like_count', pg.like_count,
               'reply_count', pg.reply_count,
               'rank', pg.rank,
               'created_at', pg.created_at,
               'updated_at', pg.updated_at
             )
             order by pg.rank desc, pg.created_at desc, pg.id desc
           ),
           '[]'::jsonb
         ),
         nr.rank,
         nr.created_at,
         nr.id
    into v_threads, v_next_rank, v_next_created_at, v_next_id
  from page pg
  left join next_row nr on true
  group by nr.rank, nr.created_at, nr.id;

  return jsonb_build_object(
    'threads', coalesce(v_threads, '[]'::jsonb),
    'next_cursor', case
      when v_next_id is null then null
      else jsonb_build_object(
        'rank', v_next_rank,
        'created_at', to_char(v_next_created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'id', v_next_id
      )::text
    end
  );
end;
$$;

create or replace function public.rpc_get_public_threads_feed(
  p_sort text default 'new',
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
  v_sort text := lower(coalesce(p_sort, 'new'));
  v_limit int := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_cursor jsonb;
  v_cursor_created_at timestamptz;
  v_cursor_id uuid;
  v_cursor_score numeric;
  v_like_weight numeric := 1;
  v_reply_weight numeric := 2;
  v_window_days int := 7;
  v_threads jsonb;
  v_next_created_at timestamptz;
  v_next_id uuid;
  v_next_score numeric;
begin
  if v_sort not in ('new', 'popular', 'following') then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_cursor is not null and btrim(p_cursor) <> '' then
    begin
      v_cursor := p_cursor::jsonb;
      if v_sort in ('new', 'following') then
        v_cursor_created_at := (v_cursor->>'created_at')::timestamptz;
        v_cursor_id := (v_cursor->>'id')::uuid;
        if v_cursor_created_at is null or v_cursor_id is null then
          return jsonb_build_object('error_code', 'invalid_request');
        end if;
      else
        v_cursor_score := (v_cursor->>'score')::numeric;
        v_cursor_created_at := (v_cursor->>'created_at')::timestamptz;
        v_cursor_id := (v_cursor->>'id')::uuid;
        if v_cursor_score is null or v_cursor_created_at is null or v_cursor_id is null then
          return jsonb_build_object('error_code', 'invalid_request');
        end if;
      end if;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;
  end if;

  if v_sort = 'following' and v_viewer_id is null then
    return jsonb_build_object('threads', '[]'::jsonb, 'next_cursor', null);
  end if;

  if v_sort = 'popular' then
    select coalesce((c.value->>'like_weight')::numeric, 1),
           coalesce((c.value->>'reply_weight')::numeric, 2),
           coalesce((c.value->>'window_days')::int, 7)
      into v_like_weight,
           v_reply_weight,
           v_window_days
    from public.app_config c
    where c.key = 'popular_feed';

    v_like_weight := coalesce(v_like_weight, 1);
    v_reply_weight := coalesce(v_reply_weight, 2);
    v_window_days := coalesce(v_window_days, 7);

    with scored as (
      select t.id,
             t.topic_id,
             tp.slug as topic_slug,
             tp.name as topic_name,
             t.author_id,
             p.nickname as author_nickname,
             t.title,
             t.body,
             t.like_count,
             t.reply_count,
             t.created_at,
             t.updated_at,
             (t.like_count * v_like_weight + t.reply_count * v_reply_weight) as score
      from public.threads t
      join public.topics tp
        on tp.id = t.topic_id
      join public.profiles p
        on p.user_id = t.author_id
      where tp.deleted_at is null
        and tp.is_public = true
        and public.guard_soft_state(t.deleted_at, t.hidden_at)
        and public.guard_block(v_viewer_id, t.author_id)
        and t.created_at >= now() - make_interval(days => v_window_days)
    ),
    raw_page as (
      select s.*
      from scored s
      where (
        v_cursor_score is null
        or s.score < v_cursor_score
        or (
          s.score = v_cursor_score
          and (
            s.created_at < v_cursor_created_at
            or (s.created_at = v_cursor_created_at and s.id < v_cursor_id)
          )
        )
      )
      order by s.score desc, s.created_at desc, s.id desc
      limit v_limit + 1
    ),
    page as (
      select *
      from raw_page
      order by score desc, created_at desc, id desc
      limit v_limit
    ),
    next_row as (
      select rp.score, rp.created_at, rp.id
      from raw_page rp
      order by rp.score desc, rp.created_at desc, rp.id desc
      offset v_limit
      limit 1
    )
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'id', pg.id,
                 'topic_id', pg.topic_id,
                 'topic_slug', pg.topic_slug,
                 'topic_name', pg.topic_name,
                 'author_id', pg.author_id,
                 'author_nickname', pg.author_nickname,
                 'title', pg.title,
                 'body', pg.body,
                 'like_count', pg.like_count,
                 'reply_count', pg.reply_count,
                 'score', pg.score,
                 'created_at', pg.created_at,
                 'updated_at', pg.updated_at
               )
               order by pg.score desc, pg.created_at desc, pg.id desc
             ),
             '[]'::jsonb
           ),
           nr.created_at,
           nr.id,
           nr.score
      into v_threads, v_next_created_at, v_next_id, v_next_score
    from page pg
    left join next_row nr on true
    group by nr.created_at, nr.id, nr.score;

    return jsonb_build_object(
      'threads', coalesce(v_threads, '[]'::jsonb),
      'next_cursor', case
        when v_next_id is null then null
        else jsonb_build_object(
          'score', v_next_score,
          'created_at', to_char(v_next_created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
          'id', v_next_id
        )::text
      end
    );
  end if;

  with base as (
    select t.id,
           t.topic_id,
           tp.slug as topic_slug,
           tp.name as topic_name,
           t.author_id,
           p.nickname as author_nickname,
           t.title,
           t.body,
           t.like_count,
           t.reply_count,
           t.created_at,
           t.updated_at
    from public.threads t
    join public.topics tp
      on tp.id = t.topic_id
    join public.profiles p
      on p.user_id = t.author_id
    where tp.deleted_at is null
      and tp.is_public = true
      and public.guard_soft_state(t.deleted_at, t.hidden_at)
      and public.guard_block(v_viewer_id, t.author_id)
      and (
        v_sort <> 'following'
        or exists (
          select 1
          from public.topic_follows tf
          where tf.user_id = v_viewer_id
            and tf.topic_id = t.topic_id
        )
      )
  ),
  raw_page as (
    select b.*
    from base b
    where (
      v_cursor_created_at is null
      or b.created_at < v_cursor_created_at
      or (b.created_at = v_cursor_created_at and b.id < v_cursor_id)
    )
    order by b.created_at desc, b.id desc
    limit v_limit + 1
  ),
  page as (
    select *
    from raw_page
    order by created_at desc, id desc
    limit v_limit
  ),
  next_row as (
    select rp.created_at, rp.id
    from raw_page rp
    order by rp.created_at desc, rp.id desc
    offset v_limit
    limit 1
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', pg.id,
               'topic_id', pg.topic_id,
               'topic_slug', pg.topic_slug,
               'topic_name', pg.topic_name,
               'author_id', pg.author_id,
               'author_nickname', pg.author_nickname,
               'title', pg.title,
               'body', pg.body,
               'like_count', pg.like_count,
               'reply_count', pg.reply_count,
               'created_at', pg.created_at,
               'updated_at', pg.updated_at
             )
             order by pg.created_at desc, pg.id desc
           ),
           '[]'::jsonb
         ),
         nr.created_at,
         nr.id
    into v_threads, v_next_created_at, v_next_id
  from page pg
  left join next_row nr on true
  group by nr.created_at, nr.id;

  return jsonb_build_object(
    'threads', coalesce(v_threads, '[]'::jsonb),
    'next_cursor', case
      when v_next_id is null then null
      else jsonb_build_object(
        'created_at', to_char(v_next_created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'id', v_next_id
      )::text
    end
  );
end;
$$;

create or replace function public.rpc_get_public_thread_detail(
  p_thread_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_thread jsonb;
begin
  select jsonb_build_object(
           'id', t.id,
           'topic_id', t.topic_id,
           'topic_slug', tp.slug,
           'topic_name', tp.name,
           'author_id', t.author_id,
           'author_nickname', p.nickname,
           'title', t.title,
           'body', t.body,
           'like_count', t.like_count,
           'reply_count', t.reply_count,
           'created_at', t.created_at,
           'updated_at', t.updated_at
         )
    into v_thread
  from public.threads t
  join public.topics tp
    on tp.id = t.topic_id
  join public.profiles p
    on p.user_id = t.author_id
  where t.id = p_thread_id
    and tp.deleted_at is null
    and tp.is_public = true
    and public.guard_soft_state(t.deleted_at, t.hidden_at)
    and public.guard_block(v_viewer_id, t.author_id);

  if v_thread is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return v_thread;
end;
$$;

revoke all on function public.rpc_list_topics() from public, anon, authenticated, service_role;
revoke all on function public.rpc_follow_topic(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_unfollow_topic(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_create_thread(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_update_thread(uuid, text, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_delete_thread(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_create_reply(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_update_reply(uuid, text) from public, anon, authenticated, service_role;
revoke all on function public.rpc_delete_reply(uuid) from public, anon, authenticated, service_role;
revoke all on function public.rpc_search_threads(text, uuid, text, int) from public, anon, authenticated, service_role;
revoke all on function public.rpc_get_public_threads_feed(text, text, int) from public, anon, authenticated, service_role;
revoke all on function public.rpc_get_public_thread_detail(uuid) from public, anon, authenticated, service_role;

grant execute on function public.rpc_list_topics() to authenticated;
grant execute on function public.rpc_follow_topic(uuid) to authenticated;
grant execute on function public.rpc_unfollow_topic(uuid) to authenticated;
grant execute on function public.rpc_create_thread(uuid, text, text) to authenticated;
grant execute on function public.rpc_update_thread(uuid, text, text) to authenticated;
grant execute on function public.rpc_delete_thread(uuid) to authenticated;
grant execute on function public.rpc_create_reply(uuid, text) to authenticated;
grant execute on function public.rpc_update_reply(uuid, text) to authenticated;
grant execute on function public.rpc_delete_reply(uuid) to authenticated;
grant execute on function public.rpc_search_threads(text, uuid, text, int) to authenticated;

grant execute on function public.rpc_get_public_threads_feed(text, text, int) to anon;
grant execute on function public.rpc_get_public_threads_feed(text, text, int) to authenticated;
grant execute on function public.rpc_get_public_thread_detail(uuid) to anon;
grant execute on function public.rpc_get_public_thread_detail(uuid) to authenticated;

commit;

begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_get_public_thread_replies(
  p_thread_id uuid,
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
  v_cursor_id uuid;
  v_thread_author_id uuid;
  v_thread_deleted_at timestamptz;
  v_thread_hidden_at timestamptz;
  v_result jsonb;
begin
  -- cursor 파싱 (jsonb keyset: created_at + id)
  if p_cursor is not null and btrim(p_cursor) <> '' then
    begin
      v_cursor_ts := (p_cursor::jsonb->>'created_at')::timestamptz;
      v_cursor_id := (p_cursor::jsonb->>'id')::uuid;
      if v_cursor_ts is null or v_cursor_id is null then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;
  end if;

  -- parent thread 가드: soft_state + block (D-050: 실패시 not_found)
  -- threads는 visibility/published 가드 미적용
  select t.author_id,
         t.deleted_at,
         t.hidden_at
    into v_thread_author_id,
         v_thread_deleted_at,
         v_thread_hidden_at
  from public.threads t
  join public.topics tp on tp.id = t.topic_id
  where t.id = p_thread_id
    and tp.deleted_at is null
    and tp.is_public = true;

  if v_thread_author_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_block(v_viewer_id, v_thread_author_id) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_thread_deleted_at, v_thread_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- reply 목록 조회: reply 자체 soft_state + block 적용
  with reply_rows as (
    select r.id,
           r.thread_id,
           r.author_id,
           pr.nickname as author_nickname,
           r.body,
           r.like_count,
           r.edited_at,
           r.created_at,
           r.updated_at
    from public.replies r
    join public.profiles pr on pr.user_id = r.author_id
    where r.thread_id = p_thread_id
      and public.guard_soft_state(r.deleted_at, r.hidden_at)
      and public.guard_block(v_viewer_id, r.author_id)
      and (
        v_cursor_ts is null
        or (r.created_at, r.id) < (v_cursor_ts, v_cursor_id)
      )
    order by r.created_at desc, r.id desc
    limit v_limit
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', reply_rows.id,
               'thread_id', reply_rows.thread_id,
               'author_id', reply_rows.author_id,
               'author_nickname', reply_rows.author_nickname,
               'body', reply_rows.body,
               'like_count', reply_rows.like_count,
               'edited_at', reply_rows.edited_at,
               'created_at', reply_rows.created_at,
               'updated_at', reply_rows.updated_at
             )
             order by reply_rows.created_at desc, reply_rows.id desc
           ),
           '[]'::jsonb
         )
    into v_result
  from reply_rows;

  return v_result;
end;
$$;

-- GRANT: anon + authenticated (공개 조회)
revoke all on function public.rpc_get_public_thread_replies(uuid, text, int)
  from public, anon, authenticated, service_role;

grant execute on function public.rpc_get_public_thread_replies(uuid, text, int) to anon;
grant execute on function public.rpc_get_public_thread_replies(uuid, text, int) to authenticated;

commit;

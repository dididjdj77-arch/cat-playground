begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- pg_cron 확장 활성화
create extension if not exists pg_cron;

-- 기존 잡이 있으면 제거 (멱등)
do $$
begin
  perform cron.unschedule(jobname)
  from cron.job
  where jobname in (
    'idempotency_sentinel_swap',
    'patch_dedup_cleanup',
    'pve_retention',
    'engagement_counter_reconcile'
  );
exception
  when others then null;
end;
$$;

-- ============================================================
-- JOB 1: observation_groups idempotency sentinel swap
-- D-041: 7일 경과 row의 idempotency_key를 sentinel UUID로 교체
-- CONFIG-BASELINES §4: 매시간, offset 15분
-- ============================================================
select cron.schedule(
  'idempotency_sentinel_swap',
  '15 * * * *',
  $$
    update public.observation_groups
    set idempotency_key = '00000000-0000-0000-0000-000000000000'::uuid
    where idempotency_key <> '00000000-0000-0000-0000-000000000000'::uuid
      and created_at < now() - interval '7 days';
  $$
);

-- ============================================================
-- JOB 2: observation_patch_dedup cleanup
-- D-061: 7일 경과 dedup 레코드 삭제
-- CONFIG-BASELINES §4: 매시간, offset 20분
-- ============================================================
select cron.schedule(
  'patch_dedup_cleanup',
  '20 * * * *',
  $$
    delete from public.observation_patch_dedup
    where created_at < now() - interval '7 days';
  $$
);

-- ============================================================
-- JOB 3: payload_version_events retention
-- D-045: 90일 초과 삭제
-- CONFIG-BASELINES §4: 매일 02:00 UTC, offset 30분
-- ============================================================
select cron.schedule(
  'pve_retention',
  '30 2 * * *',
  $$
    delete from public.payload_version_events
    where created_at < now() - interval '90 days';
  $$
);

-- ============================================================
-- JOB 4: engagement counter reconcile
-- D-100: like_count, comment_count, reply_count 보정
-- CONFIG-BASELINES §4: 6시간마다
-- deleted_at IS NULL 행만 카운트 (hidden은 포함)
-- ============================================================
select cron.schedule(
  'engagement_counter_reconcile',
  '0 */6 * * *',
  $$
    -- posts: like_count 보정
    update public.posts p
    set like_count = sub.actual_count
    from (
      select l.target_id, count(*) as actual_count
      from public.likes l
      where l.target_type = 'post'
      group by l.target_id
    ) sub
    where p.id = sub.target_id
      and p.like_count <> sub.actual_count
      and p.deleted_at is null;

    update public.posts p
    set like_count = 0
    where p.like_count > 0
      and p.deleted_at is null
      and not exists (
        select 1 from public.likes l
        where l.target_type = 'post' and l.target_id = p.id
      );

    -- posts: comment_count 보정
    update public.posts p
    set comment_count = sub.actual_count
    from (
      select c.post_id, count(*) as actual_count
      from public.comments c
      where c.deleted_at is null
      group by c.post_id
    ) sub
    where p.id = sub.post_id
      and p.comment_count <> sub.actual_count
      and p.deleted_at is null;

    update public.posts p
    set comment_count = 0
    where p.comment_count > 0
      and p.deleted_at is null
      and not exists (
        select 1 from public.comments c
        where c.post_id = p.id and c.deleted_at is null
      );

    -- threads: like_count 보정
    update public.threads t
    set like_count = sub.actual_count
    from (
      select l.target_id, count(*) as actual_count
      from public.likes l
      where l.target_type = 'thread'
      group by l.target_id
    ) sub
    where t.id = sub.target_id
      and t.like_count <> sub.actual_count
      and t.deleted_at is null;

    update public.threads t
    set like_count = 0
    where t.like_count > 0
      and t.deleted_at is null
      and not exists (
        select 1 from public.likes l
        where l.target_type = 'thread' and l.target_id = t.id
      );

    -- threads: reply_count 보정
    update public.threads t
    set reply_count = sub.actual_count
    from (
      select r.thread_id, count(*) as actual_count
      from public.replies r
      where r.deleted_at is null
      group by r.thread_id
    ) sub
    where t.id = sub.thread_id
      and t.reply_count <> sub.actual_count
      and t.deleted_at is null;

    update public.threads t
    set reply_count = 0
    where t.reply_count > 0
      and t.deleted_at is null
      and not exists (
        select 1 from public.replies r
        where r.thread_id = t.id and r.deleted_at is null
      );

    -- comments: like_count 보정
    update public.comments c
    set like_count = sub.actual_count
    from (
      select l.target_id, count(*) as actual_count
      from public.likes l
      where l.target_type = 'comment'
      group by l.target_id
    ) sub
    where c.id = sub.target_id
      and c.like_count <> sub.actual_count
      and c.deleted_at is null;

    update public.comments c
    set like_count = 0
    where c.like_count > 0
      and c.deleted_at is null
      and not exists (
        select 1 from public.likes l
        where l.target_type = 'comment' and l.target_id = c.id
      );

    -- replies: like_count 보정
    update public.replies r
    set like_count = sub.actual_count
    from (
      select l.target_id, count(*) as actual_count
      from public.likes l
      where l.target_type = 'reply'
      group by l.target_id
    ) sub
    where r.id = sub.target_id
      and r.like_count <> sub.actual_count
      and r.deleted_at is null;

    update public.replies r
    set like_count = 0
    where r.like_count > 0
      and r.deleted_at is null
      and not exists (
        select 1 from public.likes l
        where l.target_type = 'reply' and l.target_id = r.id
      );
  $$
);

commit;

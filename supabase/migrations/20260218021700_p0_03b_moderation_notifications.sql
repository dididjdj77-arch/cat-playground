begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

alter table public.blocks
  drop constraint if exists blocks_blocker_id_fkey;

alter table public.blocks
  add constraint blocks_blocker_id_fkey
  foreign key (blocker_id) references public.profiles(user_id) on delete cascade;

alter table public.blocks
  drop constraint if exists blocks_blocked_id_fkey;

alter table public.blocks
  add constraint blocks_blocked_id_fkey
  foreign key (blocked_id) references public.profiles(user_id) on delete cascade;

alter table public.reports
  drop constraint if exists reports_reporter_id_fkey;

alter table public.reports
  add constraint reports_reporter_id_fkey
  foreign key (reporter_id) references public.profiles(user_id) on delete cascade;

alter table public.reports
  drop constraint if exists reports_reason_code_check;

alter table public.reports
  drop constraint if exists reports_reason_code_chk;

alter table public.reports
  add constraint reports_reason_code_chk
  check (reason_code in ('spam', 'harassment', 'inappropriate', 'copyright', 'other'));

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(user_id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid not null,
  meta jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications
  drop constraint if exists notifications_user_id_fkey;

alter table public.notifications
  add constraint notifications_user_id_fkey
  foreign key (user_id) references public.profiles(user_id) on delete cascade;

alter table public.notifications
  drop constraint if exists notifications_actor_id_fkey;

alter table public.notifications
  add constraint notifications_actor_id_fkey
  foreign key (actor_id) references public.profiles(user_id) on delete cascade;

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  drop constraint if exists notifications_type_chk;

alter table public.notifications
  add constraint notifications_type_chk
  check (type in ('comment', 'reply', 'like'));

alter table public.notifications
  drop constraint if exists notifications_target_type_check;

alter table public.notifications
  drop constraint if exists notifications_target_type_chk;

alter table public.notifications
  add constraint notifications_target_type_chk
  check (target_type in ('post', 'thread'));

alter table public.notifications
  drop constraint if exists notifications_type_target_map_chk;

alter table public.notifications
  add constraint notifications_type_target_map_chk
  check (
    (type = 'comment' and target_type = 'post')
    or (type = 'reply' and target_type = 'thread')
    or (type = 'like' and target_type = 'post')
  );

alter table public.notifications
  drop column if exists is_read;

alter table public.notifications
  drop column if exists meta;

drop index if exists public.idx_notifications_user_unread;

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_read_at
  on public.notifications (user_id, read_at);

commit;

begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create table if not exists public.topic_follows (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  topic_id uuid not null references public.topics(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);

create index if not exists idx_topic_follows_topic_id
  on public.topic_follows (topic_id);

alter table public.threads
  drop constraint if exists threads_author_id_fkey;

alter table public.threads
  add constraint threads_author_id_fkey
  foreign key (author_id) references public.profiles(user_id) on delete cascade;

alter table public.threads
  drop constraint if exists threads_title_length_chk;

alter table public.threads
  add constraint threads_title_length_chk
  check (char_length(title) between 1 and 120);

alter table public.threads
  drop constraint if exists threads_body_length_chk;

alter table public.threads
  add constraint threads_body_length_chk
  check (char_length(body) between 1 and 10000);

alter table public.threads
  add column if not exists fts_vector tsvector
  generated always as (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(body, ''))) stored;

create index if not exists idx_threads_fts_vector
  on public.threads using gin (fts_vector);

alter table public.replies
  drop constraint if exists replies_author_id_fkey;

alter table public.replies
  add constraint replies_author_id_fkey
  foreign key (author_id) references public.profiles(user_id) on delete cascade;

alter table public.replies
  drop constraint if exists replies_body_length_chk;

alter table public.replies
  add constraint replies_body_length_chk
  check (char_length(body) between 1 and 5000);

create table if not exists public.reply_revisions (
  id uuid primary key default gen_random_uuid(),
  reply_id uuid not null references public.replies(id) on delete cascade,
  previous_body text not null,
  created_at timestamptz not null default now(),
  constraint reply_revisions_reply_id_uniq unique (reply_id)
);

alter table public.likes
  drop constraint if exists likes_user_id_fkey;

alter table public.likes
  add constraint likes_user_id_fkey
  foreign key (user_id) references public.profiles(user_id) on delete cascade;

commit;

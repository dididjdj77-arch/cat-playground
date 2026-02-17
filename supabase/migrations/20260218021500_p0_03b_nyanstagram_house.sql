begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

alter table public.house_profiles
  drop constraint if exists house_profiles_user_id_fkey;

alter table public.house_profiles
  add constraint house_profiles_user_id_fkey
  foreign key (user_id) references public.profiles(user_id) on delete cascade;

alter table public.house_profiles
  drop constraint if exists house_profiles_private_published_chk;

alter table public.house_profiles
  add constraint house_profiles_private_published_chk
  check (not (visibility = 'private' and published_at is not null));

alter table public.house_slots
  drop constraint if exists house_slots_owner_id_fkey;

alter table public.house_slots
  add constraint house_slots_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.house_slots
  drop constraint if exists house_slots_room_key_chk;

alter table public.house_slots
  add constraint house_slots_room_key_chk
  check (room_key = 'living_room');

alter table public.house_slots
  drop constraint if exists house_slots_slot_key_chk;

alter table public.house_slots
  add constraint house_slots_slot_key_chk
  check (slot_key in (
    'slot_01',
    'slot_02',
    'slot_03',
    'slot_04',
    'slot_05',
    'slot_06',
    'slot_07',
    'slot_08'
  ));

alter table public.posts
  add column if not exists meta jsonb not null default '{}'::jsonb;

alter table public.posts
  drop constraint if exists posts_author_id_fkey;

alter table public.posts
  add constraint posts_author_id_fkey
  foreign key (author_id) references public.profiles(user_id) on delete cascade;

alter table public.posts
  drop constraint if exists posts_body_length_chk;

alter table public.posts
  add constraint posts_body_length_chk
  check (char_length(body) between 1 and 5000);

alter table public.posts
  drop constraint if exists posts_private_published_chk;

alter table public.posts
  add constraint posts_private_published_chk
  check (not (visibility = 'private' and published_at is not null));

create index if not exists idx_posts_author_log_date
  on public.posts (author_id, log_date desc);

create index if not exists idx_posts_visibility_published
  on public.posts (visibility, published_at desc)
  where visibility = 'public' and published_at is not null;

create index if not exists idx_posts_published_at
  on public.posts (published_at desc);

alter table public.comments
  drop constraint if exists comments_author_id_fkey;

alter table public.comments
  add constraint comments_author_id_fkey
  foreign key (author_id) references public.profiles(user_id) on delete cascade;

alter table public.comments
  drop constraint if exists comments_body_length_chk;

alter table public.comments
  add constraint comments_body_length_chk
  check (char_length(body) between 1 and 2000);

create table if not exists public.comment_revisions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.comments(id) on delete cascade,
  previous_body text not null,
  created_at timestamptz not null default now(),
  constraint comment_revisions_comment_id_uniq unique (comment_id)
);

commit;

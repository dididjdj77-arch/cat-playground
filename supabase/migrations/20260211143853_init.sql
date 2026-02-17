begin;

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  nickname text not null unique,
  avatar_url text,
  bio text,
  nickname_changed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  default_post_visibility text not null default 'private'
    check (default_post_visibility in ('private','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cats (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  birth_date date,
  sex text,
  breed text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_cats_owner_deleted on public.cats (owner_id, deleted_at);
create index if not exists idx_cats_owner_name on public.cats (owner_id, name);

create table if not exists public.house_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  visibility text not null default 'private'
    check (visibility in ('private','public')),
  published_at timestamptz,
  hidden_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint house_profiles_private_published_chk
    check (not (visibility = 'private' and published_at is not null))
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('food','litter','toy','furniture')),
  catalog_item_id uuid,
  raw_text text,
  is_current boolean not null default true,
  changed_at timestamptz not null default now(),
  ended_at timestamptz,
  reason_code text not null default 'initial'
    check (reason_code in ('initial','switch','discontinue','correction')),
  reason_note text,
  note text,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint inventory_items_current_ended_chk
    check (
      (ended_at is null and is_current = true)
      or
      (ended_at is not null and is_current = false)
    )
);

create index if not exists idx_inventory_items_owner_type_current
  on public.inventory_items (owner_id, type, is_current);
create index if not exists idx_inventory_items_owner_deleted
  on public.inventory_items (owner_id, deleted_at);
create unique index if not exists idx_inventory_items_owner_type_current_uniq
  on public.inventory_items (owner_id, type)
  where is_current = true and deleted_at is null;

create table if not exists public.house_slots (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  room_key text not null default 'living_room',
  slot_key text not null,
  inventory_item_id uuid references public.inventory_items(id),
  equipped_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint house_slots_owner_room_slot_uniq unique (owner_id, room_key, slot_key)
);

create table if not exists public.observation_groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  log_date date not null check (log_date <= current_date),
  payload_version text not null,
  common_payload jsonb not null default '{}'::jsonb,
  version int not null default 1 check (version >= 1),
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint observation_groups_owner_idempotency_uniq unique (owner_id, idempotency_key)
);

create unique index if not exists idx_observation_groups_owner_log_date_uniq
  on public.observation_groups (owner_id, log_date)
  where deleted_at is null;
create index if not exists idx_observation_groups_owner_log_date
  on public.observation_groups (owner_id, log_date);
create index if not exists idx_observation_groups_owner_payload_version
  on public.observation_groups (owner_id, payload_version);
create index if not exists idx_observation_groups_owner_idempotency
  on public.observation_groups (owner_id, idempotency_key);

create table if not exists public.observations (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.observation_groups(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  cat_id uuid not null references public.cats(id) on delete cascade,
  status text not null default 'active' check (status in ('active','excluded')),
  override_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint observations_group_cat_uniq unique (group_id, cat_id)
);

create table if not exists public.observation_patch_dedup (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  group_id uuid not null references public.observation_groups(id) on delete cascade,
  idempotency_key uuid not null,
  result_json jsonb,
  created_at timestamptz not null default now(),
  constraint observation_patch_dedup_owner_group_key_uniq
    unique (owner_id, group_id, idempotency_key)
);

create table if not exists public.observation_inventory_refs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  group_id uuid not null references public.observation_groups(id) on delete cascade,
  inv_type text not null check (inv_type in ('food','litter','toy','furniture')),
  inventory_item_id uuid not null references public.inventory_items(id),
  created_at timestamptz not null default now(),
  constraint observation_inventory_refs_group_type_uniq unique (group_id, inv_type)
);

create table if not exists public.topics (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.threads (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references public.topics(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  like_count int not null default 0 check (like_count >= 0),
  reply_count int not null default 0 check (reply_count >= 0),
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.replies (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  edited_at timestamptz,
  like_count int not null default 0 check (like_count >= 0),
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  log_date date not null check (log_date <= current_date),
  visibility text not null default 'private'
    check (visibility in ('private','public')),
  published_at timestamptz,
  hide_from_profile boolean not null default false,
  like_count int not null default 0 check (like_count >= 0),
  comment_count int not null default 0 check (comment_count >= 0),
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint posts_private_published_chk
    check (not (visibility = 'private' and published_at is not null))
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  edited_at timestamptz,
  like_count int not null default 0 check (like_count >= 0),
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post','comment','thread','reply')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  constraint likes_user_target_uniq unique (user_id, target_type, target_id)
);

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self_chk check (blocker_id <> blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  reason_code text not null,
  note text,
  snapshot jsonb,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index if not exists idx_reports_reporter_target_uniq
  on public.reports (reporter_id, target_type, target_id)
  where deleted_at is null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('comment','reply','like')),
  target_type text not null check (target_type in ('post','comment','thread','reply')),
  target_id uuid not null,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  is_read boolean not null default false,
  read_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);
create index if not exists idx_notifications_user_unread
  on public.notifications (user_id, is_read)
  where is_read = false;

create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);

commit;

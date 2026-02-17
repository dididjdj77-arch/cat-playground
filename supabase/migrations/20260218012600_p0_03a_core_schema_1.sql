begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

alter table public.profiles
  add column if not exists user_id uuid,
  add column if not exists avatar_key text,
  add column if not exists terms_agreed_at timestamptz,
  add column if not exists is_admin boolean not null default false,
  add column if not exists deleted_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_user_id_key;

alter table public.profiles
  add constraint profiles_user_id_key unique (user_id);

alter table public.profiles
  drop constraint if exists profiles_user_id_fkey;

alter table public.profiles
  add constraint profiles_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;

alter table public.profiles
  drop constraint if exists profiles_nickname_length_chk;

alter table public.profiles
  add constraint profiles_nickname_length_chk
  check (char_length(nickname) between 2 and 20);

alter table public.profiles
  drop constraint if exists profiles_bio_length_chk;

alter table public.profiles
  add constraint profiles_bio_length_chk
  check (bio is null or char_length(bio) <= 200);

create table if not exists public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('food','litter','toy','furniture')),
  standard_name text not null,
  brand text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint catalog_items_type_standard_name_uniq unique (type, standard_name)
);

create table if not exists public.catalog_aliases (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('food','litter','toy','furniture')),
  alias text not null,
  catalog_item_id uuid not null references public.catalog_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint catalog_aliases_type_alias_uniq unique (type, alias)
);

create index if not exists idx_catalog_aliases_catalog_item_id
  on public.catalog_aliases (catalog_item_id);

create table if not exists public.catalog_suggestions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('food','litter','toy','furniture')),
  raw_text text not null,
  suggested_by uuid not null references public.profiles(user_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  resolved_catalog_item_id uuid references public.catalog_items(id) on delete set null,
  reviewed_by uuid references public.profiles(user_id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_catalog_suggestions_status_created
  on public.catalog_suggestions (status, created_at desc);

create index if not exists idx_catalog_suggestions_type_status_created
  on public.catalog_suggestions (type, status, created_at desc);

alter table public.cats
  add column if not exists avatar_key text;

alter table public.cats
  drop constraint if exists cats_owner_id_fkey;

alter table public.cats
  add constraint cats_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.inventory_items
  drop constraint if exists inventory_items_owner_id_fkey;

alter table public.inventory_items
  add constraint inventory_items_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.inventory_items
  drop constraint if exists inventory_items_catalog_item_id_fkey;

alter table public.inventory_items
  add constraint inventory_items_catalog_item_id_fkey
  foreign key (catalog_item_id) references public.catalog_items(id);

alter table public.inventory_items
  drop constraint if exists inventory_items_reason_code_check;

alter table public.inventory_items
  drop constraint if exists inventory_items_reason_code_chk;

alter table public.inventory_items
  add constraint inventory_items_reason_code_chk
  check (reason_code in ('initial','switch','correction'));

alter table public.inventory_items
  drop constraint if exists inventory_items_raw_text_length_chk;

alter table public.inventory_items
  add constraint inventory_items_raw_text_length_chk
  check (char_length(raw_text) between 1 and 200);

alter table public.inventory_items
  drop constraint if exists inventory_items_reason_note_length_chk;

alter table public.inventory_items
  add constraint inventory_items_reason_note_length_chk
  check (reason_note is null or char_length(reason_note) <= 500);

alter table public.observation_groups
  drop constraint if exists observation_groups_owner_id_fkey;

alter table public.observation_groups
  add constraint observation_groups_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.observation_groups
  drop constraint if exists observation_groups_owner_idempotency_uniq;

create unique index if not exists idx_observation_groups_owner_idempotency_active_uniq
  on public.observation_groups (owner_id, idempotency_key)
  where idempotency_key <> '00000000-0000-0000-0000-000000000000'::uuid;

alter table public.observations
  drop constraint if exists observations_owner_id_fkey;

alter table public.observations
  add constraint observations_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.observation_patch_dedup
  drop constraint if exists observation_patch_dedup_owner_id_fkey;

alter table public.observation_patch_dedup
  add constraint observation_patch_dedup_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

alter table public.observation_inventory_refs
  drop constraint if exists observation_inventory_refs_owner_id_fkey;

alter table public.observation_inventory_refs
  add constraint observation_inventory_refs_owner_id_fkey
  foreign key (owner_id) references public.profiles(user_id) on delete cascade;

commit;

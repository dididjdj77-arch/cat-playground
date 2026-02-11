begin;

alter table public.profiles
  add column if not exists user_id uuid,
  add column if not exists terms_agreed_at timestamptz,
  add column if not exists is_admin boolean not null default false,
  add column if not exists avatar_key text;

update public.profiles
set avatar_key = avatar_url
where avatar_key is null
  and avatar_url is not null;

update public.profiles p
set user_id = p.id
where p.user_id is null
  and exists (
    select 1
    from auth.users u
    where u.id = p.id
  );

do $$
begin
  if exists (select 1 from public.profiles where user_id is null) then
    raise exception 'profiles.user_id contains null rows; backfill required before setting NOT NULL';
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_user_id_key'
  ) then
    alter table public.profiles
      add constraint profiles_user_id_key unique (user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_user_id_fkey'
  ) then
    alter table public.profiles
      add constraint profiles_user_id_fkey
      foreign key (user_id) references auth.users(id) on delete cascade;
  end if;
end
$$;

alter table public.profiles
  alter column user_id set not null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('comment', 'reply', 'like')),
  actor_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'thread')),
  target_id uuid not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notifications_type_target_match_chk check (
    (type = 'comment' and target_type = 'post')
    or (type = 'reply' and target_type = 'thread')
    or (type = 'like' and target_type = 'post')
  )
);

create index if not exists idx_notifications_user_created_at
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_read_at
  on public.notifications (user_id, read_at);

alter table public.cats
  add column if not exists avatar_key text;

update public.cats
set avatar_key = avatar_url
where avatar_key is null
  and avatar_url is not null;

comment on column public.profiles.avatar_url is
  'DEPRECATED: use avatar_key (storage key path). Keep for legacy compatibility only.';

comment on column public.cats.avatar_url is
  'DEPRECATED: use avatar_key (storage key path). Keep for legacy compatibility only.';

commit;

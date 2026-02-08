-- 001_inventory_switch_discontinue_observation_refs.sql
-- D-058, D-059, D-060

-- 1) inventory_items 확장: reason_code/reason_note/ended_at + type CHECK 갱신(medicine 제거)
alter table public.inventory_items
  add column if not exists reason_code text,
  add column if not exists reason_note text,
  add column if not exists ended_at timestamptz;

update public.inventory_items
set reason_code = 'initial'
where reason_code is null;

alter table public.inventory_items
  alter column reason_code set default 'initial';

alter table public.inventory_items
  alter column reason_code set not null;

-- 기존 type CHECK(medicine 포함) 제거
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.inventory_items'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%type%'
      AND pg_get_constraintdef(oid) ILIKE '%medicine%'
  LOOP
    EXECUTE format('ALTER TABLE public.inventory_items DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;
END $$;

alter table public.inventory_items
  drop constraint if exists inventory_items_type_check_v1;

alter table public.inventory_items
  add constraint inventory_items_type_check_v1
  check (type in ('food', 'litter', 'toy', 'furniture')) not valid;

alter table public.inventory_items
  drop constraint if exists inventory_items_reason_code_check;

alter table public.inventory_items
  add constraint inventory_items_reason_code_check
  check (reason_code in ('initial', 'switch', 'discontinue', 'correction'));

-- 2) 관찰 시점 인벤 참조 고정 테이블
create table if not exists public.observation_inventory_refs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null,
  group_id uuid not null,
  inv_type text not null,
  inventory_item_id uuid not null,
  created_at timestamptz not null default now(),
  constraint observation_inventory_refs_inv_type_check
    check (inv_type in ('food', 'litter', 'toy', 'furniture')),
  constraint observation_inventory_refs_group_id_fkey
    foreign key (group_id)
    references public.observation_groups(id)
    on delete cascade,
  constraint observation_inventory_refs_inventory_item_id_fkey
    foreign key (inventory_item_id)
    references public.inventory_items(id)
    on delete restrict,
  constraint observation_inventory_refs_group_inv_type_uniq
    unique (group_id, inv_type)
);

create index if not exists idx_observation_inventory_refs_owner_group
  on public.observation_inventory_refs (owner_id, group_id);

create index if not exists idx_observation_inventory_refs_owner_type_created
  on public.observation_inventory_refs (owner_id, inv_type, created_at desc);

-- 3) RLS + owner 정책
alter table public.observation_inventory_refs enable row level security;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'observation_inventory_refs'
      AND policyname = 'observation_inventory_refs_select_own'
  ) THEN
    CREATE POLICY observation_inventory_refs_select_own
      ON public.observation_inventory_refs
      FOR SELECT
      USING (owner_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'observation_inventory_refs'
      AND policyname = 'observation_inventory_refs_insert_own'
  ) THEN
    CREATE POLICY observation_inventory_refs_insert_own
      ON public.observation_inventory_refs
      FOR INSERT
      WITH CHECK (owner_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'observation_inventory_refs'
      AND policyname = 'observation_inventory_refs_update_own'
  ) THEN
    CREATE POLICY observation_inventory_refs_update_own
      ON public.observation_inventory_refs
      FOR UPDATE
      USING (owner_id = auth.uid())
      WITH CHECK (owner_id = auth.uid());
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'observation_inventory_refs'
      AND policyname = 'observation_inventory_refs_delete_own'
  ) THEN
    CREATE POLICY observation_inventory_refs_delete_own
      ON public.observation_inventory_refs
      FOR DELETE
      USING (owner_id = auth.uid());
  END IF;
END $$;

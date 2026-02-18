begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- ============================================================
-- FIX 1: profile_settings.user_id FK → profiles(user_id)
-- D-094: 모든 owner FK는 profiles.user_id(= auth.users.id)를 참조
-- 기존: profiles(id) — profiles 내부 PK를 참조하고 있었음
-- ============================================================
alter table public.profile_settings
  drop constraint profile_settings_user_id_fkey;

alter table public.profile_settings
  add constraint profile_settings_user_id_fkey
  foreign key (user_id) references public.profiles(user_id) on delete cascade;

-- ============================================================
-- FIX 2: inventory_items.raw_text NOT NULL
-- D-086: raw_text NOT NULL, 최소 1자
-- DATA-MODEL.md: raw_text text NOT NULL
-- 기존: nullable
-- ============================================================
update public.inventory_items
  set raw_text = ''
  where raw_text is null;

alter table public.inventory_items
  alter column raw_text set not null;

-- ============================================================
-- FIX 3: app_config rate_limits per_min → per_minute
-- shared/app-config.ts RateLimitEntry: per_minute / per_day
-- DB seed: per_min / per_day (불일치)
-- playbook도 per_min으로 되어있으나, 타입 SSOT(app-config.ts)에 맞춤
-- ============================================================
update public.app_config
  set value = (
    select jsonb_object_agg(
      category,
      jsonb_build_object(
        'per_minute', (entry->>'per_min')::int,
        'per_day', (entry->>'per_day')::int
      )
    )
    from jsonb_each(app_config.value) as t(category, entry)
  )
  where key in ('rate_limits', 'rate_limits_new_account');

commit;

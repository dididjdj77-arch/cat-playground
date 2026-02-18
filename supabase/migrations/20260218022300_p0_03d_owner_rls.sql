begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

alter table public.profiles enable row level security;
drop policy if exists profiles_owner_all on public.profiles;
create policy profiles_owner_all
on public.profiles
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

alter table public.catalog_suggestions enable row level security;
drop policy if exists catalog_suggestions_owner_all on public.catalog_suggestions;
create policy catalog_suggestions_owner_all
on public.catalog_suggestions
for all
to authenticated
using (suggested_by = auth.uid())
with check (suggested_by = auth.uid());

alter table public.cats enable row level security;
drop policy if exists cats_owner_all on public.cats;
create policy cats_owner_all
on public.cats
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.house_profiles enable row level security;
drop policy if exists house_profiles_owner_all on public.house_profiles;
create policy house_profiles_owner_all
on public.house_profiles
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

alter table public.house_slots enable row level security;
drop policy if exists house_slots_owner_all on public.house_slots;
create policy house_slots_owner_all
on public.house_slots
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.inventory_items enable row level security;
drop policy if exists inventory_items_owner_all on public.inventory_items;
create policy inventory_items_owner_all
on public.inventory_items
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.observation_groups enable row level security;
drop policy if exists observation_groups_owner_all on public.observation_groups;
create policy observation_groups_owner_all
on public.observation_groups
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.observations enable row level security;
drop policy if exists observations_owner_all on public.observations;
create policy observations_owner_all
on public.observations
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.observation_inventory_refs enable row level security;
drop policy if exists observation_inventory_refs_owner_all on public.observation_inventory_refs;
create policy observation_inventory_refs_owner_all
on public.observation_inventory_refs
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.observation_patch_dedup enable row level security;
drop policy if exists observation_patch_dedup_owner_all on public.observation_patch_dedup;
create policy observation_patch_dedup_owner_all
on public.observation_patch_dedup
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

alter table public.posts enable row level security;
drop policy if exists posts_owner_all on public.posts;
create policy posts_owner_all
on public.posts
for all
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

alter table public.comments enable row level security;
drop policy if exists comments_owner_all on public.comments;
create policy comments_owner_all
on public.comments
for all
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

alter table public.threads enable row level security;
drop policy if exists threads_owner_all on public.threads;
create policy threads_owner_all
on public.threads
for all
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

alter table public.replies enable row level security;
drop policy if exists replies_owner_all on public.replies;
create policy replies_owner_all
on public.replies
for all
to authenticated
using (author_id = auth.uid())
with check (author_id = auth.uid());

alter table public.topic_follows enable row level security;
drop policy if exists topic_follows_owner_all on public.topic_follows;
create policy topic_follows_owner_all
on public.topic_follows
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

alter table public.likes enable row level security;
drop policy if exists likes_owner_all on public.likes;
create policy likes_owner_all
on public.likes
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

alter table public.blocks enable row level security;
drop policy if exists blocks_owner_all on public.blocks;
create policy blocks_owner_all
on public.blocks
for all
to authenticated
using (blocker_id = auth.uid())
with check (blocker_id = auth.uid());

alter table public.reports enable row level security;
drop policy if exists reports_owner_all on public.reports;
create policy reports_owner_all
on public.reports
for all
to authenticated
using (reporter_id = auth.uid())
with check (reporter_id = auth.uid());

alter table public.notifications enable row level security;
drop policy if exists notifications_owner_all on public.notifications;
create policy notifications_owner_all
on public.notifications
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

commit;

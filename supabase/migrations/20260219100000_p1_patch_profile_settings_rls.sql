begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- ============================================================
-- FIX: profile_settings RLS 누락
-- p0_03d_owner_rls에서 19개 테이블에 RLS 적용했으나
-- profile_settings가 빠져 있었음.
-- SELECT은 이미 revoke 상태(p0_03d_grants_revoke)이고
-- 접근은 RPC 경유이나, defense-in-depth를 위해 추가.
-- ============================================================
alter table public.profile_settings enable row level security;

drop policy if exists profile_settings_owner_all on public.profile_settings;
create policy profile_settings_owner_all
on public.profile_settings
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

commit;

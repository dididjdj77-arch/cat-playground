begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

-- ============================================================
-- rpc_get_my_profile (API.md §8)
-- 접근: auth-only (owner)
-- 반환: jsonb (nickname, bio, avatar_key, terms_agreed_at, created_at)
-- read RPC이므로 guard_terms_agreed 미적용.
-- ============================================================
create or replace function public.rpc_get_my_profile()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  select jsonb_build_object(
    'user_id', p.user_id,
    'nickname', p.nickname,
    'bio', p.bio,
    'avatar_key', p.avatar_key,
    'terms_agreed_at', p.terms_agreed_at,
    'created_at', p.created_at
  )
  into v_profile
  from public.profiles p
  where p.user_id = v_user_id
    and p.deleted_at is null;

  if v_profile is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  return jsonb_build_object('profile', v_profile);
end;
$$;

-- ============================================================
-- rpc_get_my_house (API.md §8)
-- 접근: auth-only (owner)
-- 반환: jsonb (house_profile 상태 + 슬롯 목록 + 바인딩된 인벤 정보)
-- house_profiles가 없으면 lazy create하지 않고 기본 상태 반환 (D-085).
-- read RPC이므로 guard_terms_agreed 미적용.
-- ============================================================
create or replace function public.rpc_get_my_house()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_house jsonb;
  v_slots jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  select jsonb_build_object(
    'user_id', hp.user_id,
    'visibility', hp.visibility,
    'published_at', hp.published_at,
    'created_at', hp.created_at
  )
  into v_house
  from public.house_profiles hp
  where hp.user_id = v_user_id;

  if v_house is null then
    -- D-085: lazy create하지 않고 기본 상태 반환
    v_house := jsonb_build_object(
      'user_id', v_user_id,
      'visibility', 'private',
      'published_at', null,
      'created_at', null
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'slot_key', hs.slot_key,
        'room_key', hs.room_key,
        'inventory_item_id', hs.inventory_item_id,
        'equipped_at', hs.equipped_at,
        'type', ci.type,
        'standard_name', ci.standard_name
      )
      order by hs.slot_key
    ),
    '[]'::jsonb
  )
  into v_slots
  from public.house_slots hs
  left join public.inventory_items ii on ii.id = hs.inventory_item_id
  left join public.catalog_items ci on ci.id = ii.catalog_item_id
  where hs.owner_id = v_user_id;

  return jsonb_build_object(
    'house', v_house,
    'slots', v_slots
  );
end;
$$;

-- ============================================================
-- rpc_get_my_observation_group (API.md §8)
-- 접근: auth-only (owner)
-- 입력: p_log_date date
-- 반환: jsonb (group + items + inventory_refs). 없으면 null/빈 객체.
-- owner_id = auth.uid()로 고정.
-- read RPC이므로 guard_terms_agreed 미적용.
-- ============================================================
create or replace function public.rpc_get_my_observation_group(
  p_log_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_group_id uuid;
  v_group jsonb;
  v_items jsonb;
  v_inventory_refs jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  if p_log_date is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'log_date_required');
  end if;

  select og.id
  into v_group_id
  from public.observation_groups og
  where og.owner_id = v_user_id
    and og.log_date = p_log_date
    and og.deleted_at is null;

  if v_group_id is null then
    return jsonb_build_object('group', null, 'items', '[]'::jsonb, 'inventory_refs', '[]'::jsonb);
  end if;

  select jsonb_build_object(
    'id', og.id,
    'log_date', og.log_date,
    'payload_version', og.payload_version,
    'version', og.version,
    'created_at', og.created_at,
    'updated_at', og.updated_at
  )
  into v_group
  from public.observation_groups og
  where og.id = v_group_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'cat_id', o.cat_id,
        'status', o.status,
        'override_payload', o.override_payload,
        'created_at', o.created_at
      )
      order by o.created_at
    ),
    '[]'::jsonb
  )
  into v_items
  from public.observations o
  where o.group_id = v_group_id
    and o.deleted_at is null;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', oir.id,
        'inv_type', oir.inv_type,
        'inventory_item_id', oir.inventory_item_id,
        'created_at', oir.created_at
      )
    ),
    '[]'::jsonb
  )
  into v_inventory_refs
  from public.observation_inventory_refs oir
  where oir.group_id = v_group_id;

  return jsonb_build_object(
    'group', v_group,
    'items', v_items,
    'inventory_refs', v_inventory_refs
  );
end;
$$;

-- grants
revoke all on function public.rpc_get_my_profile() from public;
revoke all on function public.rpc_get_my_profile() from anon;
revoke all on function public.rpc_get_my_profile() from service_role;
grant execute on function public.rpc_get_my_profile() to authenticated;

revoke all on function public.rpc_get_my_house() from public;
revoke all on function public.rpc_get_my_house() from anon;
revoke all on function public.rpc_get_my_house() from service_role;
grant execute on function public.rpc_get_my_house() to authenticated;

revoke all on function public.rpc_get_my_observation_group(date) from public;
revoke all on function public.rpc_get_my_observation_group(date) from anon;
revoke all on function public.rpc_get_my_observation_group(date) from service_role;
grant execute on function public.rpc_get_my_observation_group(date) to authenticated;

commit;

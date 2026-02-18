begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_set_house_slot(
  p_room_key text,
  p_slot_key text,
  p_inventory_item_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_terms_guard jsonb;
  v_profile_deleted_at timestamptz;
  v_profile_hidden_at timestamptz;
  v_item_owner_id uuid;
  v_item_is_current boolean;
  v_item_deleted_at timestamptz;
  v_slot public.house_slots%rowtype;
begin
  -- D-096 #1 terms
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  if p_room_key is null or btrim(p_room_key) = ''
     or p_slot_key is null or btrim(p_slot_key) = ''
     or p_inventory_item_id is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  insert into public.house_profiles (
    user_id,
    visibility,
    published_at,
    created_at,
    updated_at
  )
  values (
    v_owner_id,
    'private',
    null,
    now(),
    now()
  )
  on conflict (user_id) do nothing;

  -- D-096 #2 block (N/A: owner write)

  -- D-096 #3 soft_state
  select h.deleted_at, h.hidden_at
    into v_profile_deleted_at, v_profile_hidden_at
  from public.house_profiles h
  where h.user_id = v_owner_id;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if not public.guard_soft_state(v_profile_deleted_at, v_profile_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- D-096 #4 domain
  select i.owner_id, i.is_current, i.deleted_at
    into v_item_owner_id, v_item_is_current, v_item_deleted_at
  from public.inventory_items i
  where i.id = p_inventory_item_id;

  if v_item_owner_id is null or v_item_owner_id <> v_owner_id then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if coalesce(v_item_is_current, false) is not true or v_item_deleted_at is not null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'inventory_item_not_current');
  end if;

  insert into public.house_slots (
    owner_id,
    room_key,
    slot_key,
    inventory_item_id,
    equipped_at,
    created_at,
    updated_at,
    deleted_at
  )
  values (
    v_owner_id,
    p_room_key,
    p_slot_key,
    p_inventory_item_id,
    now(),
    now(),
    now(),
    null
  )
  on conflict (owner_id, room_key, slot_key)
  do update
    set inventory_item_id = excluded.inventory_item_id,
        equipped_at = excluded.equipped_at,
        updated_at = now(),
        deleted_at = null
  returning * into v_slot;

  return jsonb_build_object(
    'slot',
    jsonb_build_object(
      'room_key', v_slot.room_key,
      'slot_key', v_slot.slot_key,
      'inventory_item_id', v_slot.inventory_item_id,
      'equipped_at', v_slot.equipped_at
    )
  );
end;
$$;

create or replace function public.rpc_clear_house_slot(
  p_room_key text,
  p_slot_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_terms_guard jsonb;
begin
  -- D-096 #1 terms
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-096 #2 block (N/A: owner write)
  -- D-096 #3 soft_state (N/A)

  -- D-096 #4 domain
  if p_room_key is null or btrim(p_room_key) = ''
     or p_slot_key is null or btrim(p_slot_key) = '' then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  update public.house_slots s
  set inventory_item_id = null,
      equipped_at = null,
      updated_at = now()
  where s.owner_id = v_owner_id
    and s.room_key = p_room_key
    and s.slot_key = p_slot_key
    and s.deleted_at is null;

  return jsonb_build_object(
    'success', true,
    'slot',
    jsonb_build_object(
      'room_key', p_room_key,
      'slot_key', p_slot_key,
      'equipped_at', null
    )
  );
end;
$$;

create or replace function public.rpc_publish_house()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_terms_guard jsonb;
  v_hidden_at timestamptz;
  v_deleted_at timestamptz;
  v_profile public.house_profiles%rowtype;
begin
  -- D-096 #1 terms
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-096 #2 block (N/A: owner write)
  -- D-096 #3 soft_state (folded into domain for this RPC)

  -- D-096 #4 domain
  select h.hidden_at, h.deleted_at
    into v_hidden_at, v_deleted_at
  from public.house_profiles h
  where h.user_id = v_owner_id
  for update;

  if found and not public.guard_soft_state(v_deleted_at, v_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.house_profiles (
    user_id,
    visibility,
    published_at,
    created_at,
    updated_at
  )
  values (
    v_owner_id,
    'public',
    now(),
    now(),
    now()
  )
  on conflict (user_id)
  do update
    set visibility = 'public',
        published_at = now(),
        updated_at = now()
  returning * into v_profile;

  return jsonb_build_object(
    'house_profile',
    jsonb_build_object(
      'user_id', v_profile.user_id,
      'visibility', v_profile.visibility,
      'published_at', v_profile.published_at,
      'hidden_at', v_profile.hidden_at,
      'deleted_at', v_profile.deleted_at,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    )
  );
end;
$$;

create or replace function public.rpc_unpublish_house()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_terms_guard jsonb;
  v_hidden_at timestamptz;
  v_deleted_at timestamptz;
  v_profile public.house_profiles%rowtype;
begin
  -- D-096 #1 terms
  v_terms_guard := public.guard_terms_agreed();
  if v_terms_guard is not null then
    return v_terms_guard;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth_required');
  end if;

  -- D-096 #2 block (N/A: owner write)
  -- D-096 #3 soft_state (folded into domain for this RPC)

  -- D-096 #4 domain
  select h.hidden_at, h.deleted_at
    into v_hidden_at, v_deleted_at
  from public.house_profiles h
  where h.user_id = v_owner_id
  for update;

  if found and not public.guard_soft_state(v_deleted_at, v_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  insert into public.house_profiles (
    user_id,
    visibility,
    published_at,
    created_at,
    updated_at
  )
  values (
    v_owner_id,
    'private',
    null,
    now(),
    now()
  )
  on conflict (user_id)
  do update
    set published_at = null,
        updated_at = now()
  returning * into v_profile;

  return jsonb_build_object(
    'house_profile',
    jsonb_build_object(
      'user_id', v_profile.user_id,
      'visibility', v_profile.visibility,
      'published_at', v_profile.published_at,
      'hidden_at', v_profile.hidden_at,
      'deleted_at', v_profile.deleted_at,
      'created_at', v_profile.created_at,
      'updated_at', v_profile.updated_at
    )
  );
end;
$$;

create or replace function public.rpc_get_public_house_slots_summary(
  p_target_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_viewer_id uuid := auth.uid();
  v_visibility text;
  v_published_at timestamptz;
  v_deleted_at timestamptz;
  v_hidden_at timestamptz;
  v_slots jsonb;
begin
  if v_viewer_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  if p_target_user_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- guard: block(viewer, target)
  if not public.guard_block(v_viewer_id, p_target_user_id) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  select h.visibility,
         h.published_at,
         h.deleted_at,
         h.hidden_at
    into v_visibility,
         v_published_at,
         v_deleted_at,
         v_hidden_at
  from public.house_profiles h
  where h.user_id = p_target_user_id;

  if not found then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- guard: visibility_published(house)
  if not public.guard_visibility_published(v_visibility, v_published_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  -- guard: soft_state
  if not public.guard_soft_state(v_deleted_at, v_hidden_at) then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  with rows as (
    select
      s.slot_key,
      s.equipped_at,
      i.type,
      c.standard_name
    from public.house_slots s
    left join public.inventory_items i
      on i.id = s.inventory_item_id
     and i.owner_id = p_target_user_id
     and i.deleted_at is null
     and i.is_current = true
    left join public.catalog_items c
      on c.id = i.catalog_item_id
    where s.owner_id = p_target_user_id
      and s.deleted_at is null
    order by s.slot_key
  )
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'slot_key', r.slot_key,
               'equipped_at', r.equipped_at,
               'type', r.type,
               'standard_name', r.standard_name
             )
             order by r.slot_key
           ),
           '[]'::jsonb
         )
    into v_slots
  from rows r;

  return jsonb_build_object('slots', v_slots);
end;
$$;

revoke all on function public.rpc_set_house_slot(text, text, uuid) from public;
revoke all on function public.rpc_set_house_slot(text, text, uuid) from anon;
revoke all on function public.rpc_set_house_slot(text, text, uuid) from service_role;
grant execute on function public.rpc_set_house_slot(text, text, uuid) to authenticated;

revoke all on function public.rpc_clear_house_slot(text, text) from public;
revoke all on function public.rpc_clear_house_slot(text, text) from anon;
revoke all on function public.rpc_clear_house_slot(text, text) from service_role;
grant execute on function public.rpc_clear_house_slot(text, text) to authenticated;

revoke all on function public.rpc_publish_house() from public;
revoke all on function public.rpc_publish_house() from anon;
revoke all on function public.rpc_publish_house() from service_role;
grant execute on function public.rpc_publish_house() to authenticated;

revoke all on function public.rpc_unpublish_house() from public;
revoke all on function public.rpc_unpublish_house() from anon;
revoke all on function public.rpc_unpublish_house() from service_role;
grant execute on function public.rpc_unpublish_house() to authenticated;

revoke all on function public.rpc_get_public_house_slots_summary(uuid) from public;
revoke all on function public.rpc_get_public_house_slots_summary(uuid) from anon;
revoke all on function public.rpc_get_public_house_slots_summary(uuid) from service_role;
grant execute on function public.rpc_get_public_house_slots_summary(uuid) to authenticated;

commit;

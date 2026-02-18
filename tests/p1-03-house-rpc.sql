begin;

set local search_path = public, auth, pg_temp;

do $$
declare
  v_owner_id uuid := '44444444-4444-4444-4444-444444444444';
  v_viewer_id uuid := '55555555-5555-5555-5555-555555555555';
  v_catalog_toy_id uuid := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_current_item_id uuid := '44444444-4444-4444-4444-000000000001';
  v_old_item_id uuid := '44444444-4444-4444-4444-000000000002';

  v_resp jsonb;
  v_slots jsonb;
  v_slot jsonb;
  v_has_profile boolean;
  v_key text;
  v_forbidden_keys text[] := array[
    'inventory_item_id',
    'raw_text',
    'note',
    'meta',
    'avatar_key',
    'avatar_url',
    'catalog_item_id'
  ];
begin
  insert into auth.users (id, aud, role, email)
  values
    (v_owner_id, 'authenticated', 'authenticated', 'p1-03-owner@example.com'),
    (v_viewer_id, 'authenticated', 'authenticated', 'p1-03-viewer@example.com')
  on conflict (id) do nothing;

  update public.profiles
  set terms_agreed_at = now(),
      updated_at = now()
  where user_id in (v_owner_id, v_viewer_id);

  insert into public.catalog_items (id, type, standard_name, brand)
  values (v_catalog_toy_id, 'toy', 'P1-03 test toy', 'P1')
  on conflict (id) do update
  set type = excluded.type,
      standard_name = excluded.standard_name,
      brand = excluded.brand,
      updated_at = now();

  delete from public.house_slots where owner_id = v_owner_id;
  delete from public.house_profiles where user_id = v_owner_id;
  delete from public.inventory_items where owner_id = v_owner_id;

  insert into public.inventory_items (
    id,
    owner_id,
    type,
    catalog_item_id,
    raw_text,
    is_current,
    changed_at,
    ended_at,
    reason_code,
    created_at,
    updated_at,
    deleted_at
  )
  values
    (
      v_current_item_id,
      v_owner_id,
      'toy',
      v_catalog_toy_id,
      'P1-03 current toy',
      true,
      now(),
      null,
      'initial',
      now(),
      now(),
      null
    ),
    (
      v_old_item_id,
      v_owner_id,
      'toy',
      v_catalog_toy_id,
      'P1-03 old toy',
      false,
      now() - interval '1 day',
      now() - interval '1 hour',
      'initial',
      now(),
      now(),
      null
    );

  -- Smoke: slot bind lazily creates house_profile
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_set_house_slot(
    p_room_key => 'living_room',
    p_slot_key => 'slot_01',
    p_inventory_item_id => v_current_item_id
  )
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'rpc_set_house_slot smoke failed: %', v_resp;
  end if;

  select exists (
    select 1
    from public.house_profiles h
    where h.user_id = v_owner_id
  )
  into v_has_profile;

  if v_has_profile is not true then
    raise exception 'house_profiles lazy create failed';
  end if;

  -- Negative: non-current inventory item bind must be rejected
  select public.rpc_set_house_slot(
    p_room_key => 'living_room',
    p_slot_key => 'slot_02',
    p_inventory_item_id => v_old_item_id
  )
  into v_resp;

  if coalesce(v_resp->>'error_code', '') <> 'invalid_request' then
    raise exception 'expected invalid_request for non-current bind, got: %', v_resp;
  end if;

  -- Smoke: publish
  select public.rpc_publish_house()
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'rpc_publish_house smoke failed: %', v_resp;
  end if;

  if coalesce(v_resp->'house_profile'->>'visibility', '') <> 'public' then
    raise exception 'rpc_publish_house visibility must be public: %', v_resp;
  end if;

  if v_resp->'house_profile'->>'published_at' is null then
    raise exception 'rpc_publish_house published_at is null: %', v_resp;
  end if;

  -- Smoke: auth viewer can fetch public summary
  perform set_config('request.jwt.claim.sub', v_viewer_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_get_public_house_slots_summary(v_owner_id)
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'rpc_get_public_house_slots_summary smoke failed: %', v_resp;
  end if;

  v_slots := coalesce(v_resp->'slots', '[]'::jsonb);
  if jsonb_typeof(v_slots) <> 'array' then
    raise exception 'public summary slots must be array: %', v_resp;
  end if;

  -- T-4: whitelist only + forbidden fields absent
  for v_slot in
    select value
    from jsonb_array_elements(v_slots)
  loop
    for v_key in
      select key
      from jsonb_object_keys(v_slot) as key
    loop
      if v_key not in ('slot_key', 'equipped_at', 'type', 'standard_name') then
        raise exception 'public DTO includes non-whitelist key: % in %', v_key, v_slot;
      end if;
    end loop;

    foreach v_key in array v_forbidden_keys
    loop
      if v_slot ? v_key then
        raise exception 'public DTO leaked forbidden key % in %', v_key, v_slot;
      end if;
    end loop;
  end loop;

  -- Smoke: clear slot
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_clear_house_slot('living_room', 'slot_01')
  into v_resp;

  if coalesce((v_resp->>'success')::boolean, false) is distinct from true then
    raise exception 'rpc_clear_house_slot smoke failed: %', v_resp;
  end if;

  -- Smoke+policy: unpublish keeps visibility and hides public summary
  select public.rpc_unpublish_house()
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'rpc_unpublish_house smoke failed: %', v_resp;
  end if;

  if coalesce(v_resp->'house_profile'->>'visibility', '') <> 'public' then
    raise exception 'rpc_unpublish_house must keep visibility: %', v_resp;
  end if;

  if v_resp->'house_profile'->>'published_at' is not null then
    raise exception 'rpc_unpublish_house must null published_at: %', v_resp;
  end if;

  perform set_config('request.jwt.claim.sub', v_viewer_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_get_public_house_slots_summary(v_owner_id)
  into v_resp;

  if coalesce(v_resp->>'error_code', '') <> 'not_found' then
    raise exception 'unpublished house must return not_found: %', v_resp;
  end if;

  -- Negative: anon execute denied by grant policy
  if has_function_privilege(
    'anon',
    'public.rpc_get_public_house_slots_summary(uuid)',
    'EXECUTE'
  ) then
    raise exception 'anon must not have execute privilege on rpc_get_public_house_slots_summary';
  end if;

  raise notice 'PASS: p1-03 house rpc smoke + T-4 + negatives';
end;
$$;

rollback;

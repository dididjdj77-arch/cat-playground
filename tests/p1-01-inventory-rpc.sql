begin;

set local search_path = public, auth, pg_temp;

do $$
declare
  v_owner_id uuid := '11111111-1111-1111-1111-111111111111';
  v_terms_null_owner_id uuid := '22222222-2222-2222-2222-222222222222';
  v_catalog_food_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_catalog_toy_id uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  v_resp jsonb;
  v_first_id uuid;
  v_second_id uuid;
  v_current_count int;
  v_reason_code text;
  v_is_current boolean;
  v_ended_at timestamptz;
begin
  -- Test fixture users and catalog items
  insert into auth.users (id, aud, role, email)
  values
    (v_owner_id, 'authenticated', 'authenticated', 'p1-owner@example.com'),
    (v_terms_null_owner_id, 'authenticated', 'authenticated', 'p1-no-terms@example.com')
  on conflict (id) do nothing;

  update public.profiles
  set terms_agreed_at = now(),
      updated_at = now()
  where user_id = v_owner_id;

  insert into public.catalog_items (id, type, standard_name, brand)
  values
    (v_catalog_food_id, 'food', 'P1 test food', 'P1'),
    (v_catalog_toy_id, 'toy', 'P1 test toy', 'P1')
  on conflict (id) do update
  set type = excluded.type,
      standard_name = excluded.standard_name,
      brand = excluded.brand,
      updated_at = now();

  delete from public.inventory_items
  where owner_id in (v_owner_id, v_terms_null_owner_id);

  -- ------------------------------------------------------------
  -- Smoke: switch 1회 성공 (current 없으면 initial 생성)
  -- ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_inventory_switch(
    p_type => 'food',
    p_raw_text => 'P1 first food',
    p_catalog_item_id => v_catalog_food_id,
    p_changed_at => now(),
    p_reason_note => 'first insert'
  )
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'smoke switch(initial) failed: %', v_resp;
  end if;

  v_first_id := (v_resp->>'id')::uuid;
  if v_first_id is null then
    raise exception 'smoke switch(initial) missing id: %', v_resp;
  end if;

  select reason_code, is_current, ended_at
    into v_reason_code, v_is_current, v_ended_at
  from public.inventory_items
  where id = v_first_id;

  if v_reason_code <> 'initial' or v_is_current is distinct from true or v_ended_at is not null then
    raise exception 'initial row invariant failed: reason_code=%, is_current=%, ended_at=%', v_reason_code, v_is_current, v_ended_at;
  end if;

  -- ------------------------------------------------------------
  -- 불변식 회귀: switch 후 이전 row reason_code 불변
  -- ------------------------------------------------------------
  select public.rpc_inventory_switch(
    p_type => 'food',
    p_raw_text => 'P1 second food',
    p_catalog_item_id => v_catalog_food_id,
    p_changed_at => now(),
    p_reason_note => 'switch again'
  )
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'second switch failed: %', v_resp;
  end if;

  v_second_id := (v_resp->>'id')::uuid;

  select reason_code, is_current, ended_at
    into v_reason_code, v_is_current, v_ended_at
  from public.inventory_items
  where id = v_first_id;

  if v_reason_code <> 'initial' then
    raise exception 'reason_code changed unexpectedly on previous row: %', v_reason_code;
  end if;

  if v_is_current is distinct from false or v_ended_at is null then
    raise exception 'previous row not closed correctly: is_current=%, ended_at=%', v_is_current, v_ended_at;
  end if;

  select reason_code, is_current, ended_at
    into v_reason_code, v_is_current, v_ended_at
  from public.inventory_items
  where id = v_second_id;

  if v_reason_code <> 'switch' or v_is_current is distinct from true or v_ended_at is not null then
    raise exception 'new switch row invariant failed: reason_code=%, is_current=%, ended_at=%', v_reason_code, v_is_current, v_ended_at;
  end if;

  -- ------------------------------------------------------------
  -- Negative: dual current 방지 (동일 owner/type current는 항상 1개)
  -- ------------------------------------------------------------
  select count(*)
    into v_current_count
  from public.inventory_items
  where owner_id = v_owner_id
    and type = 'food'
    and is_current = true
    and deleted_at is null;

  if v_current_count <> 1 then
    raise exception 'dual current invariant violated after switches: current_count=%', v_current_count;
  end if;

  -- ------------------------------------------------------------
  -- Smoke: discontinue 1회 성공
  -- ------------------------------------------------------------
  select public.rpc_inventory_discontinue(
    p_type => 'food',
    p_reason_note => 'stop using'
  )
  into v_resp;

  if v_resp ? 'error_code' then
    raise exception 'smoke discontinue failed: %', v_resp;
  end if;

  if coalesce((v_resp->>'success')::boolean, false) is distinct from true then
    raise exception 'discontinue response malformed: %', v_resp;
  end if;

  select count(*)
    into v_current_count
  from public.inventory_items
  where owner_id = v_owner_id
    and type = 'food'
    and is_current = true
    and deleted_at is null;

  if v_current_count <> 0 then
    raise exception 'discontinue should leave zero current rows, got %', v_current_count;
  end if;

  -- ------------------------------------------------------------
  -- Negative: terms 미동의 write 거부
  -- ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', v_terms_null_owner_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  select public.rpc_inventory_switch(
    p_type => 'toy',
    p_raw_text => 'blocked by terms',
    p_catalog_item_id => v_catalog_toy_id,
    p_changed_at => now(),
    p_reason_note => null
  )
  into v_resp;

  if coalesce(v_resp->>'error_code', '') <> 'terms_not_agreed' then
    raise exception 'expected terms_not_agreed, got: %', v_resp;
  end if;

  -- ------------------------------------------------------------
  -- Stub contract: correction 미구현 에러 반환
  -- ------------------------------------------------------------
  select public.rpc_inventory_correction(
    p_type => 'toy',
    p_raw_text => 'unused',
    p_catalog_item_id => v_catalog_toy_id,
    p_changed_at => now(),
    p_reason_note => null
  )
  into v_resp;

  if coalesce(v_resp->>'error_code', '') <> 'invalid_request' then
    raise exception 'expected invalid_request from correction stub, got: %', v_resp;
  end if;

  if coalesce(v_resp->>'message', '') <> 'correction not implemented' then
    raise exception 'unexpected correction message: %', v_resp;
  end if;
end;
$$;

rollback;

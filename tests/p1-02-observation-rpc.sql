begin;

set local search_path = public, auth, pg_temp;

do $$
declare
  v_owner_id uuid := '33333333-3333-3333-3333-333333333333';
  v_cat_1 uuid := '33333333-3333-3333-3333-000000000001';
  v_cat_2 uuid := '33333333-3333-3333-3333-000000000002';
  v_inv_food uuid := '33333333-3333-3333-3333-000000000011';
  v_inv_toy uuid := '33333333-3333-3333-3333-000000000012';

  v_key_upsert uuid := '33333333-3333-4333-8333-000000000101';
  v_key_patch uuid := '33333333-3333-4333-8333-000000000201';
  v_key_patch_conflict uuid := '33333333-3333-4333-8333-000000000202';
  v_key_unknown uuid := '33333333-3333-4333-8333-000000000301';
  v_key_reject uuid := '33333333-3333-4333-8333-000000000302';
  v_key_overwrite_keep uuid := '33333333-3333-4333-8333-000000000303';
  v_key_overwrite_partial uuid := '33333333-3333-4333-8333-000000000304';
  v_key_overwrite_clear uuid := '33333333-3333-4333-8333-000000000305';

  v_resp_upsert jsonb;
  v_resp_upsert_replay jsonb;
  v_resp_patch jsonb;
  v_resp_patch_replay jsonb;
  v_resp_conflict jsonb;
  v_resp_future jsonb;
  v_resp_reject jsonb;
  v_resp_unknown jsonb;
  v_resp_invalid_key_log_date jsonb;

  v_group_id uuid;
  v_version_before_patch int;
  v_version_after_patch int;
  v_unknown_event_count int;
  v_unknown_rollup_count bigint;
  v_ref_count int;
begin
  insert into auth.users (id, aud, role, email)
  values (v_owner_id, 'authenticated', 'authenticated', 'p1-observation-owner@example.com')
  on conflict (id) do nothing;

  update public.profiles
  set terms_agreed_at = now(),
      updated_at = now()
  where user_id = v_owner_id;

  delete from public.observation_patch_dedup where owner_id = v_owner_id;
  delete from public.observation_inventory_refs where owner_id = v_owner_id;
  delete from public.observations where owner_id = v_owner_id;
  delete from public.observation_groups where owner_id = v_owner_id;
  delete from public.inventory_items where owner_id = v_owner_id;
  delete from public.cats where owner_id = v_owner_id;

  insert into public.cats (id, owner_id, name)
  values
    (v_cat_1, v_owner_id, 'P1 Cat One'),
    (v_cat_2, v_owner_id, 'P1 Cat Two');

  insert into public.inventory_items (
    id,
    owner_id,
    type,
    raw_text,
    is_current,
    changed_at,
    ended_at,
    reason_code,
    reason_note,
    meta
  )
  values
    (v_inv_food, v_owner_id, 'food', 'P1 food', true, now(), null, 'initial', null, '{}'::jsonb),
    (v_inv_toy, v_owner_id, 'toy', 'P1 toy', true, now(), null, 'initial', null, '{}'::jsonb);

  insert into public.payload_versions (version, state, meta)
  values
    ('1.0', 'ACTIVE', '{}'::jsonb),
    ('0.5', 'REJECT', '{}'::jsonb)
  on conflict (version) do update
  set state = excluded.state,
      meta = excluded.meta,
      updated_at = now();

  perform set_config('request.jwt.claim.sub', v_owner_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Smoke: upsert 1회 성공
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date,
    p_idempotency_key => v_key_upsert,
    p_common_payload => '{"weather":"sunny"}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active', 'override_payload', '{"mood":"ok"}'::jsonb),
      jsonb_build_object('cat_id', v_cat_2, 'status', 'active', 'override_payload', null)
    ),
    p_inventory_refs => jsonb_build_object('food', v_inv_food::text, 'toy', v_inv_toy::text)
  )
  into v_resp_upsert;

  if v_resp_upsert ? 'error_code' then
    raise exception 'smoke upsert failed: %', v_resp_upsert;
  end if;

  v_group_id := (v_resp_upsert ->> 'group_id')::uuid;
  v_version_before_patch := (v_resp_upsert ->> 'version')::int;
  if v_group_id is null or v_version_before_patch is null then
    raise exception 'smoke upsert malformed response: %', v_resp_upsert;
  end if;

  -- 멱등성 replay: 동일 idempotency_key는 동일 결과
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date,
    p_idempotency_key => v_key_upsert,
    p_common_payload => '{"weather":"rainy"}'::jsonb,
    p_items => '[]'::jsonb,
    p_inventory_refs => null
  )
  into v_resp_upsert_replay;

  if v_resp_upsert_replay is distinct from v_resp_upsert then
    raise exception 'upsert replay mismatch. first=%, replay=%', v_resp_upsert, v_resp_upsert_replay;
  end if;

  -- D-084: 동일 idempotency_key + 다른 log_date는 invalid_request
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date - 2,
    p_idempotency_key => v_key_upsert,
    p_common_payload => '{}'::jsonb,
    p_items => '[]'::jsonb,
    p_inventory_refs => null
  )
  into v_resp_invalid_key_log_date;

  if coalesce(v_resp_invalid_key_log_date ->> 'error_code', '') <> 'invalid_request' then
    raise exception 'expected invalid_request for same key different log_date, got: %', v_resp_invalid_key_log_date;
  end if;

  -- Smoke: patch 1회 성공
  select public.rpc_patch_observation_items(
    p_group_id => v_group_id,
    p_expected_version => v_version_before_patch,
    p_idempotency_key => v_key_patch,
    p_patches => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'excluded', 'override_payload', '{"mood":"tired"}'::jsonb)
    )
  )
  into v_resp_patch;

  if v_resp_patch ? 'error_code' then
    raise exception 'smoke patch failed: %', v_resp_patch;
  end if;

  v_version_after_patch := (v_resp_patch ->> 'version')::int;
  if v_version_after_patch <> v_version_before_patch + 1 then
    raise exception 'patch version increment failed: before=%, after=%', v_version_before_patch, v_version_after_patch;
  end if;

  -- Patch replay: 동일 (group_id, idempotency_key) 동일 result_json
  select public.rpc_patch_observation_items(
    p_group_id => v_group_id,
    p_expected_version => v_version_before_patch,
    p_idempotency_key => v_key_patch,
    p_patches => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_2, 'status', 'excluded')
    )
  )
  into v_resp_patch_replay;

  if v_resp_patch_replay is distinct from v_resp_patch then
    raise exception 'patch replay mismatch. first=%, replay=%', v_resp_patch, v_resp_patch_replay;
  end if;

  -- 409: expected_version mismatch
  select public.rpc_patch_observation_items(
    p_group_id => v_group_id,
    p_expected_version => v_version_before_patch,
    p_idempotency_key => v_key_patch_conflict,
    p_patches => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_2, 'status', 'excluded')
    )
  )
  into v_resp_conflict;

  if coalesce(v_resp_conflict ->> 'error_code', '') <> 'version_conflict' then
    raise exception 'expected version_conflict, got: %', v_resp_conflict;
  end if;

  if coalesce((v_resp_conflict ->> 'current_version')::int, -1) <> v_version_after_patch then
    raise exception 'version_conflict current_version mismatch: expected %, got %', v_version_after_patch, v_resp_conflict;
  end if;

  -- D-064 merge: NULL=keep
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date,
    p_idempotency_key => v_key_overwrite_keep,
    p_common_payload => '{"weather":"windy"}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active')
    ),
    p_inventory_refs => null
  )
  into v_resp_upsert;

  if v_resp_upsert ? 'error_code' then
    raise exception 'overwrite keep failed: %', v_resp_upsert;
  end if;

  v_group_id := (v_resp_upsert ->> 'group_id')::uuid;

  select count(*)
    into v_ref_count
  from public.observation_inventory_refs r
  where r.group_id = v_group_id
    and r.owner_id = v_owner_id;

  if v_ref_count <> 2 then
    raise exception 'D-064 NULL=keep failed, expected 2 refs, got %', v_ref_count;
  end if;

  -- D-064 merge: specific keys=upsert (others keep)
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date,
    p_idempotency_key => v_key_overwrite_partial,
    p_common_payload => '{"weather":"cloudy"}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active')
    ),
    p_inventory_refs => jsonb_build_object('food', v_inv_food::text)
  )
  into v_resp_upsert;

  if v_resp_upsert ? 'error_code' then
    raise exception 'overwrite partial failed: %', v_resp_upsert;
  end if;

  select count(*)
    into v_ref_count
  from public.observation_inventory_refs r
  where r.group_id = v_group_id
    and r.owner_id = v_owner_id;

  if v_ref_count <> 2 then
    raise exception 'D-064 partial upsert failed, expected 2 refs, got %', v_ref_count;
  end if;

  -- D-064 merge: {}=delete
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date,
    p_idempotency_key => v_key_overwrite_clear,
    p_common_payload => '{"weather":"clear"}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active')
    ),
    p_inventory_refs => '{}'::jsonb
  )
  into v_resp_upsert;

  if v_resp_upsert ? 'error_code' then
    raise exception 'overwrite clear failed: %', v_resp_upsert;
  end if;

  select count(*)
    into v_ref_count
  from public.observation_inventory_refs r
  where r.group_id = v_group_id
    and r.owner_id = v_owner_id;

  if v_ref_count <> 0 then
    raise exception 'D-064 clear failed, expected 0 refs, got %', v_ref_count;
  end if;

  -- Negative: future log_date 거부
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '1.0',
    p_log_date => current_date + 1,
    p_idempotency_key => '33333333-3333-4333-8333-000000000401'::uuid,
    p_common_payload => '{}'::jsonb,
    p_items => '[]'::jsonb,
    p_inventory_refs => null
  )
  into v_resp_future;

  if coalesce(v_resp_future ->> 'error_code', '') <> 'invalid_request' then
    raise exception 'expected invalid_request for future log_date, got: %', v_resp_future;
  end if;

  -- Negative: REJECT 상태 payload_version 거부
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '0.5',
    p_log_date => current_date - 1,
    p_idempotency_key => v_key_reject,
    p_common_payload => '{}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active')
    ),
    p_inventory_refs => null
  )
  into v_resp_reject;

  if coalesce(v_resp_reject ->> 'error_code', '') <> 'rejected_version' then
    raise exception 'expected rejected_version, got: %', v_resp_reject;
  end if;

  -- Unknown version: 저장 성공 + event_type='unknown' + rollups unknown_count 반영
  select public.rpc_upsert_observation_group_with_items(
    p_payload_version => '9.9',
    p_log_date => current_date - 3,
    p_idempotency_key => v_key_unknown,
    p_common_payload => '{}'::jsonb,
    p_items => jsonb_build_array(
      jsonb_build_object('cat_id', v_cat_1, 'status', 'active')
    ),
    p_inventory_refs => null
  )
  into v_resp_unknown;

  if v_resp_unknown ? 'error_code' then
    raise exception 'unknown payload_version should be accepted, got: %', v_resp_unknown;
  end if;

  select count(*)
    into v_unknown_event_count
  from public.payload_version_events e
  where e.version = '9.9'
    and e.event_type = 'unknown';

  if v_unknown_event_count < 1 then
    raise exception 'unknown payload_version event missing for version 9.9';
  end if;

  select coalesce(sum(r.unknown_count), 0)
    into v_unknown_rollup_count
  from public.payload_version_rollups r
  where r.version = '9.9';

  if v_unknown_rollup_count < 1 then
    raise exception 'payload_version_rollups unknown_count not reflected for version 9.9';
  end if;
end;
$$;

rollback;

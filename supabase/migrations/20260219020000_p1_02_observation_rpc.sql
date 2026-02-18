begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.validate_payload_version(
  p_version text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_state text;
  v_event_version text;
  v_now timestamptz := now();
  v_bucket_ts timestamptz := date_trunc('hour', v_now);
begin
  v_event_version := coalesce(nullif(btrim(p_version), ''), '<invalid>');

  if p_version is null or btrim(p_version) = '' or p_version !~ '^\d+\.\d+$' then
    insert into public.payload_version_events (ts, version, event_type, reason)
    values (v_now, v_event_version, 'normalize_fail', 'invalid_payload_version');

    insert into public.payload_version_rollups (
      version,
      bucket_ts,
      seen_count,
      reject_count,
      normalize_fail_count,
      unknown_count,
      last_seen_at
    )
    values (v_event_version, v_bucket_ts, 0, 0, 1, 0, v_now)
    on conflict (version, bucket_ts) do update
    set normalize_fail_count = public.payload_version_rollups.normalize_fail_count + 1,
        last_seen_at = greatest(public.payload_version_rollups.last_seen_at, excluded.last_seen_at);

    return jsonb_build_object('error_code', 'invalid_payload_version');
  end if;

  select pv.state
    into v_state
  from public.payload_versions pv
  where pv.version = p_version;

  if v_state is null then
    insert into public.payload_version_events (ts, version, event_type)
    values (v_now, p_version, 'unknown');

    insert into public.payload_version_rollups (
      version,
      bucket_ts,
      seen_count,
      reject_count,
      normalize_fail_count,
      unknown_count,
      last_seen_at
    )
    values (p_version, v_bucket_ts, 0, 0, 0, 1, v_now)
    on conflict (version, bucket_ts) do update
    set unknown_count = public.payload_version_rollups.unknown_count + 1,
        last_seen_at = greatest(public.payload_version_rollups.last_seen_at, excluded.last_seen_at);

    return jsonb_build_object('state', 'UNKNOWN');
  end if;

  if v_state = 'REJECT' then
    insert into public.payload_version_events (ts, version, event_type)
    values (v_now, p_version, 'reject');

    insert into public.payload_version_rollups (
      version,
      bucket_ts,
      seen_count,
      reject_count,
      normalize_fail_count,
      unknown_count,
      last_seen_at
    )
    values (p_version, v_bucket_ts, 0, 1, 0, 0, v_now)
    on conflict (version, bucket_ts) do update
    set reject_count = public.payload_version_rollups.reject_count + 1,
        last_seen_at = greatest(public.payload_version_rollups.last_seen_at, excluded.last_seen_at);

    return jsonb_build_object('error_code', 'rejected_version');
  end if;

  insert into public.payload_version_events (ts, version, event_type)
  values (v_now, p_version, 'seen');

  insert into public.payload_version_rollups (
    version,
    bucket_ts,
    seen_count,
    reject_count,
    normalize_fail_count,
    unknown_count,
    last_seen_at
  )
  values (p_version, v_bucket_ts, 1, 0, 0, 0, v_now)
  on conflict (version, bucket_ts) do update
  set seen_count = public.payload_version_rollups.seen_count + 1,
      last_seen_at = greatest(public.payload_version_rollups.last_seen_at, excluded.last_seen_at);

  return jsonb_build_object('state', v_state);
end;
$$;

create or replace function public.rpc_upsert_observation_group_with_items(
  p_payload_version text,
  p_log_date date,
  p_idempotency_key uuid,
  p_common_payload jsonb,
  p_items jsonb,
  p_inventory_refs jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_guard_result jsonb;
  v_validation_result jsonb;
  v_existing_group_id uuid;
  v_existing_log_date date;
  v_group_id uuid;
  v_group_version int;
  v_items jsonb;
  v_now timestamptz := now();
  v_item jsonb;
  v_cat_id uuid;
  v_status text;
  v_override_payload jsonb;
  v_ref_key text;
  v_ref_value jsonb;
  v_inventory_item_id uuid;
begin
  if v_owner_id is null then
    raise exception 'unauthorized';
  end if;

  v_guard_result := public.guard_terms_agreed();
  if v_guard_result is not null then
    return v_guard_result;
  end if;

  if p_log_date is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_idempotency_key is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_owner_id::text || ':' || p_log_date::text, 0));
  perform pg_advisory_xact_lock(hashtextextended(v_owner_id::text || ':' || p_idempotency_key::text, 0));

  select g.id, g.log_date
    into v_existing_group_id, v_existing_log_date
  from public.observation_groups g
  where g.owner_id = v_owner_id
    and g.idempotency_key = p_idempotency_key
    and g.deleted_at is null
  order by g.created_at desc
  limit 1;

  if v_existing_group_id is not null then
    if v_existing_log_date <> p_log_date then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    select g.version
      into v_group_version
    from public.observation_groups g
    where g.id = v_existing_group_id;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'cat_id', o.cat_id,
          'status', o.status,
          'override_payload', o.override_payload
        )
        order by o.created_at, o.id
      ),
      '[]'::jsonb
    )
      into v_items
    from public.observations o
    where o.group_id = v_existing_group_id
      and o.owner_id = v_owner_id
      and o.deleted_at is null;

    return jsonb_build_object(
      'group_id', v_existing_group_id,
      'version', v_group_version,
      'items', v_items
    );
  end if;

  v_validation_result := public.validate_payload_version(p_payload_version);
  if v_validation_result ? 'error_code' then
    return v_validation_result;
  end if;

  if p_log_date > current_date then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_inventory_refs is not null and jsonb_typeof(p_inventory_refs) <> 'object' then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    if not (v_item ? 'cat_id') then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    begin
      v_cat_id := (v_item ->> 'cat_id')::uuid;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;

    if not exists (
      select 1
      from public.cats c
      where c.id = v_cat_id
        and c.owner_id = v_owner_id
        and c.deleted_at is null
    ) then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    v_status := coalesce(v_item ->> 'status', 'active');
    if v_status not in ('active', 'excluded') then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;
  end loop;

  if p_inventory_refs is not null and p_inventory_refs <> '{}'::jsonb then
    for v_ref_key, v_ref_value in
      select key, value
      from jsonb_each(p_inventory_refs)
    loop
      if v_ref_key not in ('food', 'litter', 'toy', 'furniture') then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;

      if jsonb_typeof(v_ref_value) <> 'string' then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;

      begin
        v_inventory_item_id := (v_ref_value #>> '{}')::uuid;
      exception
        when others then
          return jsonb_build_object('error_code', 'invalid_request');
      end;

      if not exists (
        select 1
        from public.inventory_items i
        where i.id = v_inventory_item_id
          and i.owner_id = v_owner_id
          and i.deleted_at is null
      ) then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;
    end loop;
  end if;

  select g.id
    into v_group_id
  from public.observation_groups g
  where g.owner_id = v_owner_id
    and g.log_date = p_log_date
    and g.deleted_at is null
  for update;

  if v_group_id is null then
    insert into public.observation_groups (
      owner_id,
      log_date,
      payload_version,
      common_payload,
      version,
      idempotency_key,
      created_at,
      updated_at
    )
    values (
      v_owner_id,
      p_log_date,
      p_payload_version,
      coalesce(p_common_payload, '{}'::jsonb),
      1,
      p_idempotency_key,
      v_now,
      v_now
    )
    returning id, version
      into v_group_id, v_group_version;
  else
    update public.observation_groups g
    set payload_version = p_payload_version,
        common_payload = coalesce(p_common_payload, '{}'::jsonb),
        idempotency_key = p_idempotency_key,
        version = g.version + 1,
        updated_at = v_now
    where g.id = v_group_id
    returning version
      into v_group_version;

    delete from public.observations o
    where o.group_id = v_group_id
      and o.owner_id = v_owner_id;
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    if not (v_item ? 'cat_id') then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    begin
      v_cat_id := (v_item ->> 'cat_id')::uuid;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;

    if not exists (
      select 1
      from public.cats c
      where c.id = v_cat_id
        and c.owner_id = v_owner_id
        and c.deleted_at is null
    ) then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    v_status := coalesce(v_item ->> 'status', 'active');
    if v_status not in ('active', 'excluded') then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    if v_item ? 'override_payload' then
      v_override_payload := v_item -> 'override_payload';
    else
      v_override_payload := null;
    end if;

    insert into public.observations (
      group_id,
      owner_id,
      cat_id,
      status,
      override_payload,
      created_at,
      updated_at,
      deleted_at
    )
    values (
      v_group_id,
      v_owner_id,
      v_cat_id,
      v_status,
      v_override_payload,
      v_now,
      v_now,
      null
    )
    on conflict (group_id, cat_id) do update
    set owner_id = excluded.owner_id,
        status = excluded.status,
        override_payload = excluded.override_payload,
        updated_at = excluded.updated_at,
        deleted_at = null;
  end loop;

  if p_inventory_refs is null then
    null;
  elsif p_inventory_refs = '{}'::jsonb then
    delete from public.observation_inventory_refs r
    where r.group_id = v_group_id
      and r.owner_id = v_owner_id;
  else
    for v_ref_key, v_ref_value in
      select key, value
      from jsonb_each(p_inventory_refs)
    loop
      v_inventory_item_id := (v_ref_value #>> '{}')::uuid;

      insert into public.observation_inventory_refs (
        owner_id,
        group_id,
        inv_type,
        inventory_item_id,
        created_at
      )
      values (
        v_owner_id,
        v_group_id,
        v_ref_key,
        v_inventory_item_id,
        v_now
      )
      on conflict (group_id, inv_type) do update
      set owner_id = excluded.owner_id,
          inventory_item_id = excluded.inventory_item_id;
    end loop;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'cat_id', o.cat_id,
        'status', o.status,
        'override_payload', o.override_payload
      )
      order by o.created_at, o.id
    ),
    '[]'::jsonb
  )
    into v_items
  from public.observations o
  where o.group_id = v_group_id
    and o.owner_id = v_owner_id
    and o.deleted_at is null;

  return jsonb_build_object(
    'group_id', v_group_id,
    'version', v_group_version,
    'items', v_items
  );
end;
$$;

create or replace function public.rpc_patch_observation_items(
  p_group_id uuid,
  p_expected_version int,
  p_idempotency_key uuid,
  p_patches jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_guard_result jsonb;
  v_existing_result jsonb;
  v_current_version int;
  v_new_version int;
  v_now timestamptz := now();
  v_patch jsonb;
  v_cat_id uuid;
  v_status text;
  v_has_status boolean;
  v_has_override_payload boolean;
  v_result jsonb;
begin
  if v_owner_id is null then
    raise exception 'unauthorized';
  end if;

  v_guard_result := public.guard_terms_agreed();
  if v_guard_result is not null then
    return v_guard_result;
  end if;

  if p_group_id is null or p_expected_version is null or p_idempotency_key is null then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  if p_patches is null or jsonb_typeof(p_patches) <> 'array' then
    return jsonb_build_object('error_code', 'invalid_request');
  end if;

  select d.result_json
    into v_existing_result
  from public.observation_patch_dedup d
  where d.owner_id = v_owner_id
    and d.group_id = p_group_id
    and d.idempotency_key = p_idempotency_key;

  if v_existing_result is not null then
    return v_existing_result;
  end if;

  select g.version
    into v_current_version
  from public.observation_groups g
  where g.id = p_group_id
    and g.owner_id = v_owner_id
    and g.deleted_at is null
  for update;

  if v_current_version is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  select d.result_json
    into v_existing_result
  from public.observation_patch_dedup d
  where d.owner_id = v_owner_id
    and d.group_id = p_group_id
    and d.idempotency_key = p_idempotency_key;

  if v_existing_result is not null then
    return v_existing_result;
  end if;

  if p_expected_version <> v_current_version then
    return jsonb_build_object(
      'error_code', 'version_conflict',
      'current_version', v_current_version
    );
  end if;

  for v_patch in
    select value
    from jsonb_array_elements(p_patches)
  loop
    if jsonb_typeof(v_patch) <> 'object' or not (v_patch ? 'cat_id') then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    begin
      v_cat_id := (v_patch ->> 'cat_id')::uuid;
    exception
      when others then
        return jsonb_build_object('error_code', 'invalid_request');
    end;

    v_has_status := v_patch ? 'status';
    v_has_override_payload := v_patch ? 'override_payload';

    if v_has_status then
      v_status := v_patch ->> 'status';
      if v_status not in ('active', 'excluded') then
        return jsonb_build_object('error_code', 'invalid_request');
      end if;
    else
      v_status := null;
    end if;

    if not v_has_status and not v_has_override_payload then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;

    update public.observations o
    set status = case when v_has_status then v_status else o.status end,
        override_payload = case when v_has_override_payload then v_patch -> 'override_payload' else o.override_payload end,
        updated_at = v_now
    where o.group_id = p_group_id
      and o.owner_id = v_owner_id
      and o.cat_id = v_cat_id
      and o.deleted_at is null;

    if not found then
      return jsonb_build_object('error_code', 'invalid_request');
    end if;
  end loop;

  update public.observation_groups g
  set version = g.version + 1,
      updated_at = v_now
  where g.id = p_group_id
  returning g.version
    into v_new_version;

  select jsonb_build_object(
    'group_id', p_group_id,
    'version', v_new_version,
    'items', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'cat_id', o.cat_id,
          'status', o.status,
          'override_payload', o.override_payload
        )
        order by o.created_at, o.id
      ),
      '[]'::jsonb
    )
  )
    into v_result
  from public.observations o
  where o.group_id = p_group_id
    and o.owner_id = v_owner_id
    and o.deleted_at is null;

  insert into public.observation_patch_dedup (
    owner_id,
    group_id,
    idempotency_key,
    result_json,
    created_at
  )
  values (
    v_owner_id,
    p_group_id,
    p_idempotency_key,
    v_result,
    v_now
  )
  on conflict (owner_id, group_id, idempotency_key) do nothing;

  if not found then
    select d.result_json
      into v_existing_result
    from public.observation_patch_dedup d
    where d.owner_id = v_owner_id
      and d.group_id = p_group_id
      and d.idempotency_key = p_idempotency_key;

    if v_existing_result is not null then
      return v_existing_result;
    end if;
  end if;

  return v_result;
end;
$$;

revoke all on function public.validate_payload_version(text) from public;
revoke all on function public.validate_payload_version(text) from anon;
revoke all on function public.validate_payload_version(text) from authenticated;
revoke all on function public.validate_payload_version(text) from service_role;

revoke all on function public.rpc_upsert_observation_group_with_items(text, date, uuid, jsonb, jsonb, jsonb) from public;
revoke all on function public.rpc_upsert_observation_group_with_items(text, date, uuid, jsonb, jsonb, jsonb) from anon;
revoke all on function public.rpc_upsert_observation_group_with_items(text, date, uuid, jsonb, jsonb, jsonb) from service_role;
grant execute on function public.rpc_upsert_observation_group_with_items(text, date, uuid, jsonb, jsonb, jsonb) to authenticated;

revoke all on function public.rpc_patch_observation_items(uuid, int, uuid, jsonb) from public;
revoke all on function public.rpc_patch_observation_items(uuid, int, uuid, jsonb) from anon;
revoke all on function public.rpc_patch_observation_items(uuid, int, uuid, jsonb) from service_role;
grant execute on function public.rpc_patch_observation_items(uuid, int, uuid, jsonb) to authenticated;

commit;

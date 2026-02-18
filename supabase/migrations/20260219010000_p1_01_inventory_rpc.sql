begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.rpc_inventory_switch(
  p_type text,
  p_raw_text text,
  p_catalog_item_id uuid default null,
  p_changed_at timestamptz default now(),
  p_reason_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_guard_error jsonb;
  v_now timestamptz := now();
  v_catalog_type text;
  v_current public.inventory_items%rowtype;
  v_new_item public.inventory_items%rowtype;
begin
  -- D-096: guard_terms_agreed -> domain guard
  v_guard_error := public.guard_terms_agreed();
  if v_guard_error is not null then
    return v_guard_error;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth required');
  end if;

  if p_type not in ('food', 'litter', 'toy', 'furniture') then
    return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'invalid type');
  end if;

  if p_changed_at is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'changed_at is required');
  end if;

  if char_length(btrim(coalesce(p_raw_text, ''))) < 1
     or char_length(p_raw_text) > 200 then
    return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'raw_text length must be 1..200');
  end if;

  if p_reason_note is not null and char_length(p_reason_note) > 500 then
    return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'reason_note max length is 500');
  end if;

  if p_catalog_item_id is not null then
    select c.type
      into v_catalog_type
    from public.catalog_items c
    where c.id = p_catalog_item_id;

    if v_catalog_type is null then
      return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'catalog item not found');
    end if;

    if v_catalog_type <> p_type then
      return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'catalog item type mismatch');
    end if;
  end if;

  -- Serialize by owner/type to keep current 0..1 invariant under concurrency.
  perform pg_advisory_xact_lock(hashtextextended(v_owner_id::text || ':' || p_type, 0));

  select i.*
    into v_current
  from public.inventory_items i
  where i.owner_id = v_owner_id
    and i.type = p_type
    and i.is_current = true
    and i.deleted_at is null
  order by i.created_at desc
  limit 1
  for update;

  if found then
    update public.inventory_items
    set ended_at = v_now,
        is_current = false,
        updated_at = v_now
    where id = v_current.id;

    insert into public.inventory_items (
      owner_id,
      type,
      catalog_item_id,
      raw_text,
      is_current,
      changed_at,
      ended_at,
      reason_code,
      reason_note,
      created_at,
      updated_at,
      deleted_at
    )
    values (
      v_owner_id,
      p_type,
      p_catalog_item_id,
      p_raw_text,
      true,
      p_changed_at,
      null,
      'switch',
      p_reason_note,
      v_now,
      v_now,
      null
    )
    returning * into v_new_item;
  else
    -- D-057/D-075: no current item means initial registration.
    insert into public.inventory_items (
      owner_id,
      type,
      catalog_item_id,
      raw_text,
      is_current,
      changed_at,
      ended_at,
      reason_code,
      reason_note,
      created_at,
      updated_at,
      deleted_at
    )
    values (
      v_owner_id,
      p_type,
      p_catalog_item_id,
      p_raw_text,
      true,
      p_changed_at,
      null,
      'initial',
      p_reason_note,
      v_now,
      v_now,
      null
    )
    returning * into v_new_item;
  end if;

  return to_jsonb(v_new_item);
end;
$$;

create or replace function public.rpc_inventory_discontinue(
  p_type text,
  p_reason_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_guard_error jsonb;
  v_now timestamptz := now();
  v_current_id uuid;
begin
  -- D-096: guard_terms_agreed -> domain guard
  v_guard_error := public.guard_terms_agreed();
  if v_guard_error is not null then
    return v_guard_error;
  end if;

  if v_owner_id is null then
    return jsonb_build_object('error_code', 'invalid_request', 'message', 'auth required');
  end if;

  if p_type not in ('food', 'litter', 'toy', 'furniture') then
    return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'invalid type');
  end if;

  if p_reason_note is not null and char_length(p_reason_note) > 500 then
    return jsonb_build_object('error_code', 'invalid_inventory_item', 'message', 'reason_note max length is 500');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_owner_id::text || ':' || p_type, 0));

  select i.id
    into v_current_id
  from public.inventory_items i
  where i.owner_id = v_owner_id
    and i.type = p_type
    and i.is_current = true
    and i.deleted_at is null
  order by i.created_at desc
  limit 1
  for update;

  if v_current_id is null then
    return jsonb_build_object('error_code', 'not_found');
  end if;

  update public.inventory_items
  set ended_at = v_now,
      is_current = false,
      updated_at = v_now
  where id = v_current_id;

  return jsonb_build_object(
    'success', true,
    'type', p_type,
    'discontinued_at', v_now
  );
end;
$$;

create or replace function public.rpc_inventory_correction(
  p_type text,
  p_raw_text text,
  p_catalog_item_id uuid default null,
  p_changed_at timestamptz default now(),
  p_reason_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Reference parameters to satisfy plpgsql lint (stub)
  perform p_type, p_raw_text, p_catalog_item_id, p_changed_at, p_reason_note;
  return jsonb_build_object(
    'error_code', 'invalid_request',
    'message', 'correction not implemented'
  );
end;
$$;

revoke all on function public.rpc_inventory_switch(text, text, uuid, timestamptz, text) from public;
revoke all on function public.rpc_inventory_switch(text, text, uuid, timestamptz, text) from anon;
revoke all on function public.rpc_inventory_switch(text, text, uuid, timestamptz, text) from service_role;
grant execute on function public.rpc_inventory_switch(text, text, uuid, timestamptz, text) to authenticated;

revoke all on function public.rpc_inventory_discontinue(text, text) from public;
revoke all on function public.rpc_inventory_discontinue(text, text) from anon;
revoke all on function public.rpc_inventory_discontinue(text, text) from service_role;
grant execute on function public.rpc_inventory_discontinue(text, text) to authenticated;

revoke all on function public.rpc_inventory_correction(text, text, uuid, timestamptz, text) from public;
revoke all on function public.rpc_inventory_correction(text, text, uuid, timestamptz, text) from anon;
revoke all on function public.rpc_inventory_correction(text, text, uuid, timestamptz, text) from service_role;
grant execute on function public.rpc_inventory_correction(text, text, uuid, timestamptz, text) to authenticated;

commit;

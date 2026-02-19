begin;

set local search_path = public, auth, pg_temp;

do $$
declare
  v_user_id uuid := '77777777-7777-7777-7777-777777777771';
  v_other_user_id uuid := '78888888-8888-8888-8888-888888888882';
  v_notif_id uuid;
  v_result jsonb;
begin
  -- Fixture: insert test users into auth.users (triggers profile bootstrap)
  insert into auth.users (id, aud, role, email)
  values
    (v_user_id, 'authenticated', 'authenticated', 'p1-07-owner@example.com'),
    (v_other_user_id, 'authenticated', 'authenticated', 'p1-07-other@example.com')
  on conflict (id) do nothing;

  -- Set terms_agreed for primary user
  update public.profiles
  set terms_agreed_at = now(),
      nickname = 'testnick_p107a',
      nickname_changed_at = now(),
      updated_at = now()
  where user_id = v_user_id;

  update public.profiles
  set terms_agreed_at = now(),
      updated_at = now()
  where user_id = v_other_user_id;

  -- Set JWT claims for authenticated RPC calls
  perform set_config('request.jwt.claim.sub', v_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);

  -- Smoke: agree_terms sets terms_agreed_at (idempotent)
  v_result := public.rpc_agree_terms();
  if (v_result ->> 'terms_agreed_at') is null then
    raise exception 'rpc_agree_terms failed: %', v_result;
  end if;

  -- Smoke: get_notifications works and returns array
  insert into public.notifications (user_id, type, actor_id, target_type, target_id, created_at)
  values (v_user_id, 'like', v_other_user_id, 'post', gen_random_uuid(), now())
  returning id into v_notif_id;

  v_result := public.rpc_get_notifications(null, 20);
  if jsonb_typeof(v_result -> 'notifications') <> 'array' then
    raise exception 'rpc_get_notifications failed: %', v_result;
  end if;

  -- Negative: terms 미동의 상태에서 update_profile 거부
  update public.profiles
  set terms_agreed_at = null
  where user_id = v_user_id;

  v_result := public.rpc_update_profile('ignored_nickname', 'new bio from test', null);
  if (v_result ->> 'error_code') <> 'terms_not_agreed' then
    raise exception 'rpc_update_profile should reject pre-terms: %', v_result;
  end if;

  -- read RPC 예외 확인: pre-terms 상태에서도 get_notifications 가능
  v_result := public.rpc_get_notifications(null, 20);
  if (v_result ->> 'error_code') is not null then
    raise exception 'rpc_get_notifications must be allowed pre-terms: %', v_result;
  end if;

  -- mark_* write RPC는 pre-terms에서 차단
  v_result := public.rpc_mark_notification_read(v_notif_id);
  if (v_result ->> 'error_code') <> 'terms_not_agreed' then
    raise exception 'rpc_mark_notification_read should reject pre-terms: %', v_result;
  end if;

  v_result := public.rpc_mark_all_notifications_read();
  if (v_result ->> 'error_code') <> 'terms_not_agreed' then
    raise exception 'rpc_mark_all_notifications_read should reject pre-terms: %', v_result;
  end if;

  -- terms 복구 후 nickname silently ignored 검증
  perform public.rpc_agree_terms();

  update public.profiles
  set nickname = 'testnick_' || substr(replace(v_user_id::text, '-', ''), 1, 8),
      nickname_changed_at = now(),
      bio = null
  where user_id = v_user_id;

  v_result := public.rpc_update_profile('should_be_ignored', 'bio_after_update', null);
  if (v_result -> 'profile' ->> 'nickname') = 'should_be_ignored' then
    raise exception 'p_nickname must be silently ignored in rpc_update_profile: %', v_result;
  end if;

  if (v_result -> 'profile' ->> 'bio') <> 'bio_after_update' then
    raise exception 'bio should be updated in rpc_update_profile: %', v_result;
  end if;

  raise notice 'PASS: p1-07 profile/notif rpc smoke+negative';
end;
$$;

rollback;

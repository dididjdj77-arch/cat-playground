begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

create or replace function public.fn_bootstrap_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_nickname text;
begin
  v_nickname := 'user_' || substr(replace(new.id::text, '-', ''), 1, 14);

  insert into public.profiles (user_id, nickname, created_at, updated_at)
  values (new.id, v_nickname, now(), now())
  on conflict (user_id) do update
  set updated_at = now();

  return new;
exception
  when others then
    raise log 'fn_bootstrap_profile_from_auth_user failed for user_id %, sqlstate %, error %',
      new.id,
      sqlstate,
      sqlerrm;
    return new;
end;
$$;

revoke all on function public.fn_bootstrap_profile_from_auth_user() from public;

drop trigger if exists trg_auth_users_profile_bootstrap on auth.users;

create trigger trg_auth_users_profile_bootstrap
after insert on auth.users
for each row
execute function public.fn_bootstrap_profile_from_auth_user();

commit;

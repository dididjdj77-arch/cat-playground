# Playbook: Ops App Config

> 이 문서는 app_config 운영 파라미터 저장/조회 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-056, CONFIG-BASELINES.md

## 체크리스트

### Do
- [ ] `app_config(key text primary key, value jsonb, updated_at, updated_by)` 구조를 사용한다.
- [ ] 읽기 RPC는 `rpc_get_app_config(p_keys text[]) returns jsonb` 형태를 사용한다.
- [ ] whitelist key(`rate_limits`, `rate_limits_new_account`, `auto_hide`, `popular_feed`)만 반환한다.
- [ ] unknown key는 에러 대신 무시한다.
- [ ] RPC는 `SECURITY DEFINER` + auth-only로 제한한다.
- [ ] 함수 내부에서 `auth.uid() is null` 호출을 명시적으로 거부한다.
- [ ] 인증/권한 실패 에러 표현은 `docs/API.md` 표준 에러 체계와 정합되게 유지한다.
- [ ] 초기 seed는 CONFIG-BASELINES 기준값으로 맞춘다(예시 값은 샘플).

### Don't
- [ ] 토큰/비밀키를 app_config에 저장하지 않는다.
- [ ] 클라이언트에 원본 테이블 direct SELECT를 열지 않는다.
- [ ] anon 접근을 허용하지 않는다.

## Access Control

- app_config 원본 테이블은 anon/authenticated에 direct SELECT를 열지 않는다.
- `rpc_get_app_config` 실행 권한은 authenticated 전용으로 두고 PUBLIC은 revoke 한다.
- service/ops 경로에서 사용자 세션 없이 읽기가 필요할 때만 service_role EXECUTE를 추가한다.
- 예시 role명(`anon`, `authenticated`, `service_role`)은 프로젝트 표준 역할명 기준으로 적용한다.

```sql
revoke all on table public.app_config from anon, authenticated;

revoke all on function public.rpc_get_app_config(text[]) from public;
grant execute on function public.rpc_get_app_config(text[]) to authenticated;
-- 필요 시에만:
-- grant execute on function public.rpc_get_app_config(text[]) to service_role;
```

## 템플릿

> 참고: 아래 DDL의 `if not exists`는 playbook 예시다. 실제 migration 적용 시 fail-fast/idempotent 선택 기준은 `docs/playbooks/migrations.md`를 따른다.

```sql
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid null
);

create or replace function public.rpc_get_app_config(p_keys text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'auth required';
  end if;

  with requested as (
    select unnest(coalesce(p_keys, array[]::text[])) as key
  ),
  allowed as (
    select key
    from requested
    where key in ('rate_limits', 'rate_limits_new_account', 'auto_hide', 'popular_feed')
  )
  select coalesce(jsonb_object_agg(c.key, c.value), '{}'::jsonb)
    into v_result
  from public.app_config c
  join allowed a on a.key = c.key;

  return v_result;
end;
$$;

revoke all on function public.rpc_get_app_config(text[]) from public;
grant execute on function public.rpc_get_app_config(text[]) to authenticated;
-- 필요 시에만:
-- grant execute on function public.rpc_get_app_config(text[]) to service_role;

-- ⚠️ 아래 값은 playbook 예시(샘플)이다.
-- 실제 seed는 반드시 CONFIG-BASELINES.md의 수치와 정합시킨다.
-- CONFIG-BASELINES 수치와 다른 값을 seed하면 운영 파라미터 불일치가 발생한다.
insert into public.app_config (key, value)
values
  ('rate_limits', '{"posts":{"per_min":2,"per_day":20}}'::jsonb),
  ('rate_limits_new_account', '{"posts":{"per_min":1,"per_day":5}}'::jsonb),
  ('auto_hide', '{"threshold_n":5,"window_hours":24,"trust_days":7}'::jsonb),
  ('popular_feed', '{"like_weight":1,"reply_weight":2,"window_days":7}'::jsonb)
on conflict (key) do nothing;
```

## Environment Matrix

> 목적: dev/staging/prod 환경에서 필요한 설정 "필드"를 고정한다.
> 원칙: 값은 Phase 0.9에서 채우며, 이 문서에는 실제 비밀값을 기록하지 않는다.

| 필드 | dev | staging | prod | 저장 위치 | 권한 경계 |
|------|-----|---------|------|-----------|-----------|
| Supabase URL | TBD | TBD | TBD | Supabase Dashboard 또는 서버 환경변수 | 공개 가능(서비스 endpoint) |
| Supabase anon key | TBD | TBD | TBD | 서버/앱 환경변수(.env.*) | 공개 가능(anon) |
| Supabase service_role key | TBD | TBD | TBD | 서버 전용 비밀 저장소(Secrets Manager/Vault) | 서버 전용, 클라이언트 노출 금지 |
| OAuth redirect URI | TBD | TBD | TBD | OAuth Provider Console + 앱/웹 설정 문서 | 공개 가능(URI), 임의 변경 금지 |
| Expo scheme | TBD | TBD | TBD | Expo app config(`app.json`/`app.config.*`) | 공개 가능(딥링크 식별자) |
| Next.js domain | TBD | TBD | TBD | 배포 플랫폼 프로젝트 설정 | 공개 가능(도메인) |
| app_config key: `rate_limits` | TBD | TBD | TBD | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `rate_limits_new_account` | TBD | TBD | TBD | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `auto_hide` | TBD | TBD | TBD | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `popular_feed` | TBD | TBD | TBD | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |

### Environment Matrix 체크리스트

- [ ] 모든 필드의 값은 `TBD`로 유지한다(실값/토큰/비밀번호 기록 금지).
- [ ] 비밀 필드는 저장 위치를 "서버 전용 비밀 저장소"로 기록하고 클라이언트 노출 금지를 명시한다.
- [ ] OAuth redirect URI / Expo scheme / Next.js domain을 환경별(dev/staging/prod)로 모두 채울 수 있는 자리만 확보한다.
- [ ] app_config 수치 근거는 `docs/CONFIG-BASELINES.md`를 따르고, 키 목록은 D-056 whitelist와 정합시킨다.

## 검증

### 스모크 테스트

```sql
select public.rpc_get_app_config(array['rate_limits','auto_hide']);
```

### 네거티브 테스트

```sql
-- unknown key는 무시되고 known key만 반환되는지 확인
select public.rpc_get_app_config(array['rate_limits','unknown_key']);

-- anon role로 호출 시 거부되는지 확인
```

## 근거 링크
- See: DECISIONS D-056
- See: docs/CONFIG-BASELINES.md#3-app_config-key-매핑-d-056
- See: docs/DECISIONS.md#d-053-레이트리밋-v1-기본값
- See: docs/DECISIONS.md#d-054-조건부-자동숨김신고-기반-v1-임계치신뢰-조건

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
> P0.9-02 적용 원칙: 레포 근거가 있는 값은 실제 키/기본값으로 채우고, 근거가 없는 항목은 `TBD (OPEN)`으로 남긴다.
> 비밀값은 평문으로 기록하지 않고, 키 이름/저장 위치/권한 경계만 기록한다.

| 필드 | dev | staging | prod | 저장 위치 | 권한 경계 |
|------|-----|---------|------|-----------|-----------|
| Supabase URL | `LOCAL_SUPABASE_URL=http://127.0.0.1:54321` | `STAGING_SUPABASE_URL=https://your-staging-project-ref.supabase.co` | `PROD_SUPABASE_URL=https://your-prod-project-ref.supabase.co` | `.env.example` + 런타임 `.env` | 공개 가능(서비스 endpoint) |
| Supabase anon key | `LOCAL_SUPABASE_ANON_KEY` | `STAGING_SUPABASE_ANON_KEY` | `PROD_SUPABASE_ANON_KEY` | `.env.example` + 런타임 `.env` | 공개 가능(anon) |
| Supabase service_role key | `LOCAL_SUPABASE_SERVICE_ROLE_KEY` | `STAGING_SUPABASE_SERVICE_ROLE_KEY` | `PROD_SUPABASE_SERVICE_ROLE_KEY` | `.env.example` + 서버 전용 비밀 저장소 | 서버 전용, 클라이언트 노출 금지 |
| OAuth redirect URI (Expo Auth Spike) | `<EXPO_PUBLIC_AUTH_REDIRECT_SCHEME>://auth/callback` | `<EXPO_PUBLIC_AUTH_REDIRECT_SCHEME>://auth/callback` | `<EXPO_PUBLIC_AUTH_REDIRECT_SCHEME>://auth/callback` | `apps/expo/src/auth-spike/oauth.ts` + `apps/expo/.env.example` | 공개 가능(URI), 임의 변경 금지 |
| Expo scheme | `LOCAL_EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` -> `EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` | `STAGING_EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` -> `EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` | `PROD_EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` -> `EXPO_PUBLIC_AUTH_REDIRECT_SCHEME` | `.env.example` + `apps/expo/.env.example` | 공개 가능(딥링크 식별자) |
| Next.js domain | `LOCAL_NEXT_PUBLIC_SITE_URL=https://localhost:3000` | `STAGING_NEXT_PUBLIC_SITE_URL=<staging-next-domain>` | `PROD_NEXT_PUBLIC_SITE_URL=<prod-next-domain>` | `.env.example` + 배포 플랫폼 프로젝트 설정 | 공개 가능(도메인) |
| robots/sitemap base URL | `https://localhost:3000` | `TBD (OPEN)` | `TBD (OPEN)` | dev 근거: `docs/playbooks/seo-web.md`; staging/prod는 배포 도메인 확정 후 기록 | 공개 가능(URL) |
| ISR revalidate secret | `LOCAL_REVALIDATE_SECRET` | `STAGING_REVALIDATE_SECRET` | `PROD_REVALIDATE_SECRET` | `.env.example` + 서버 전용 비밀 저장소 (`REVALIDATE_SECRET`) | 서버 전용, 클라이언트 노출 금지 |
| app_config key: `rate_limits` | `public.app_config.rate_limits` | `public.app_config.rate_limits` | `public.app_config.rate_limits` | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `rate_limits_new_account` | `public.app_config.rate_limits_new_account` | `public.app_config.rate_limits_new_account` | `public.app_config.rate_limits_new_account` | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `auto_hide` | `public.app_config.auto_hide` | `public.app_config.auto_hide` | `public.app_config.auto_hide` | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |
| app_config key: `popular_feed` | `public.app_config.popular_feed` | `public.app_config.popular_feed` | `public.app_config.popular_feed` | `public.app_config` (`rpc_get_app_config` 경유) | authenticated RPC 읽기 전용 |

### Environment Matrix 체크리스트

- [ ] 비밀값 평문을 기록하지 않고, 키 이름/저장 위치/권한 경계만 기록한다.
- [ ] 환경별로 `*_SUPABASE_*`, `*_EXPO_PUBLIC_AUTH_REDIRECT_SCHEME`, `*_NEXT_PUBLIC_SITE_URL`, `*_REVALIDATE_SECRET` 키를 채운다.
- [ ] OAuth redirect URI는 `<EXPO_PUBLIC_AUTH_REDIRECT_SCHEME>://auth/callback` 규칙으로 기록하고, provider 콘솔 값과 일치시킨다.
- [ ] app_config 수치 근거는 `docs/CONFIG-BASELINES.md`를 따르고, 키 목록은 D-056 whitelist와 정합시킨다.
- [ ] 레포 근거가 없는 값은 `TBD (OPEN)`으로 남기고 배포 환경 확정 시 업데이트한다.

### AS-5 환경별 재현 체크리스트 (로그인 -> 세션 확인)

- [ ] 실행 환경(dev/staging/prod)별로 Env Matrix 값을 주입한 뒤 Expo 앱을 실행한다.
- [ ] iOS/Android 각각 `AS-1`(로그인), `AS-2`(redirect/deeplink), `AS-3`(세션 복구), `AS-4`(auth-only RPC)를 1회 이상 통과시킨다.
- [ ] 네거티브 1건 이상(로그인 취소/네트워크 오류/unknown key RPC)을 재현하고 결과를 기록한다.
- [ ] 증거(스크린샷/로그)에는 실행 환경, 실행 시각, 사용한 설정 키 범위를 함께 남긴다.

### OPEN (P0.9-02)

- [ ] staging/prod의 실제 Next.js domain 및 robots/sitemap base URL은 레포에 확정값이 없으므로 `TBD (OPEN)` 상태다.
- [ ] provider별 OAuth redirect URI 실값(Apple/Kakao/Google 콘솔)은 운영 콘솔 확정 후 동일 섹션에 반영한다.

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

# Playbook: Payload Version KPI

> 이 문서는 payload_version 상태 머신, KPI 이벤트/롤업 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-028, D-042, D-045, D-089, ADR-006

## 체크리스트

### Do
- [ ] payload_version은 semver 형태(예: `1.0`, `1.1`)로 검증한다 (ADR-006).
- [ ] payload 최소 골격 검증(필수 키/타입)은 D-042 규칙을 따른다.
- [ ] 상태 머신: `ACTIVE | DEPRECATED | REJECT`.
- [ ] `REJECT` 버전은 저장을 거부한다.
- [ ] `ACTIVE/DEPRECATED`는 저장을 허용한다.
- [ ] unknown payload_version은 D-089에 따라 저장을 허용하고 `payload_version_events`에 `event_type='unknown'`으로 기록한다.
- [ ] KPI 이벤트는 append-only 로그(`payload_version_events`)로 기록한다 (핫패스 카운터 UPDATE 금지, ADR-006).
- [ ] 이벤트 타입은 `seen/reject/normalize_fail/unknown`을 사용한다.
- [ ] 롤업(`payload_version_rollups`)은 배치/cron으로 집계한다.
- [ ] `payload_version_events`는 90일 보관 후 삭제하고(D-045), rollups는 장기 보존한다.
- [ ] unknown payload_version 처리는 D-089를 SSOT로 따른다.

### Don't
- [ ] `payload_versions` 단일 row에 `seen_count++` 같은 카운터 UPDATE를 하지 않는다.
- [ ] `REJECT` 상태 payload를 저장하지 않는다.
- [ ] unknown payload_version을 `rejected_version`으로 강제 처리하지 않는다(D-089).
- [ ] `payload_version_events` retention을 90일 초과로 운영하지 않는다.

## 외부 표면 캐시 (Edge/Route/SDK 레이어)

- [ ] 인프로세스 TTL 캐시(<= 5분)는 SQL 함수가 아니라 외부 표면에서 적용한다.
- [ ] 캐시 미스 시 DB 폴백을 사용한다.
- [ ] 캐시 키는 `payload_version` 기준으로 분리한다.

## 템플릿

### payload_version 검증 + 이벤트 기록

```sql
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
begin
  -- semver 형태 검증 (ADR-006)
  if p_version !~ '^\d+\.\d+$' then
    return jsonb_build_object('error_code', 'invalid_payload_version');
  end if;

  select state into v_state
  from public.payload_versions
  where version = p_version;

  if v_state is null then
    insert into public.payload_version_events (version, event_type, ts)
    values (p_version, 'unknown', now());
    return jsonb_build_object('state', 'UNKNOWN_ACCEPTED');
  end if;

  insert into public.payload_version_events (version, event_type, ts)
  values (
    p_version,
    case v_state when 'REJECT' then 'reject' else 'seen' end,
    now()
  );

  if v_state = 'REJECT' then
    return jsonb_build_object('error_code', 'rejected_version');
  end if;

  return jsonb_build_object('state', v_state);
end;
$$;
```

### 롤업 (배치/cron)

```sql
insert into public.payload_version_rollups (
  version, bucket_ts, seen_count, reject_count, normalize_fail_count, last_seen_at
)
select
  e.version,
  date_trunc('hour', e.ts) as bucket_ts,
  count(*) filter (where e.event_type = 'seen') as seen_count,
  count(*) filter (where e.event_type = 'reject') as reject_count,
  count(*) filter (where e.event_type = 'normalize_fail') as normalize_fail_count,
  max(e.ts) as last_seen_at
from public.payload_version_events e
where e.ts >= now() - interval '2 hours'
group by e.version, date_trunc('hour', e.ts)
on conflict (version, bucket_ts) do update set
  seen_count = excluded.seen_count,
  reject_count = excluded.reject_count,
  normalize_fail_count = excluded.normalize_fail_count,
  last_seen_at = greatest(payload_version_rollups.last_seen_at, excluded.last_seen_at);
```

### Retention cleanup (D-045)

```sql
delete from public.payload_version_events
where ts < now() - interval '90 days';
```

## 검증

### 스모크 테스트

```sql
select public.validate_payload_version('1.0');
-- 기대: {"state":"ACTIVE"} 또는 {"state":"DEPRECATED"} (테이블 상태에 따라)

select count(*)
from public.payload_version_events
where version = '1.0' and event_type in ('seen', 'reject');
-- 기대: >= 1
```

### 네거티브 테스트

```sql
select public.validate_payload_version('abc');
-- 기대: {"error_code":"invalid_payload_version"}

select public.validate_payload_version('0.5');
-- 기대: payload_versions.state='REJECT'이면 {"error_code":"rejected_version"}
-- 기대: payload_versions 미등록(unknown)이면 {"state":"UNKNOWN_ACCEPTED"}
```

## 근거 링크
- See: DECISIONS D-028, D-042, D-045, D-089
- See: docs/ADR/ADR-006-payload-version-kpi.md
- See: docs/DATA-MODEL.md#11-payload_versions--kpi
- See: docs/TESTING-STRATEGY.md

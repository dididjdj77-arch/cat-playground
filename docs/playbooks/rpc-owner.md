# Playbook: RPC Owner

> 이 문서는 owner 전용 RPC(쓰기/수정/멱등) 작업의 실행 가이드입니다.
> 정책 근거: See DECISIONS D-022, D-040, D-046, D-061, D-065

## 체크리스트

### Do
- [ ] owner 식별은 `auth.uid()`를 강제한다.
- [ ] 트랜잭션 경계를 명시해 partial write를 방지한다.
- [ ] `idempotency_key` 중복을 서버에서 차단한다.
- [ ] `expected_version` 불일치 시 409 충돌을 반환한다.
- [ ] 충돌 응답은 `error_code/current_version/(optional) current_group_snapshot` 구조를 따른다.
- [ ] replay 응답은 최초 성공과 동일한 응답 shape를 반환한다 (status-only 금지).
- [ ] replay 구현은 `stored response_json` 또는 `canonical 테이블 재구성` 중 하나를 선택한다.
- [ ] like_count는 원자 UPDATE(`= like_count + 1`)로 처리한다.
- [ ] inventory 수정은 `is_current=false + 새 row` 패턴을 사용한다.
- [ ] 비즈니스 에러는 JSON return으로 전달한다 (raise exception은 hard fail만). See D-065.
- [ ] 모든 write RPC는 `guard_terms_agreed()`를 호출한다 (D-073).
- [ ] write RPC guard 호출 순서를 고정한다: `guard_terms_agreed` → `guard_block` → `guard_soft_state` → `guard_visibility_published`.
- [ ] RPC 성격상 불필요한 guard는 `N/A`로 명시한다(예: owner-write RPC의 `guard_visibility_published`).

### Don't
- [ ] read-modify-write로 like_count를 업데이트하지 않는다.
- [ ] 멱등키 없이 재시도 가능한 쓰기 RPC를 만들지 않는다.
- [ ] inventory row를 delete 방식으로 제거하지 않는다.

## 템플릿

```sql
-- 범용 패턴: replay는 "최초 성공과 동일 shape" 반환
create or replace function public.rpc_upsert_owner_item(
  p_idempotency_key text,
  p_expected_version int,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := auth.uid();
  v_current_version int;
  v_replay_json jsonb;
begin
  if v_owner_id is null then
    raise exception 'unauthorized';
  end if;

  -- replay 구현 선택지:
  -- A) 저장된 response_json 그대로 반환
  -- B) canonical 테이블에서 재조립해 동일 응답 shape로 반환
  -- (도메인별 스키마에 맞춰 택1)

  -- 도메인별 최신 version 조회 (예시)
  -- e.g. public.<owner_aggregate_table>(owner_id, version, created_at)
  select version into v_current_version
  from public.<owner_aggregate_table>
  where owner_id = v_owner_id
  order by created_at desc
  limit 1;

  if v_current_version is not null and v_current_version <> p_expected_version then
    -- 에러 전달 패턴 (D-065):
    -- DB 함수는 JSON return으로 비즈니스 에러를 전달한다.
    -- PostgREST 경유 시 무예외 정상 return은 HTTP 200이 기본이며,
    -- 외부 표면이 error_code -> HTTP로 매핑할 수 있다.
    return jsonb_build_object(
      'error_code', 'version_conflict',
      'current_version', v_current_version
    );
  end if;

  -- write payload in one transaction boundary
  return jsonb_build_object('status', 'ok');
end;
$$;
```

### Example: Observation upsert replay (재구성 방식)

```sql
-- observation_groups + observations에서 결과를 재구성하는 예시
select g.id, g.version
into v_group_id, v_group_version
from public.observation_groups g
where g.owner_id = v_owner_id
  and g.idempotency_key = p_idempotency_key
  and g.deleted_at is null;

if found then
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'cat_id', o.cat_id,
        'status', o.status,
        'override_payload', o.override_payload
      )
      order by o.created_at
    ),
    '[]'::jsonb
  )
  into v_items
  from public.observations o
  where o.group_id = v_group_id
    and o.deleted_at is null;

  return jsonb_build_object(
    'group_id', v_group_id,
    'version', v_group_version,
    'items', v_items
  );
end if;
```

### Example: Observation patch replay (D-061)

```sql
select d.result_json
into v_replay_json
from public.observation_patch_dedup d
where d.owner_id = v_owner_id
  and d.group_id = p_group_id
  and d.idempotency_key = p_idempotency_key;

if found then
  return v_replay_json;
end if;
```

## 검증

### 스모크 테스트

```sql
-- Smoke: 멱등 리플레이
-- 1회: 정상 저장
select public.rpc_upsert_owner_item('key-001', 1, '{"test":true}'::jsonb);
-- 기대: {"status":"ok", ...}

-- 2회: 동일 key 재호출
select public.rpc_upsert_owner_item('key-001', 1, '{"test":true}'::jsonb);
-- 기대: 1회와 동일한 응답 shape(동일 group/version) 반환
```

### 네거티브 테스트

```sql
-- expected_version 불일치 시 충돌 JSON 기대
select public.rpc_upsert_owner_item('key-002', 1, '{"test":true}'::jsonb);
-- 기대: {"error_code":"version_conflict","current_version":...}

-- inventory delete 시도는 거부되고 is_current=false + 새 row 경로만 허용 기대
```

## 근거 링크
- See: DECISIONS D-022
- See: DECISIONS D-040
- See: DECISIONS D-046
- See: DECISIONS D-061
- See: DECISIONS D-065
- See: docs/PROCESS.md#6-고위험-판정-원칙-from-d-032
